---
name: usb-keystroke-decoder
description: Decode USB keyboard keystrokes from PCAP captures. Use this skill whenever you need to extract typed text from USB traffic, analyze keyboard HID reports, or investigate USB-based keylogging. Trigger on any mention of USB keyboard analysis, PCAP keystroke extraction, HID report decoding, USB traffic forensics, or recovering typed input from network captures.
---

# USB Keystroke Decoder

Extract and decode typed keystrokes from USB HID traffic captured in PCAP files. This skill handles the USB boot protocol format used by most keyboards.

## How USB Keyboards Work

USB keyboards use the HID boot protocol. Each interrupt transfer to the host is 8 bytes:

| Byte | Meaning |
|------|----------|
| 0 | Modifier bitmap (Shift, Ctrl, Alt, etc.) |
| 1 | Reserved/padding |
| 2-7 | Up to 6 keycodes in USB usage ID format |

Keycode `0x00` means no key. Keyboards without NKRO send `0x01` in byte 2 when more than 6 keys are pressed.

## Quick Start

### Method 1: Use the bundled decoder script

```bash
# Extract raw USB data from PCAP
tshark -r capture.pcap -Y 'usb.capdata && usb.data_len == 8' -T fields -e usb.capdata | \
  sed 's/../:&/g' > keystrokes.txt

# Decode to text
python3 scripts/usb_decoder.py keystrokes.txt
```

### Method 2: Use Wireshark

1. **Filter keyboard traffic**: `usb.transfer_type == 0x01 && usb.endpoint_address.direction == "IN"`
2. **Add columns**: Right-click `usb.capdata` and `usbhid.boot_report.keyboard.keycode_1` fields
3. **Hide empty reports**: `!(usb.capdata == 00:00:00:00:00:00:00:00)`
4. **Export**: File → Export Packet Dissections → As CSV

## Common Modifier Bits

| Hex | Modifier |
|-----|----------|
| 0x01 | Left Ctrl |
| 0x02 | Left Shift |
| 0x04 | Left Alt |
| 0x08 | Left GUI (Super/Windows) |
| 0x10 | Right Ctrl |
| 0x20 | Right Shift |
| 0x40 | Right Alt |
| 0x80 | Right GUI |

## Common Keycodes

| Hex | Key | Hex | Key | Hex | Key |
|-----|-----|-----|-----|-----|-----|
| 0x04 | a | 0x05 | b | 0x06 | c |
| 0x07 | d | 0x08 | e | 0x09 | f |
| 0x0A | g | 0x0B | h | 0x0C | i |
| 0x0D | j | 0x0E | k | 0x0F | l |
| 0x10 | ; | 0x11 | ' | 0x12 | ` |
| 0x13 | \ | 0x14 | Enter | 0x15 | Esc |
| 0x16 | Backspace | 0x17 | Tab | 0x18 | Space |
| 0x19 | - | 0x1A | = | 0x1B | [ |
| 0x1C | ] | 0x1D | # | 0x1E | 1 |
| 0x1F | 2 | 0x20 | 3 | 0x21 | 4 |
| 0x22 | 5 | 0x23 | 6 | 0x24 | 7 |
| 0x25 | 8 | 0x26 | 9 | 0x27 | 0 |
| 0x28 | Return | 0x29 | Caps Lock | 0x2A | F1 |
| 0x2B | F2 | 0x2C | F3 | 0x2D | F4 |
| 0x2E | F5 | 0x2F | F6 | 0x30 | F7 |
| 0x31 | F8 | 0x32 | F9 | 0x33 | F10 |
| 0x34 | F11 | 0x35 | F12 | 0x36 | Scroll Lock |

## Troubleshooting

### Wireshark shows no usbhid.* fields
The HID report descriptor wasn't captured. Try:
- Replug the keyboard while capturing
- Fall back to raw `usb.capdata` decoding

### Windows captures show empty device list
USBPcap extcap interface may be missing after Wireshark upgrades. Reinstall USBPcap.

### Nonsense output
You may be mixing multiple devices. Always correlate by `usb.bus_id:device:interface` (e.g., `1.9.1`) before decoding.

### BLE keyboards
Filter on `btatt.value && frame.len == 20` and dump hex payloads before decoding.

## External Tools

- **ctf-usb-keyboard-parser**: Quick CTF challenges
- **CTF-Usb_Keyboard_Parser**: Native pcap/pcapng support, no tshark required
- **USB-HID-decoders**: Keyboard, mouse, and tablet visualizers

## References

- [ctf-usb-keyboard-parser](https://github.com/TeamRocketIst/ctf-usb-keyboard-parser)
- [CTF-Usb_Keyboard_Parser](https://github.com/5h4rrk/CTF-Usb_Keyboard_Parser)
- [USB-HID-decoders](https://github.com/Nissen96/USB-HID-decoders)
