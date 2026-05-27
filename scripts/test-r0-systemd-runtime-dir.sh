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

CONTAINER_DEBIAN=padctl-r0-sd-runtime-debian12
CONTAINER_FEDORA=padctl-r0-sd-runtime-fedora41
CONTAINER_UBUNTU=padctl-r0-sd-runtime-ubuntu2604

step() { printf '\n=== %s ===\n' "$*"; }
ok()   { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

cleanup() {
    docker rm -f "$CONTAINER_DEBIAN" >/dev/null 2>&1 || true
    docker rm -f "$CONTAINER_FEDORA" >/dev/null 2>&1 || true
    docker rm -f "$CONTAINER_UBUNTU" >/dev/null 2>&1 || true
}
trap cleanup EXIT

PADCTL_BIN="$REPO_ROOT/zig-out/bin/padctl"
[ -x "$PADCTL_BIN" ] || fail "padctl binary missing — run ./scripts/padctl-docker build first ($PADCTL_BIN)"

run_stages_in() {
    local IMAGE="$1"
    local CONTAINER="$2"

    step "distro: $IMAGE — build systemd-capable container image"
    case "$IMAGE" in
        fedora:*)
            docker build -q -t "padctl-r0-sd-runtime-${CONTAINER##*-}:test" - >/dev/null <<DOCKERFILE
FROM $IMAGE
RUN dnf install -y systemd dbus procps-ng && dnf clean all
DOCKERFILE
            ;;
        *)
            docker build -q -t "padctl-r0-sd-runtime-${CONTAINER##*-}:test" - >/dev/null <<DOCKERFILE
FROM $IMAGE
RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus procps \
 && rm -rf /var/lib/apt/lists/*
DOCKERFILE
            ;;
    esac
    local LOCAL_IMAGE="padctl-r0-sd-runtime-${CONTAINER##*-}:test"

    step "distro: $IMAGE — start systemd as PID 1"
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    docker run -d --name "$CONTAINER" --privileged --cgroupns=host \
      --tmpfs /run --tmpfs /run/lock \
      -v /sys/fs/cgroup:/sys/fs/cgroup \
      -e container=docker \
      "$LOCAL_IMAGE" /lib/systemd/systemd >/dev/null
    docker cp "$PADCTL_BIN" "$CONTAINER:/usr/bin/padctl"

    local state
    for _ in $(seq 1 30); do
        state=$(docker exec "$CONTAINER" systemctl is-system-running 2>/dev/null || true)
        [[ "$state" =~ ^(running|degraded)$ ]] && break
        sleep 1
    done
    [[ "$state" =~ ^(running|degraded)$ ]] || fail "$IMAGE: systemd did not reach running/degraded in 30s (state='$state')"
    ok "$IMAGE: systemd is $state"

    step "distro: $IMAGE — stage system unit via legacy-update path"
    docker exec "$CONTAINER" /bin/bash -euo pipefail -c '
      mkdir -p /lib/systemd/system
      : > /lib/systemd/system/padctl.service
      padctl install --no-enable --no-start --no-user-service >/dev/null
      test -s /lib/systemd/system/padctl.service
    '

    step "distro: $IMAGE — static check: systemd-analyze verify"
    docker exec "$CONTAINER" systemd-analyze verify --man=no /lib/systemd/system/padctl.service
    ok "$IMAGE: systemd-analyze verify clean"

    step "distro: $IMAGE — behavioral check: RuntimeDirectory=padctl auto-created on start"
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
    ok "$IMAGE: /run/padctl created with root:root 755"

    step "distro: $IMAGE — cleanup check: RuntimeDirectoryPreserve=no removes dir on stop"
    docker exec "$CONTAINER" /bin/bash -euo pipefail -c '
      systemctl stop padctl.service || true
      for _ in $(seq 1 20); do
        [ ! -d /run/padctl ] && break
        sleep 0.25
      done
      [ ! -d /run/padctl ] || { echo "FAIL: /run/padctl persisted after stop (Preserve=no violated)"; exit 1; }
    '
    ok "$IMAGE: /run/padctl removed on stop"
}

printf '\n=== distro: debian:12 ===\n'
run_stages_in "debian:12" "$CONTAINER_DEBIAN"

printf '\n=== distro: fedora:41 ===\n'
run_stages_in "fedora:41" "$CONTAINER_FEDORA"

printf '\n=== distro: ubuntu:26.04 ===\n'
run_stages_in "ubuntu:26.04" "$CONTAINER_UBUNTU"

printf '\nAll 3 stages passed on 3 distros.\n'
