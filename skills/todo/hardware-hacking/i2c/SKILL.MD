---
name: i2c-bus-pirate
description: How to use Bus Pirate for I2C communication, testing, and sniffing. Use this skill whenever the user needs to work with I2C devices, test I2C hardware, read/write to I2C memory chips, or sniff I2C bus traffic. Trigger on mentions of I2C, Bus Pirate, EEPROM, EPROM, I2C devices, hardware hacking, or embedded device communication.
---

# I2C Bus Pirate Skill

A skill for working with I2C devices using the Bus Pirate hardware interface.

## Quick Start

### Test Bus Pirate Functionality

Before using the Bus Pirate, verify it's working correctly:

1. Connect VPU to +5V and ADC to 3.3V
2. Access the Bus Pirate via serial terminal (e.g., Tera Term at 115200 baud)
3. Run the self-test command:

```
HiZ>~
```

Expected output shows all tests passing with "Found 0 errors."

### Connect to I2C Device

1. Connect Bus Pirate to target device:
   - SCL → SCL pin
   - SDA → SDA pin
   - GND → GND pin
   - VPU → Power (3.3V or 5V depending on device)

2. Configure I2C mode:

```
HiZ>m
(1)>4              # Select I2C mode
(1)>1              # Select Software mode
(1)>2              # Select speed (~50kHz typical)
I2C>W              # Power supplies ON
```

## Core Operations

### Find I2C Devices

Scan the bus to discover connected devices:

```
I2C>(0)            # Open macro menu
I2C>(1)            # Run 7-bit address search
```

Output shows device addresses in format: `0xA0(0x50 W) 0xA1(0x50 R)`
- Write address (e.g., 0xA0) for sending data
- Read address (e.g., 0xA1) for receiving data

### Write to I2C Device

Write data to a specific address:

```
I2C>[0xA0 0x00 0x69 0x42 0x42 0x42]
```

Format: `[device_address high_byte low_byte data_bytes...]`

Example: Write "BBB" (0x42 0x42 0x42) to address 0x69 on device 0xA0

### Read from I2C Device

Two-step process:

1. Set the read address:
```
I2C>[0xA0 0x00 0x69]
```

2. Read data:
```
I2C>[0xA1 r:20]    # Read 20 bytes from address 0x69
```

### Sniff I2C Traffic

Monitor communication between two devices:

1. Connect Bus Pirate to SCL, SDA, and GND of the target bus
2. Configure I2C mode (same as above)
3. Start sniffer:

```
I2C>(2)            # Start I2C sniffer
```

Captured traffic appears as: `[0xA0+0x00+0x69+0x41+...]`

## Command Reference

| Command | Description |
|---------|-------------|
| `~` | Run self-test |
| `i` | Show Bus Pirate info |
| `v` | Check voltages |
| `m` | Mode menu |
| `W` | Power supplies ON |
| `(0)` | Macro menu |
| `(1)` | Address search |
| `(2)` | I2C sniffer |
| `[addr data...]` | Write command |
| `[addr r:n]` | Read n bytes |

## Common I2C Devices

| Device | Typical Address | Notes |
|--------|-----------------|-------|
| 24C256 EEPROM | 0xA0/0xA1 | 32Kbit, 5V tolerant |
| AT24C02 | 0xA0/0xA1 | 256 byte EEPROM |
| MCP23017 | 0x20-0x27 | GPIO expander |
| PCF8575 | 0x20-0x27 | 16-channel GPIO |

## Troubleshooting

### No devices found
- Check wiring (SCL, SDA, GND)
- Verify pull-up resistors are present (4.7kΩ typical)
- Ensure device is powered
- Try different speed settings

### Communication errors
- Verify voltage levels match device requirements
- Check for bus conflicts (multiple devices on same address)
- Ensure proper termination

### Sniffer not capturing
- Confirm Bus Pirate is powered (command `W`)
- Verify connections to SCL/SDA
- Check baud rate matches actual bus speed

## Best Practices

1. Always run self-test before critical operations
2. Use address search to verify device presence
3. Start with slower speeds (~50kHz) for compatibility
4. Keep I2C bus lines short (<30cm)
5. Use proper pull-up resistors on SCL and SDA
6. Power down Bus Pirate when not in use to prevent bus conflicts
