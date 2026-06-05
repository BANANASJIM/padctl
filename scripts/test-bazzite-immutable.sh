#!/usr/bin/env bash
# Faithful Bazzite (ublue/ostree immutable) install test via a Fedora container
# plus an ostree simulation, so CI need not pull the multi-GB Bazzite image.
#
# Reproduces the two Bazzite-specific conditions that matter for padctl install:
#   - /run/ostree-booted present        -> install auto-detects immutable
#   - /usr/local -> /var/usrlocal symlink (target created only at deploy time)
#
# Validates the install-migration hardening (PR #365):
#   A. an immutable update refreshes the /etc driver-block rule to the new block set
#   B. a stale rule in the non-active udev tree is swept (no /etc shadows /usr/lib)
#   C. a non-immutable uninstall still removes /etc rules left by an immutable install
#   D. install does not crash on the driver re-probe when USB sysfs is unwritable
#
# Inputs (env):  PADCTL  = path to the padctl binary
#                DEVICES = path to a devices/ tree containing flydigi/vader5.toml
# Run as root inside a disposable container.
set -u
PADCTL="${PADCTL:?set PADCTL to the padctl binary path}"
DEVSRC="${DEVICES:?set DEVICES to a devices/ directory}"
RULE=61-padctl-driver-block.rules
ETC=/etc/udev/rules.d/$RULE
LIB=/usr/local/lib/udev/rules.d/$RULE        # /usr/local -> /var/usrlocal on Bazzite
PASS=0; FAIL=0
ok(){  echo "  PASS: $*"; PASS=$((PASS + 1)); }
bad(){ echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }
blocks(){ grep -q "DRIVER==\"$2\"" "$1" 2>/dev/null; }                                  # blocks <file> <driver>
shows(){ grep "DRIVER==" "$1" 2>/dev/null | grep -oE "usbhid|hid_generic|xpad" | sort -u | tr "\n" " "; }
inst(){ ( cd "$1" && "$PADCTL" install --immutable --prefix /usr/local --no-enable --no-start --no-user-service ) >/tmp/i.log 2>&1; }

# --- Bazzite/ostree environment simulation ---
touch /run/ostree-booted
# shellcheck disable=SC2114  # container overlay only; swap /usr/local for the Bazzite symlink
rm -rf /usr/local
ln -s ../var/usrlocal /usr/local
mkdir -p /var/usrlocal

# install resolves device TOMLs from the binary's parent dirs before cwd, so a
# devices/ tree beside the binary would shadow each phase's modified TOML. Copy
# the binary somewhere with no devices/ ancestor so the per-phase cwd TOML wins.
cp "$PADCTL" /usr/bin/padctl
PADCTL=/usr/bin/padctl

# Two device-config generations: the old over-broad block list that hid the pad,
# and the shipped list (xpad only). Generated from the real vader5.toml so the
# rule content is faithful.
mkdir -p /work_old/devices/flydigi /work_new/devices/flydigi
cp "$DEVSRC/flydigi/vader5.toml" /work_new/devices/flydigi/vader5.toml
sed 's/^block_kernel_drivers = .*/block_kernel_drivers = ["xpad", "hid_generic", "usbhid"]/' \
  "$DEVSRC/flydigi/vader5.toml" > /work_old/devices/flydigi/vader5.toml

# shellcheck disable=SC1091  # /etc/os-release always present in the container
echo "container: $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")  (ostree-booted simulated, /usr/local -> $(readlink /usr/local))"

echo "=== A. immutable update (over-broad -> shipped) refreshes the /etc rule ==="
inst /work_old
if blocks "$ETC" usbhid; then ok "old over-broad rule written to /etc [$(shows "$ETC")]"; else bad "over-broad rule not written to /etc"; fi
inst /work_new
if [ -e "$ETC" ] && ! blocks "$ETC" usbhid; then ok "/etc refreshed to xpad-only [$(shows "$ETC")]"; else bad "stale usbhid still in /etc [$(shows "$ETC")]"; fi

echo "=== B. cross-mode sweep removes a stale rule from the non-active tree ==="
if [ ! -e "$ETC" ]; then
  bad "precondition failed: /etc rule absent before sweep test"
else
  mkdir -p "$(dirname "$LIB")"
  cp "$ETC" "$LIB"
  sed -i 's/DRIVER=="xpad"/DRIVER=="usbhid"/' "$LIB"
  echo "  seeded stale $LIB [$(shows "$LIB")]"
  inst /work_new
  if [ ! -e "$LIB" ]; then ok "stale /usr/local/lib copy swept"; else bad "stale lib copy survived [$(shows "$LIB")]"; fi
  if [ -e "$ETC" ] && ! blocks "$ETC" usbhid; then ok "active /etc rule intact + xpad-only"; else bad "active /etc rule disturbed"; fi
fi

echo "=== C. non-immutable uninstall still removes /etc rules from an immutable install ==="
# The rule was written to /etc by the immutable installs above. Pre-#365, /etc
# removal was gated on effective_immutable, so a --no-immutable uninstall left it
# orphaned; #365 made it unconditional. This asserts the new behavior.
if [ ! -e "$ETC" ]; then
  bad "precondition failed: /etc rule absent before uninstall"
else
  ( cd /work_new && "$PADCTL" uninstall --no-immutable --prefix /usr/local ) >/tmp/u.log 2>&1
  if [ ! -e "$ETC" ]; then ok "/etc rule removed by non-immutable uninstall"; else bad "/etc rule orphaned after non-immutable uninstall"; fi
fi

echo "=== D. install does not crash on the driver re-probe (USB sysfs unwritable) ==="
if inst /work_new; then ok "install exit 0 - re-probe silently no-ops"; else bad "install crashed (exit non-zero): $(tail -1 /tmp/i.log)"; fi

echo "=== RESULT: $PASS passed, $FAIL failed ==="
[ "$FAIL" = 0 ] || exit 1
