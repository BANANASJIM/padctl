#!/usr/bin/env bash
# Behavioral E2E test for systemd-owned /run/padctl/ lifecycle.
#
# Regressions caught (none of which a text-blob grep would notice):
#   - Typo in directive name (e.g. RuntimeDirectroy=) → systemd-analyze verify fails
#   - Directive accidentally moved into a comment block → /run/padctl/ not created
#   - RuntimeDirectoryPreserve flipped to yes/restart → cleanup check fails
#
# Run: bash scripts/test-r0-systemd-runtime-dir.sh
# Requires: docker, ./scripts/padctl-docker build (produces zig-out/bin/padctl)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONTAINER=padctl-r0-sd-runtime
IMAGE=padctl-r0-sd-runtime:test

cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

step() { printf '\n=== %s ===\n' "$*"; }
ok()   { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

PADCTL_BIN="$REPO_ROOT/zig-out/bin/padctl"
[ -x "$PADCTL_BIN" ] || fail "padctl binary missing — run ./scripts/padctl-docker build first ($PADCTL_BIN)"

step "build systemd-capable container image"
docker build -q -t "$IMAGE" - >/dev/null <<'DOCKERFILE'
FROM debian:12
RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus procps \
 && rm -rf /var/lib/apt/lists/*
DOCKERFILE

step "start systemd as PID 1"
cleanup
docker run -d --name "$CONTAINER" --privileged --cgroupns=host \
  --tmpfs /run --tmpfs /run/lock \
  -v /sys/fs/cgroup:/sys/fs/cgroup \
  -e container=docker \
  "$IMAGE" /lib/systemd/systemd >/dev/null
docker cp "$PADCTL_BIN" "$CONTAINER:/usr/bin/padctl"

for _ in $(seq 1 30); do
    state=$(docker exec "$CONTAINER" systemctl is-system-running 2>/dev/null || true)
    [[ "$state" =~ ^(running|degraded)$ ]] && break
    sleep 1
done
[[ "$state" =~ ^(running|degraded)$ ]] || fail "systemd did not reach running/degraded in 30s (state='$state')"
ok "systemd is $state"

step "stage system unit via legacy-update path"
# updateLegacySystemService() only refreshes /lib/systemd/system/padctl.service
# when a file is already present, so seed a stub then re-run install.
docker exec "$CONTAINER" /bin/bash -euo pipefail -c '
  mkdir -p /lib/systemd/system
  : > /lib/systemd/system/padctl.service
  padctl install --no-enable --no-start --no-user-service >/dev/null
  test -s /lib/systemd/system/padctl.service
'

step "static check: systemd-analyze verify"
docker exec "$CONTAINER" systemd-analyze verify --man=no /lib/systemd/system/padctl.service
ok "systemd-analyze verify clean"

step "behavioral check: RuntimeDirectory=padctl auto-created on start"
# ExecStart=padctl daemon will exit (no hardware) and Restart=on-failure will
# loop; --no-block returns immediately, then we inspect /run/padctl after the
# initial activation. RuntimeDirectory= is materialized BEFORE ExecStart runs,
# so it exists regardless of subsequent ExecStart failure.
docker exec "$CONTAINER" /bin/bash -euo pipefail -c '
  systemctl daemon-reload
  systemctl start --no-block padctl.service || true
  for _ in $(seq 1 20); do
    [ -d /run/padctl ] && break
    sleep 0.25
  done
  [ -d /run/padctl ] || { echo "FAIL: /run/padctl was not created"; exit 1; }
  perm=$(stat -c "%U:%G %a" /run/padctl)
  [ "$perm" = "root:root 755" ] || { echo "FAIL: /run/padctl perms=$perm (want root:root 755)"; exit 1; }
'
ok "/run/padctl created with root:root 755"

step "cleanup check: RuntimeDirectoryPreserve=no removes dir on stop"
docker exec "$CONTAINER" /bin/bash -euo pipefail -c '
  systemctl stop padctl.service || true
  for _ in $(seq 1 20); do
    [ ! -d /run/padctl ] && break
    sleep 0.25
  done
  [ ! -d /run/padctl ] || { echo "FAIL: /run/padctl persisted after stop (Preserve=no violated)"; exit 1; }
'
ok "/run/padctl removed on stop"

printf '\nAll 3 stages passed.\n'
