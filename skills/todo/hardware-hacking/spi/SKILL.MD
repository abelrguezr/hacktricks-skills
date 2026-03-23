---
name: spi-firmware-dumping
description: How to dump firmware from SPI EEPROM chips using CH341A programmer or Bus Pirate, and analyze the extracted firmware. Use this skill whenever the user mentions SPI, EEPROM, firmware extraction, chip dumping, CH341A, Bus Pirate, flashrom, or needs to extract firmware from embedded devices for analysis, reverse engineering, or security testing. Also trigger when users want to analyze embedded device firmware, extract binaries from hardware, or work with SPI communication protocols.
---

# SPI Firmware Dumping and Analysis

This skill helps you dump firmware from SPI EEPROM chips and analyze the extracted binaries for security research, reverse engineering, or embedded device analysis.

## Understanding SPI Communication

SPI (Serial Peripheral Interface) is a synchronous serial communication protocol used in embedded systems. Key concepts:

- **Master-Slave Architecture**: A master (microprocessor) controls slave devices (EEPROM, sensors, etc.)
- **Clock Signal**: Synchronizes data transfer between master and slave
- **Chip Select (CS)**: Low = slave selected, High = slave deselected
- **MOSI** (Master Out, Slave In): Data sent to slave
- **MISO** (Master In, Slave Out): Data received from slave

Multiple slaves can connect to one master, but slaves cannot communicate with each other.

## Hardware Setup

### Option 1: CH341A EEPROM Programmer

The CH341A is an inexpensive USB-based tool for reading/writing EEPROM chips.

**Setup Steps:**

1. Connect the EEPROM chip to the CH341A programmer
2. Plug the programmer into your computer via USB
3. Install drivers if the device isn't detected
4. **Critical**: Orient the EEPROM correctly - place the VCC pin in reverse orientation to the USB connector
5. Verify connection using G-Flash or flashrom

**Dumping with G-Flash (GUI):**

```bash
# G-Flash automatically detects the EEPROM
# Use the GUI to read and save the firmware
```

**Dumping with flashrom (CLI):**

```bash
# Basic dump command
flashrom -p ch341a_spi -r firmware.bin
```

### Option 2: Bus Pirate + flashrom

The Bus Pirate is a versatile hardware tool that can interface with SPI devices.

**Pin Mapping:**

- MOSI → DI (Data In)
- MISO → DO (Data Out)
- Connect according to your Bus Pirate's pinout diagram

**Dumping Command:**

```bash
# -VV: Verbose output
# -c: Chip model (optional, omit if unknown)
# -p: Programmer interface
# -r: Output file path
flashrom -VV -c "W25Q64.V" -p buspirate_spi:dev=COM3 -r flash_content.img
```

**Linux example:**

```bash
flashrom -VV -p buspirate_spi:dev=/dev/ttyUSB0 -r firmware.bin
```

## Firmware Analysis

Once you've dumped the firmware, use these tools to extract information:

### Quick Inspection

```bash
# Extract readable strings
strings firmware.bin > strings_output.txt

# View hex dump
hexdump -C firmware.bin | head -100

# Alternative hex viewer
xxd firmware.bin | head -100
```

### Deep Analysis with binwalk

Binwalk identifies file signatures and extracts embedded files:

```bash
# Extract all embedded files
binwalk -e firmware.bin

# Extract with verbose output
binwalk -e -v firmware.bin

# Show file signatures without extraction
binwalk -t firmware.bin
```

### Common Analysis Workflow

1. **Initial inspection**: Run `strings` to find passwords, URLs, or interesting text
2. **File extraction**: Use `binwalk -e` to extract embedded filesystems
3. **Binary analysis**: Use tools like `objdump`, `radare2`, or `Ghidra` on extracted binaries
4. **Configuration search**: Look for hardcoded credentials, API keys, or network settings

## Safety Warnings

⚠️ **Critical precautions:**

- Firmware extraction is delicate - mishandling can corrupt or erase the firmware
- Always study the specific device before attempting extraction
- Some chips may be write-protected or require specific voltage levels
- Backup the original firmware before attempting to reflash
- Verify chip orientation before connecting power
- Some devices may become unusable if firmware is corrupted

## Troubleshooting

**Device not detected:**
- Check USB drivers are installed
- Verify chip orientation (VCC pin position)
- Try a different USB port
- Check physical connections

**Read errors:**
- Verify chip model in flashrom command
- Check voltage requirements match the chip
- Ensure proper grounding
- Try different read speeds

**Incomplete dumps:**
- Verify chip size matches expected firmware size
- Check for write-protected regions
- Some chips require specific read sequences

## When to Use This Skill

Use this skill when you need to:
- Extract firmware from embedded devices for security analysis
- Dump EEPROM chips for reverse engineering
- Analyze SPI communication protocols
- Work with hardware hacking or physical security testing
- Extract binaries from devices where source code isn't available
- Prepare firmware for vulnerability research or backdoor analysis
