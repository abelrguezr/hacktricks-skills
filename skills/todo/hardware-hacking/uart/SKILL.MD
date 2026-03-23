---
name: uart-hacking
description: Hardware hacking skill for UART serial communication, port identification, baud rate detection, and firmware extraction. Use this skill whenever you need to communicate with embedded devices via UART, identify UART pins on a PCB, extract firmware from embedded systems, or work with serial consoles. Trigger this skill for any UART-related tasks including debugging embedded devices, accessing bootloaders, or performing hardware forensics. Make sure to use this skill when the user mentions UART, serial communication, embedded device debugging, firmware extraction, bootloader access, or any hardware hacking involving serial protocols.
---

# UART Hacking Skill

A comprehensive guide for UART serial communication, hardware identification, and firmware extraction from embedded devices.

## Quick Reference

| Task | Tool | Command |
|------|------|--------|
| List serial devices | Linux/Mac | `ls /dev/` |
| Connect to UART | picocom | `picocom /dev/<device> --baud <rate>` |
| Configure minicom | minicom | `minicom -s` |
| Dump firmware | uboot | `md` (memory dump) |
| Extract firmware | binwalk | `binwalk -e <file>.rom` |

## Common Baud Rates

Try these in order when data isn't readable:
- 9600 (most common)
- 19200
- 38400
- 57600
- 115200 (very common for modern devices)

## Hardware Tools

### Required Equipment

- **USB-to-serial adapter** (CP2102 or PL2303 chips recommended)
- **Multimeter** (for pin identification)
- **Logic analyzer** (optional, for signal analysis)
- **Jumper wires** (for connections)

### Alternative Tools

- Bus Pirate
- Adafruit FT232H
- Shikra
- Attify Badge
- Arduino UNO R3 (with removable Atmel 328p chip)

## Identifying UART Pins

UART uses 4 pins: **TX** (Transmit), **RX** (Receive), **Vcc** (Voltage), **GND** (Ground).

### Method 1: Visual Inspection

Look for labels on the PCB:
- Pins may be marked with `TX`, `RX`, `VCC`, `GND`
- Sometimes labeled as `TXD`, `RXD`

### Method 2: Multimeter Detection

**Safety First:** Never confuse GND and VCC - this can fry the circuit!

#### Step 1: Find GND (Device Powered OFF)

1. Set multimeter to **Continuity Test** mode
2. Place black lead on a known ground point
3. Test each pin with red lead until you hear continuity beep
4. Multiple GND pins may exist on the PCB

#### Step 2: Find VCC (Device Powered ON)

1. Set multimeter to **DC Voltage** mode (20V range)
2. Black probe on GND, red probe on target pin
3. Power on the device
4. Look for constant **3.3V or 5V** reading
5. Other voltages indicate a different pin

#### Step 3: Find TX (Device Powered ON)

1. Set multimeter to **DC Voltage** mode (20V range)
2. Black probe on GND, red probe on target pin
3. Power on the device
4. Look for voltage that **fluctuates briefly then stabilizes** at VCC
5. This indicates debug data transmission during boot

#### Step 4: Find RX

1. RX is typically the pin closest to the other 3 UART pins
2. Has the **lowest voltage fluctuation**
3. Has the **lowest overall voltage** of all UART pins

### Troubleshooting Disabled UART

Some manufacturers disable UART by disconnecting RX or TX:

1. Check device warranty - if present, debug interfaces may be disabled
2. Trace circuit board connections to find breakout points
3. Use jumper wires or soldering to reconnect the circuit

## Connecting UART Hardware

### Critical Connection Rule

**Always connect TX to RX and RX to TX!**

```
Adapter TXD  ──────>  Target RXD
Adapter RXD  ──────>  Target TXD
Adapter GND  ──────>  Target GND
Adapter VCC  ──────>  Target VCC (match voltage!)
```

### CP210X Adapter Setup

**Pins:** 5V, GND, RXD, TXD, 3.3V

1. Match voltage to target (3.3V or 5V) - **mismatch can damage device**
2. Connect RXD to target TXD, TXD to target RXD
3. Install CP210X drivers if adapter not detected
4. List devices: `ls /dev/`
5. Connect with: `picocom /dev/<adapter> --baud <baudrate>`

### Arduino UNO R3 as UART Adapter

Use when dedicated adapters unavailable:

1. **Remove** the Atmel 328p chip (must be DIP, not SMD)
2. Connect Arduino RX (Pin 0) to target TX
3. Connect Arduino TX (Pin 1) to target RX
4. Connect GND to target GND
5. Use Arduino IDE Serial Monitor
6. Set baud rate in Tools menu

### Bus Pirate Setup

```bash
# Enter UART mode
UART>m
(1)>3  # Select UART

# Set baud rate (try different values)
(1)>5  # 9600 bps

# Accept defaults for remaining settings
(1)>  # 8 data bits, no parity
(1)>  # 1 stop bit
(1)>  # Idle 1 polarity
(1)>  # Open drain output

# Power on
UART>W

# Monitor data
UART>(2)  # Live UART input monitor
```

## Baud Rate Detection

When data appears garbled, the baud rate is incorrect.

### Manual Detection

1. Connect to TX pin with serial adapter
2. Try common baud rates in order: 9600, 19200, 38400, 57600, 115200
3. Look for readable text output
4. Use `baudrate.py` script for automated detection

### Using baudrate.py

```bash
python baudrate.py /dev/ttyUSB0
```

This script cycles through common baud rates and displays readable output.

## Firmware Extraction

### When to Extract Firmware

- UART console is read-only
- Need to analyze embedded system internals
- Performing security research or forensics
- Firmware stored in EEPROM with volatile processor memory

### Accessing Bootloader (U-Boot)

1. Connect UART to computer
2. **Disconnect power** from target device
3. Open serial console (picocom, minicom, etc.)
4. **Hold Enter key**
5. **Reconnect power** to device
6. Bootloader should interrupt and show menu

### Alternative Bootloader Interrupt Keys

If Enter doesn't work, try:
- Space key
- Ctrl+C
- Ctrl+X
- Esc

### Dumping Firmware with U-Boot

1. Access U-Boot menu (see above)
2. Type `help` to list available commands
3. Use `md` (memory dump) to dump EEPROM contents
4. **Log the serial output** to capture the dump
5. Strip unnecessary data from log
6. Save as `filename.rom`

### Extracting Firmware Contents

```bash
binwalk -e <filename.rom>
```

This extracts files based on signature detection.

### Troubleshooting Bootloader Access

**Bootloader locked?**
- Check UART output during normal boot for U-Boot mentions
- Try different interrupt keys
- Some devices have locked bootloaders that cannot be interrupted

**No UART output?**
- Verify pin identification
- Check baud rate
- Ensure proper voltage levels
- Check for disabled UART (see troubleshooting above)

## Common UART Configurations

### 8N1 (Most Common)

- 8 data bits
- No parity
- 1 stop bit

### Example: Sending Character 'C'

ASCII: 0x43 = 01000011 binary

Transmission sequence:
1. Start bit: 0
2. Data bits: 0, 1, 0, 0, 0, 0, 1, 1
3. Stop bit: 1

## Safety Guidelines

1. **Always verify voltage levels** before connecting VCC
2. **Never connect VCC to GND** - this will damage equipment
3. **Match voltage** between adapter and target (3.3V vs 5V)
4. **Power off** when identifying pins with multimeter
5. **Use current-limited power** when possible
6. **Document pin assignments** before making connections

## Troubleshooting Checklist

- [ ] Correct TX/RX crossover connection?
- [ ] GND connected?
- [ ] Voltage levels match?
- [ ] Correct baud rate?
- [ ] Drivers installed (CP210X, etc.)?
- [ ] Correct device path (`/dev/ttyUSB0`, etc.)?
- [ ] UART not disabled by manufacturer?
- [ ] Bootloader interrupt key correct?

## Next Steps

After establishing UART communication:

1. **Explore the console** - type commands, check help menus
2. **Identify the system** - check version, model, OS
3. **Look for shell access** - try common commands
4. **Dump firmware** if read-only console
5. **Analyze extracted files** with binwalk, strings, etc.

## References

- [baudrate.py](https://github.com/devttys0/baudrate/) - Baud rate detection script
- U-Boot documentation - Bootloader commands
- binwalk - Firmware extraction tool
