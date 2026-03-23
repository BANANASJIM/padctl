# HID Reverse Engineering Guide

This guide walks through reverse engineering a gamepad's HID protocol from scratch. No prior HID experience needed — just basic hex literacy. Once you have identified all fields, proceed to the [Device Config Guide](device-config-guide.md) to write the TOML config.

## Prerequisites

Install these tools before starting:

```bash
# Wireshark + USB monitor kernel module
sudo pacman -S wireshark-qt    # or apt install wireshark
sudo modprobe usbmon

# Raw hex tools (usually pre-installed)
which xxd hexdump

# Input device testing
sudo pacman -S evtest          # or apt install evtest

# padctl's own capture tool
padctl-capture --help
```

You need read access to `/dev/hidraw*` and `/dev/usbmon*`. Either run as root or add your user to the appropriate groups:

```bash
sudo usermod -aG input $USER   # for hidraw
sudo usermod -aG wireshark $USER
```

---

## Step 1: Identify the Device

Plug in your gamepad and find it:

```bash
$ lsusb
Bus 001 Device 012: ID 054c:0ce6 Sony Corp. DualSense Wireless Controller
```

The hex pair `054c:0ce6` is your VID:PID. Write these down — they go directly into the TOML config.

### Find the hidraw node

```bash
$ ls /dev/hidraw*
/dev/hidraw0  /dev/hidraw1  /dev/hidraw2  /dev/hidraw3

$ cat /sys/class/hidraw/hidraw3/device/uevent
HID_ID=0003:0000054C:00000CE6
HID_NAME=Sony Interactive Entertainment Wireless Controller
HID_PHYS=usb-0000:08:00.3-2/input3
```

The `HID_ID` confirms VID/PID. The `input3` at the end of `HID_PHYS` tells you this is interface 3.

### Multiple interfaces

Many devices expose several USB interfaces. A DualSense has interfaces 0-3 (audio + HID). You need the one that carries gamepad data. Quick way to find it:

```bash
# Read a few bytes from each hidraw node while pressing buttons
for i in /dev/hidraw*; do
    echo "=== $i ==="
    sudo timeout 1 xxd -l 64 -c 32 "$i" 2>/dev/null || echo "(no data)"
done
```

The node that produces continuous output when you press buttons or move sticks is your target.

---

## Step 2: Capture Raw HID Reports

### Method 1: padctl-capture (recommended)

```bash
padctl-capture --device /dev/hidraw3 --duration 30 --output capture.bin
```

While capturing, do each action one at a time with a pause between:
1. Leave controller idle for 3 seconds (this is your baseline)
2. Press and release each face button (A, B, X, Y) one at a time
3. Press and release each shoulder button (LB, RB, LT, RT)
4. Move left stick to full left, full right, full up, full down
5. Move right stick the same way
6. Press each D-pad direction
7. Press Start, Select, Home

Write down the order and approximate timing. You will cross-reference this with the capture data.

### Method 2: Wireshark USB capture

```bash
sudo modprobe usbmon
```

Open Wireshark, select the `usbmonN` interface matching your USB bus (from `lsusb` output). Apply this display filter:

```
usb.transfer_type == 0x01 && usb.dst == "host"
```

This shows only interrupt IN transfers (device-to-host) — which is how gamepads send input reports.

Start capture, perform the same systematic button/axis sequence, then stop.

### Method 3: Quick and dirty with xxd

For a fast look without any special tools:

```bash
sudo xxd -c 64 -g 1 /dev/hidraw3 | head -20
```

This prints raw reports in hex as they arrive. Move a stick or press a button to see bytes change.

---

## Step 3: Analyze the Protocol

This is the core skill. You are looking at raw bytes and figuring out what each one means.

### Determine report size and report ID

Look at the raw data. Every read from hidraw returns one complete report. Check the length — common sizes are 10, 20, 32, 49, 64, or 78 bytes.

If the first byte is constant across all reports, it is likely a **report ID**. For example, DualSense USB reports always start with `0x01`:

```
01 80 80 80 80 00 00 08 00 00 ...
^^
Report ID 0x01
```

Some devices (like Flydigi Vader 5) use multi-byte magic headers:

```
5a a5 ef 00 00 00 00 00 00 ...
^^^^^^^^
3-byte magic prefix
```

### Find the idle baseline

With nothing pressed and sticks centered, capture several reports. This is your baseline:

```
Idle DualSense USB report (64 bytes):
01 80 80 80 80 00 00 08 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
```

Note bytes 1-4 are `80 80 80 80` — that is four axes centered at 0x80 (128).

### Identify analog axes

Move **only** the left stick fully left, and compare with idle:

```
Idle:       01 [80] 80 80 80 00 00 08 ...
Left full:  01 [00] 80 80 80 00 00 08 ...
                ^^
                Byte 1 changed: 0x80 → 0x00
```

Now fully right:

```
Right full: 01 [ff] 80 80 80 00 00 08 ...
                ^^
                Byte 1: 0x80 → 0xFF
```

This tells you:
- **Byte 1** = left stick X axis
- **Type**: `u8` (unsigned, 0x00 = left, 0x80 = center, 0xFF = right)
- Needs `transform = "scale(-32768, 32767)"` to map to standard axis range

Repeat for left stick Y (byte 2), right stick X (byte 3), right stick Y (byte 4).

**How to tell `u8` vs `i16le`:**

| Pattern | Type | Center | Range |
|---------|------|--------|-------|
| Single byte, idle = `0x80` | `u8` | 128 | 0-255 |
| Single byte, idle = `0x00` | `i8` | 0 | -128 to 127 |
| Two bytes, idle = `0x00 0x00` | `i16le` | 0 | -32768 to 32767 |
| Two bytes, idle = `0x00 0x80` | `u16le` centered | 32768 | 0-65535 |

For `i16le`, you will see two adjacent bytes change together. Move the stick fully right:

```
8BitDo Ultimate (i16le axes):
Idle:       01 [00 00] [00 00] [00 00] [00 00] ...
Right full: 01 [ff 7f] [00 00] [00 00] [00 00] ...
                ^^^^^
                0x7FFF = 32767 in little-endian = i16le max
```

### Identify triggers

Triggers are usually `u8` (0 = released, 0xFF = fully pressed). Slowly squeeze a trigger and watch which byte ramps from `0x00` to `0xFF`:

```
LT released: ... 00 00 08 ...
LT half:     ... 80 00 08 ...
LT full:     ... ff 00 08 ...
                  ^^
                  Byte 5 = LT, type u8
```

### Identify buttons

Press **one** button at a time and XOR with the idle frame to find changed bits:

```
Idle byte 8:    08  = 0000 1000
Press Cross:    28  = 0010 1000
XOR:            20  = 0010 0000  → bit 5 changed
```

So the Cross/A button is bit 5 of byte 8.

Do this for every button. Build a table:

| Button | Byte | Bit (in byte) | Bit (in group) |
|--------|------|---------------|----------------|
| Square/X | 8 | 4 | 4 |
| Cross/A | 8 | 5 | 5 |
| Circle/B | 8 | 6 | 6 |
| Triangle/Y | 8 | 7 | 7 |
| L1/LB | 9 | 0 | 8 |
| R1/RB | 9 | 1 | 9 |
| L3/LS | 9 | 6 | 14 |
| R3/RS | 9 | 7 | 15 |

The "bit in group" is calculated from the button_group source offset. If `source = { offset = 8, size = 3 }`, then bit indices are: byte 8 bits 0-7, byte 9 bits 8-15, byte 10 bits 16-23.

### Identify D-pad

D-pads come in two flavors:

**Hat switch (most common):** A single nibble (4 bits) encodes direction as a number 0-8:

```
0=N  1=NE  2=E  3=SE  4=S  5=SW  6=W  7=NW  8=neutral
```

Look for a nibble in the button bytes that cycles through these values as you press D-pad directions. On DualSense, bits [3:0] of byte 8 are the hat:

```
Idle:    08 (1000) → hat = 8 (neutral)
Up:      00 (0000) → hat = 0 (north)
Right:   02 (0010) → hat = 2 (east)
Down:    04 (0100) → hat = 4 (south)
Left:    06 (0110) → hat = 6 (west)
```

**Button bits:** Four separate bits, one for each direction. Flydigi Vader 5 uses this:

```toml
map = { DPadUp = 0, DPadRight = 1, DPadDown = 2, DPadLeft = 3, ... }
```

### Spot checksums

If the last 1-4 bytes change with **every** report even when nothing else changes, that is likely a checksum or sequence counter. DualSense Bluetooth has a CRC32 in the last 4 bytes:

```
Report bytes 74-77 change every frame, even when idle
→ CRC32 checksum over bytes 0-73
```

A single byte that increments by 1 each report is a sequence counter (common, usually ignored).

---

## Tips and Tricks

### Compare with similar devices

Devices from the same vendor often share report layouts. DualShock 4 and DualSense share the same structure with minor offset shifts (see `devices/sony/dualshock4.toml` vs `devices/sony/dualsense.toml`). If your device is a newer revision of a known one, start from the existing config and adjust offsets.

### Finding output commands (rumble, LED)

In Wireshark, look for host-to-device interrupt or control transfers:

```
usb.transfer_type == 0x01 && usb.dst != "host"
```

Or look for SET_REPORT control transfers:

```
usb.setup.bRequest == 0x09
```

Trigger rumble from another driver or app and capture the outgoing bytes. The structure is usually: report ID + flags + motor values + padding.

### Vendor-specific magic

Some devices (like Flydigi Vader 5) require an init sequence to enter extended mode. Signs that you need this:
- Reports are very short (< 10 bytes) and missing axes
- Reports change format after you send a specific command
- A reference driver sends a series of vendor commands on open

Look at how existing Linux drivers handle the device. Protocol facts (byte sequences, report formats) are not copyrightable (Feist v. Rural, 1991) — you may freely use byte offsets, field types, VID/PID, and bit positions found in any open-source driver. **Do not copy source code or comment text verbatim.**
