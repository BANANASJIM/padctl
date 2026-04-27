#!/usr/bin/env python3
"""
Wave 6 probe — does kernel `hid-pidff` bind to a virtual UHID device with bus=BUS_USB?

Strategy:
  1. Create a virtual HID joystick + PID output collection via /dev/uhid
  2. Wait for kernel to process the device (evdev + hidraw nodes appear)
  3. Inspect dmesg for `hid-pidff` bind messages
  4. Inspect /sys/class/input/event*/device/capabilities/ff for EV_FF capability
  5. Emit structured verdict

This probe is ADR-015 Stage 3 entry-condition verification (issue #82).
Target kernel: host (6.18.9 Arch) + any containerised kernel (Docker shares host kernel).

Dependencies: python3, hid-tools, /dev/uhid, CAP_SYS_ADMIN (root or cap-add).
"""

import os
import re
import sys
import time
import json
import subprocess
import select
from pathlib import Path

import hidtools.uhid
from hidtools.util import BusType


# -----------------------------------------------------------------------------
# HID report descriptor — Joystick (1 axis) + PID output collection with minimum
# fields for `hid-pidff` to recognise the device.
#
# Reference:
#   - HID PID 1.01 spec (usb.org/sites/default/files/pid1_01.pdf)
#   - linux/drivers/hid/hid-pidff.c — `pidff_find_reports` expects Set Effect,
#     Effect Operation, Device Control, and PID Pool report IDs; for a minimum
#     bind, Set Effect + Effect Operation + Device Control + PID Pool are needed.
#   - Usage Page 0x0F (PID), Usage 0x01 (PID State Report) is a logical collection
#
# This descriptor is intentionally minimal — just enough for pidff_find_reports
# to locate the mandatory output reports. Any failures will show up in dmesg.
#
# Layout summary (report IDs):
#   Report ID 1 (Input): joystick X axis (1 byte)
#   Report ID 2 (Output): Set Effect Report — effect block idx, effect type,
#                         duration, direction X, direction Y
#   Report ID 3 (Output): Set Envelope Report (optional but pidff logs if missing)
#   Report ID 4 (Output): Set Condition Report
#   Report ID 5 (Output): Set Periodic
#   Report ID 6 (Output): Set Constant Force
#   Report ID 7 (Output): Set Ramp Force
#   Report ID 8 (Output): Effect Operation (play/stop)
#   Report ID 9 (Output): Device Control (reset, pause, resume, actuator on/off)
#   Report ID 10 (Input): PID State Report
#   Report ID 11 (Feature): Create New Effect Report
#   Report ID 12 (Feature): Block Load Report
#   Report ID 13 (Feature): PID Pool Report
#   Report ID 14 (Output): PID Device Gain
#
# Because writing a byte-perfect PID descriptor is delicate, we embed one
# derived from hid-tools/tests/ references and the PID 1.01 example wheel.

# HID report descriptor bytes — a well-known PID-compatible joystick descriptor.
# Adapted from Moza R5 / generic PID wheel descriptors (11ff:f045 class). The
# layout is: Application (Joystick) > Input(axes, buttons) > PID Logical(outputs).
#
# NOTE: We intentionally keep this conservative. If kernel pidff still rejects
# it, the failure mode ("bustype/descriptor-form/xyz") informs Stage 3 vs
# Option (a) decision.

RDESC = bytes([
    # Usage Page (Generic Desktop)
    0x05, 0x01,
    # Usage (Joystick)
    0x09, 0x04,
    # Collection (Application)
    0xA1, 0x01,
    #   Report ID (1) — input (axes)
    0x85, 0x01,
    #   Collection (Physical)
    0xA1, 0x00,
    #     Usage (X)
    0x09, 0x30,
    #     Logical Minimum (-127)
    0x15, 0x81,
    #     Logical Maximum (127)
    0x25, 0x7F,
    #     Report Size (8)
    0x75, 0x08,
    #     Report Count (1)
    0x95, 0x01,
    #     Input (Data, Var, Abs)
    0x81, 0x02,
    #   End Collection
    0xC0,

    # === PID output collection ===
    # Usage Page (Physical Interface Device) = 0x0F
    0x05, 0x0F,

    # ---- Set Effect Report (report id 2) ----
    # Usage (Set Effect Report) = 0x21
    0x09, 0x21,
    # Collection (Logical)
    0xA1, 0x02,
    #   Report ID (2)
    0x85, 0x02,
    #   Usage (Effect Block Index) = 0x22
    0x09, 0x22,
    #   Logical Min 1 / Max 40
    0x15, 0x01, 0x25, 0x28,
    #   Report Size 8 / Count 1
    0x75, 0x08, 0x95, 0x01,
    #   Output (Data, Var, Abs)
    0x91, 0x02,
    #   Usage (Effect Type) = 0x25
    0x09, 0x25,
    #   Collection (Logical)
    0xA1, 0x02,
    #     Usage Page (PID)
    0x05, 0x0F,
    #     Usage (ET Constant Force) = 0x26
    0x09, 0x26,
    #     Usage (ET Ramp) = 0x27
    0x09, 0x27,
    #     Usage (ET Square) = 0x30
    0x09, 0x30,
    #     Usage (ET Sine) = 0x31
    0x09, 0x31,
    #     Usage (ET Triangle) = 0x32
    0x09, 0x32,
    #     Usage (ET Sawtooth Up) = 0x33
    0x09, 0x33,
    #     Usage (ET Sawtooth Down) = 0x34
    0x09, 0x34,
    #     Usage (ET Spring) = 0x40
    0x09, 0x40,
    #     Usage (ET Damper) = 0x41
    0x09, 0x41,
    #     Usage (ET Inertia) = 0x42
    0x09, 0x42,
    #     Usage (ET Friction) = 0x43
    0x09, 0x43,
    #     Logical Min 1 / Max 11
    0x15, 0x01, 0x25, 0x0B,
    #     Report Size 8 / Count 1
    0x75, 0x08, 0x95, 0x01,
    #     Output (Data, Ary, Abs)
    0x91, 0x00,
    #   End Collection
    0xC0,
    #   Usage Page (PID)
    0x05, 0x0F,
    #   Usage (Duration) = 0x50
    0x09, 0x50,
    #   Unit Exponent (-3) — ms
    0x55, 0x0D,
    #   Unit (SI Time, Second)
    0x66, 0x01, 0x10,
    #   Logical Min 0 / Max 0x7FFF
    0x15, 0x00, 0x26, 0xFF, 0x7F,
    #   Report Size 16 / Count 1
    0x75, 0x10, 0x95, 0x01,
    #   Output (Data, Var, Abs)
    0x91, 0x02,
    #   Unit(0) — reset
    0x66, 0x00, 0x00,
    #   Unit Exponent (0)
    0x55, 0x00,
    # End Collection (Set Effect Report)
    0xC0,

    # ---- Effect Operation Report (report id 8) ----
    # Usage (Effect Operation Report) = 0x77
    0x09, 0x77,
    # Collection (Logical)
    0xA1, 0x02,
    #   Report ID (8)
    0x85, 0x08,
    #   Usage (Effect Block Index) = 0x22
    0x09, 0x22,
    #   Logical Min 1 / Max 40
    0x15, 0x01, 0x25, 0x28,
    #   Report Size 8 / Count 1
    0x75, 0x08, 0x95, 0x01,
    #   Output (Data, Var, Abs)
    0x91, 0x02,
    #   Usage (Operation) = 0x78
    0x09, 0x78,
    #   Collection (Logical)
    0xA1, 0x02,
    #     Usage (Op Start) = 0x79
    0x09, 0x79,
    #     Usage (Op Start Solo) = 0x7A
    0x09, 0x7A,
    #     Usage (Op Stop) = 0x7B
    0x09, 0x7B,
    #     Logical Min 1 / Max 3
    0x15, 0x01, 0x25, 0x03,
    #     Report Size 8 / Count 1
    0x75, 0x08, 0x95, 0x01,
    #     Output (Data, Ary, Abs)
    0x91, 0x00,
    #   End Collection
    0xC0,
    # End Collection
    0xC0,

    # ---- Device Control (report id 9) ----
    # Usage (PID Device Control) = 0x95
    0x09, 0x95,
    # Collection (Logical)
    0xA1, 0x02,
    #   Report ID (9)
    0x85, 0x09,
    #   Usage (DC Device Reset) = 0x97
    0x09, 0x97,
    #   Usage (DC Device Pause) = 0x98
    0x09, 0x98,
    #   Usage (DC Device Continue) = 0x99
    0x09, 0x99,
    #   Usage (DC Stop All Effects) = 0x9A
    0x09, 0x9A,
    #   Usage (DC Enable Actuators) = 0x9B
    0x09, 0x9B,
    #   Usage (DC Disable Actuators) = 0x9C
    0x09, 0x9C,
    #   Logical Min 1 / Max 6
    0x15, 0x01, 0x25, 0x06,
    #   Report Size 8 / Count 1
    0x75, 0x08, 0x95, 0x01,
    #   Output (Data, Ary, Abs)
    0x91, 0x00,
    # End Collection
    0xC0,

    # ---- Create New Effect Report (Feature id 11) ----
    # Usage (Create New Effect Report) = 0xAB
    0x09, 0xAB,
    # Collection (Logical)
    0xA1, 0x02,
    #   Report ID (11)
    0x85, 0x0B,
    #   Usage (Effect Type) = 0x25
    0x09, 0x25,
    #   Collection (Logical)
    0xA1, 0x02,
    #     Usage Page (PID)
    0x05, 0x0F,
    #     Usage (ET Constant Force) = 0x26
    0x09, 0x26,
    #     Usage (ET Ramp) = 0x27
    0x09, 0x27,
    #     Usage (ET Spring) = 0x40
    0x09, 0x40,
    #     Usage (ET Damper) = 0x41
    0x09, 0x41,
    #     Usage (ET Inertia) = 0x42
    0x09, 0x42,
    #     Usage (ET Friction) = 0x43
    0x09, 0x43,
    #     Logical Min 1 / Max 11
    0x15, 0x01, 0x25, 0x0B,
    #     Report Size 8 / Count 1
    0x75, 0x08, 0x95, 0x01,
    #     Feature (Data, Ary, Abs)
    0xB1, 0x00,
    #   End Collection
    0xC0,
    # End Collection
    0xC0,

    # ---- Block Load Report (Feature id 12) ----
    # Usage (Block Load Report) = 0x89
    0x09, 0x89,
    # Collection (Logical)
    0xA1, 0x02,
    #   Report ID (12)
    0x85, 0x0C,
    #   Usage (Effect Block Index) = 0x22
    0x09, 0x22,
    #   Logical Min 1 / Max 40
    0x15, 0x01, 0x25, 0x28,
    #   Report Size 8 / Count 1
    0x75, 0x08, 0x95, 0x01,
    #   Feature (Data, Var, Abs)
    0xB1, 0x02,
    #   Usage (Block Load Status) = 0x8B
    0x09, 0x8B,
    #   Collection (Logical)
    0xA1, 0x02,
    #     Usage (Block Load Success) = 0x8C
    0x09, 0x8C,
    #     Usage (Block Load Full) = 0x8D
    0x09, 0x8D,
    #     Usage (Block Load Error) = 0x8E
    0x09, 0x8E,
    #     Logical Min 1 / Max 3
    0x15, 0x01, 0x25, 0x03,
    #     Report Size 8 / Count 1
    0x75, 0x08, 0x95, 0x01,
    #     Feature (Data, Ary, Abs)
    0xB1, 0x00,
    #   End Collection
    0xC0,
    #   Usage (RAM Pool Available) = 0xAC
    0x09, 0xAC,
    #   Logical Min 0 / Max 0xFFFF
    0x15, 0x00, 0x27, 0xFF, 0xFF, 0x00, 0x00,
    #   Report Size 16 / Count 1
    0x75, 0x10, 0x95, 0x01,
    #   Feature (Data, Var, Abs)
    0xB1, 0x02,
    # End Collection
    0xC0,

    # ---- PID Pool Report (Feature id 13) ----
    # Usage (PID Pool Report) = 0x7F
    0x09, 0x7F,
    # Collection (Logical)
    0xA1, 0x02,
    #   Report ID (13)
    0x85, 0x0D,
    #   Usage (RAM Pool Size) = 0x80
    0x09, 0x80,
    #   Logical Min 0 / Max 0xFFFF
    0x15, 0x00, 0x27, 0xFF, 0xFF, 0x00, 0x00,
    #   Report Size 16 / Count 1
    0x75, 0x10, 0x95, 0x01,
    #   Feature (Data, Var, Abs)
    0xB1, 0x02,
    #   Usage (Simultaneous Effects Max) = 0x83
    0x09, 0x83,
    #   Logical Min 0 / Max 0xFF
    0x15, 0x00, 0x26, 0xFF, 0x00,
    #   Report Size 8 / Count 1
    0x75, 0x08, 0x95, 0x01,
    #   Feature (Data, Var, Abs)
    0xB1, 0x02,
    #   Usage (Device Managed Pool) = 0xA9
    0x09, 0xA9,
    #   Usage (Shared Parameter Blocks) = 0xAA
    0x09, 0xAA,
    #   Logical Min 0 / Max 1
    0x15, 0x00, 0x25, 0x01,
    #   Report Size 1 / Count 2
    0x75, 0x01, 0x95, 0x02,
    #   Feature (Data, Var, Abs)
    0xB1, 0x02,
    #   Padding Report Size 1 / Count 6
    0x75, 0x01, 0x95, 0x06,
    #   Feature (Const, Var, Abs)
    0xB1, 0x03,
    # End Collection
    0xC0,

    # End Collection (Application)
    0xC0,
])


class PidffProbe(hidtools.uhid.UHIDDevice):
    def __init__(self):
        super().__init__()
        self.name = os.environ.get(
            "PROBE_NAME", "padctl Wave6 PIDff Probe Wheel"
        )
        self.phys = "padctl/wave6-probe"
        self.uniq = "padctl/wave6-probe-0"
        vid = int(os.environ.get("PROBE_VID", "0x11ff"), 16)
        pid = int(os.environ.get("PROBE_PID", "0x1211"), 16)  # Moza R5 default
        self.info = (BusType.USB, vid, pid)
        self.rdesc = RDESC
        self.ff_output_events: list[bytes] = []

    def output_report(self, data, size, rtype):
        # Record any UHID_OUTPUT event from kernel — this is exactly what
        # padctl would receive from hid-pidff when a game sends FFB.
        payload = bytes(data[:size])
        self.ff_output_events.append(payload)
        print(f"[probe] UHID_OUTPUT rtype={rtype} size={size} data={payload.hex(' ')}", file=sys.stderr)


def read_ff_capabilities(sys_path: Path) -> dict:
    """Inspect every evdev node's capabilities/ff file and return parsed bits."""
    out = {}
    for ev_dir in sorted(Path(sys_path).glob("input/input*/event*")):
        ev_name = ev_dir.name
        caps_path = ev_dir.parent / "capabilities" / "ff"
        if caps_path.exists():
            out[ev_name] = caps_path.read_text().strip()
    return out


def read_modalias_and_driver(sys_path: Path) -> dict:
    """Find the HID device modalias + bound driver under sys_path's ancestry."""
    result = {}
    for hid_dir in sorted(Path(sys_path).glob("../hid*") if (Path(sys_path).name.startswith("0003:") is False) else [Path(sys_path)]):
        modalias = hid_dir / "modalias"
        driver_link = hid_dir / "driver"
        if modalias.exists():
            result[hid_dir.name] = {
                "modalias": modalias.read_text().strip(),
                "driver": driver_link.resolve().name if driver_link.is_symlink() else None,
            }
    return result


def read_dmesg_tail_since(mark: str) -> str:
    """Read dmesg lines printed after mark. Requires CAP_SYSLOG or kernel.dmesg_restrict=0."""
    try:
        out = subprocess.run(
            ["dmesg", "-T", "--notime"], capture_output=True, text=True, check=True
        ).stdout
    except subprocess.CalledProcessError as e:
        return f"<dmesg failed: {e}>"
    # split at mark; keep everything after
    idx = out.rfind(mark)
    if idx == -1:
        return "<mark not found — returning last 80 lines>\n" + "\n".join(out.splitlines()[-80:])
    return out[idx:]


def try_load_module(name: str) -> tuple[bool, str]:
    """Try modprobe; return (ok, stderr)."""
    try:
        r = subprocess.run(
            ["modprobe", name],
            capture_output=True, text=True, timeout=10,
        )
        return (r.returncode == 0, r.stderr.strip())
    except FileNotFoundError:
        return (False, "modprobe not installed")
    except Exception as e:
        return (False, str(e))


def check_module_loaded(name: str) -> bool:
    # /sys/module/<name> — works whether module is loaded or built-in
    return Path(f"/sys/module/{name.replace('-', '_')}").exists()


def main():
    print(f"[probe] kernel: {os.uname().release}", file=sys.stderr)
    print(f"[probe] /dev/uhid present: {Path('/dev/uhid').exists()}", file=sys.stderr)
    print(f"[probe] rdesc length: {len(RDESC)} bytes", file=sys.stderr)

    # Attempt to load hid-universal-pidff so kernel has a driver that can bind
    # to PID-compliant wheels. On Arch 6.18, hid-generic will NOT call
    # hid_pidff_init — only drivers with matching VID/PID aliases will.
    target_modules = ["hid_universal_pidff", "hid_microsoft", "hid"]
    for mod in target_modules:
        if check_module_loaded(mod):
            print(f"[probe] module {mod} already loaded/built-in", file=sys.stderr)
        else:
            ok, err = try_load_module(mod.replace("_", "-"))
            print(f"[probe] modprobe {mod}: ok={ok} err={err!r}", file=sys.stderr)


    # Emit a unique dmesg marker so we can tail only our slice
    marker = f"padctl-wave6-probe-mark-{os.getpid()}-{int(time.time())}"
    try:
        # Not fatal if this fails — we'll just get the full dmesg tail
        with open("/dev/kmsg", "w") as km:
            km.write(f"padctl-probe: {marker}\n")
    except (PermissionError, OSError):
        print(f"[probe] /dev/kmsg not writable; will use full dmesg tail", file=sys.stderr)
        marker = None

    device = PidffProbe()
    try:
        device.create_kernel_device()
        print(f"[probe] UHID device created; dispatching events for 2s to let kernel bind", file=sys.stderr)

        # Pump events for up to 3 seconds to allow kernel to call start/open
        deadline = time.time() + 3.0
        while time.time() < deadline:
            remaining = max(0.01, deadline - time.time())
            # dispatch returns after processing one event or on timeout
            rlist, _, _ = select.select([device.fd], [], [], remaining)
            if rlist:
                hidtools.uhid.UHIDDevice.process_one_event_static() if hasattr(hidtools.uhid.UHIDDevice, "process_one_event_static") else device.dispatch(0.01)
            else:
                device.dispatch(0.01)

        print(f"[probe] sys_path: {device.sys_path}", file=sys.stderr)
        print(f"[probe] hidraw_nodes: {device.hidraw_nodes}", file=sys.stderr)
        print(f"[probe] device_nodes: {device.device_nodes}", file=sys.stderr)

        # Collect state
        sys_path = device.sys_path
        verdict = {
            "kernel": os.uname().release,
            "rdesc_len": len(RDESC),
            "vid_pid": f"{device.vid:04x}:{device.pid:04x}",
            "bus": device.bus.name if device.bus else None,
            "sys_path": str(sys_path) if sys_path else None,
            "hidraw_nodes": device.hidraw_nodes,
            "evdev_nodes": device.device_nodes,
            "ff_capabilities": {},
            "modalias": None,
            "bound_driver": None,
            "dmesg_slice": None,
            "uhid_output_events_seen": len(device.ff_output_events),
        }

        if sys_path:
            # The sys_path looks like /sys/devices/virtual/misc/uhid/0003:11FF:F045.XXXX/
            verdict["ff_capabilities"] = read_ff_capabilities(sys_path)

            modalias_path = Path(sys_path) / "modalias"
            if modalias_path.exists():
                verdict["modalias"] = modalias_path.read_text().strip()

            driver_link = Path(sys_path) / "driver"
            if driver_link.is_symlink():
                verdict["bound_driver"] = driver_link.resolve().name

        # dmesg slice
        if marker:
            verdict["dmesg_slice"] = read_dmesg_tail_since(marker)
        else:
            try:
                out = subprocess.run(
                    ["dmesg", "-T"], capture_output=True, text=True, check=True
                ).stdout
                verdict["dmesg_slice"] = "\n".join(out.splitlines()[-60:])
            except Exception as e:
                verdict["dmesg_slice"] = f"<dmesg unavailable: {e}>"

        # Binary verdict — strict: must have either
        #   (a) driver name contains pidff/universal-pidff, OR
        #   (b) any evdev node exposes non-zero ff capabilities bitmap
        # dmesg string matching alone is unreliable (marker itself contains "PID").
        driver = verdict.get("bound_driver") or ""
        ff_caps_nonzero = any(
            (caps and caps.replace(" ", "").replace("0", "") != "")
            for caps in verdict["ff_capabilities"].values()
        )
        pidff_driver_bound = (
            "pidff" in driver.lower() or "universal-pidff" in driver.lower()
        )
        # dmesg hint is informational only, not part of binary verdict
        dmesg_lower = (verdict["dmesg_slice"] or "").lower()
        pidff_init_in_dmesg = (
            "hid_pidff" in dmesg_lower
            or "pidff_find_reports" in dmesg_lower
            or "pidff:" in dmesg_lower
        )

        # dmesg-based bind detection — the driver symlink may be stale if the
        # kernel OOPSed during init, but the bind line in dmesg is authoritative.
        dmesg_raw = verdict["dmesg_slice"] or ""
        dmesg_shows_pidff_bind = bool(
            re.search(r"hid-(universal-)?pidff\s+\d+:", dmesg_raw)
        )
        dmesg_shows_ffb_init_error = (
            "error initialising force feedback" in dmesg_lower
            or "error initializing force feedback" in dmesg_lower
        )
        dmesg_shows_kernel_oops = (
            "kernel null pointer dereference" in dmesg_lower
            or "oops:" in dmesg_lower
        )

        # Orthogonal dimensions:
        #   (1) BUSTYPE_ACCEPTED — kernel did not reject BUS_USB at bind time
        #       (any driver bound, including hid-generic / hid-universal-pidff)
        #   (2) PIDFF_DRIVER_BOUND — hid-pidff/hid-universal-pidff took over via
        #       modalias match (requires VID/PID in driver's table)
        #   (3) FFB_INITIALIZED — kernel exposed EV_FF capabilities on evdev
        bustype_accepted = bool(
            verdict["hidraw_nodes"]  # any hidraw created = kernel accepted CREATE2
        )
        pidff_bound_via_modalias = dmesg_shows_pidff_bind or pidff_driver_bound
        ffb_initialized = ff_caps_nonzero

        verdict["BUSTYPE_ACCEPTED"] = bustype_accepted
        verdict["PIDFF_DRIVER_BOUND"] = pidff_bound_via_modalias
        verdict["FFB_INITIALIZED"] = ffb_initialized
        verdict["FFB_INIT_ERROR"] = dmesg_shows_ffb_init_error
        verdict["KERNEL_OOPS"] = dmesg_shows_kernel_oops
        # Legacy boolean (kept for compat) — now means "full Stage 3 viable"
        verdict["PIDFF_BOUND"] = bool(ffb_initialized)
        verdict["verdict_basis"] = {
            "driver_sysfs_link": driver,
            "ff_caps_nonzero": ff_caps_nonzero,
            "pidff_driver_sysfs_match": pidff_driver_bound,
            "pidff_init_log_in_dmesg": pidff_init_in_dmesg,
            "dmesg_shows_pidff_bind": dmesg_shows_pidff_bind,
        }

        print("\n=== VERDICT ===")
        print(json.dumps(verdict, indent=2, default=str))

    finally:
        try:
            device.destroy()
        except Exception:
            pass


if __name__ == "__main__":
    main()
