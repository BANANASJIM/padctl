#!/usr/bin/env bash
# Phase 13 Wave 5 canary — validate Wave 3's UHID IMU descriptor on a real
# kernel via Docker. Runs the `uhid_uniq_pairing_test` assertions (including
# the EVIOCGPROP / EVIOCGBIT kernel-classification checks added for Wave 5)
# inside a container that has access to the host's `/dev/uhid`.
#
# Goal: prove `buildForImu` emits a descriptor that the kernel 6.18 HID→evdev
# mapper classifies as an accelerometer sensor (INPUT_PROP_ACCELEROMETER set,
# zero EV_KEY bits), without touching the user's physical gamepad.
#
# Prerequisites on the host:
#   - /dev/uhid present (kernel CONFIG_UHID=y)
#   - docker running with permission to bind /dev/uhid
#   - project root used as build context

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_TAG="padctl-wave5-canary:latest"

echo "[wave5] building image from $REPO_ROOT (tag=$IMAGE_TAG)"
docker build \
    -t "$IMAGE_TAG" \
    -f "$REPO_ROOT/Dockerfile.wave5" \
    "$REPO_ROOT"

echo "[wave5] host /dev/uhid:"
ls -l /dev/uhid || {
    echo "[wave5] FAIL: /dev/uhid missing on host. Load the uhid module first (modprobe uhid)." >&2
    exit 2
}

echo "[wave5] running tests with PADCTL_TEST_REQUIRE_UHID=1"
# --privileged is required because the container must mount devtmpfs over
# /dev so that evdev nodes created by UHID_CREATE2 in the kernel (which land
# in the host's devtmpfs) are visible inside the container. Docker's default
# /dev is a sanitised tmpfs and won't reflect late-binding input nodes.
docker_run_args=(
    --rm
    --privileged
    -v "$REPO_ROOT:/src"
    -w /src
    -e PADCTL_TEST_REQUIRE_UHID=1
)

docker run "${docker_run_args[@]}" \
    "$IMAGE_TAG" \
    bash -c '
        set -euo pipefail
        # Shadow Docker-provided tmpfs /dev with the host kernel devtmpfs so
        # UHID-born evdev nodes are visible. Requires --privileged + CAP_SYS_ADMIN.
        mount -t devtmpfs devtmpfs /dev
        echo "[container] kernel: $(uname -r)"
        echo "[container] zig: $(zig version)"
        echo "[container] /dev/uhid: $(ls -l /dev/uhid 2>&1 || true)"
        echo "[container] /dev/input count before: $(ls /dev/input | wc -l)"

        echo "[container] zig build test-uhid-uniq -Dlibusb=false (isolated uhid_uniq_pairing test)"
        # Narrow to the single canary test file so we do not accidentally
        # trigger other tests that probe /dev/hidraw* on the host — they can
        # deadlock in hid_hw_open on kernel 6.18 when real USB HID devices
        # are attached to the host and the container runs as root.
        zig build test-uhid-uniq -Dlibusb=false

        echo "[container] post-run /dev/input count: $(ls /dev/input | wc -l)"
    '
