---
name: ibutton-hacking
description: How to read, analyze, and work with iButton (Dallas Touch Memory) access keys using Flipper Zero. Use this skill whenever the user mentions iButton, Dallas keys, 1-Wire protocol, Flipper Zero access control, physical access keys, or wants to read/emulate/analyze contact-based access systems. This skill covers the complete workflow from understanding the technology to practical operations with Flipper Zero.
---

# iButton Hacking with Flipper Zero

A practical guide to working with iButton (Dallas Touch Memory) access control systems using Flipper Zero.

## What is iButton?

iButton is a generic name for electronic identification keys packed in a **coin-shaped metal container**. Also called **Dallas Touch Memory** or contact memory. Despite being commonly called "magnetic" keys, there is **nothing magnetic** in them - they contain a full microchip operating on a digital protocol.

### Physical Characteristics

- **Form factor**: Round coin with two contacts
- **Holders**: Plastic holder with hole, rings, pendants, etc.
- **Operation**: Contacts touch the reader, key is powered, ID is transmitted

## How iButton Works

### The 1-Wire Protocol

Dallas keys exchange data using the **1-Wire protocol**:

- **Single contact** for bidirectional data transfer (master to slave and vice versa)
- **Master-Slave topology**: Master always initiates communication, Slave follows instructions
- **Power delivery**: The key is powered by the reader when contacts touch

### Communication Flow

1. Key (Slave) contacts the intercom/reader (Master)
2. Chip inside the key turns on, powered by the intercom
3. Key is initialized
4. Intercom requests the key ID
5. Key transmits its ID

### Flipper Zero Modes

Flipper Zero can operate in both modes:

| Mode | Role | Function |
|------|------|----------|
| **Key Reading** | Master | Acts as a reader |
| **Key Emulation** | Slave | Pretends to be a key |

## Key Types

### Dallas Keys

The most common iButton type. Uses the standard 1-Wire protocol with a 64-bit ROM code.

### Cyfral Keys

Polish variant with different encoding. Requires specific handling.

### Metakom Keys

Another regional variant with its own protocol specifics.

For detailed technical information about how these keys work, refer to: https://blog.flipperzero.one/taming-ibutton/

## Reading iButton Keys with Flipper Zero

### Step-by-Step Process

1. **Navigate to iButton interface** on Flipper Zero
2. **Select "Read" mode** (Master mode)
3. **Touch the key to the reader contacts** on Flipper
4. **Wait for ID to be captured**
5. **Save the key** to your Flipper's storage

### Troubleshooting Reading Issues

**Problem**: Key is not read immediately

**Cause**: The contact PSD (pressure sensitive device) of the intercom/reader may be larger than expected, preventing proper contact between the outer contours of the key and reader.

**Solution**: Press the key firmly over one of the walls/edges of the reader to ensure contact.

**Problem**: Inconsistent reads

**Solutions**:
- Ensure clean, dry contacts on both key and reader
- Apply firm, steady pressure
- Try different angles of contact
- Check for corrosion or damage on the key

## Common Issues and Solutions

### Contact Issues

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| No read at all | Poor contact | Press harder, try different angle |
| Intermittent reads | Dirty contacts | Clean with alcohol |
| Wrong ID read | Multiple keys nearby | Isolate the key |

### Power Issues

- iButtons draw power from the reader - ensure the reader is powered
- Some readers have weak power delivery - try holding contact longer

### Protocol Issues

- Dallas, Cyfral, and Metakom keys use different encoding
- Flipper Zero should auto-detect, but may need manual selection
- If reads fail, try different key type settings

## Practical Applications

### Access Control Analysis

- Read and document all keys in a facility
- Identify key types and protocols in use
- Map access levels to specific keys

### Key Cloning

- Read original key
- Save to Flipper
- Emulate to test access
- **Note**: Only clone keys you own or have permission to work with

### Security Assessment

- Test if access control systems properly validate keys
- Check for replay attack vulnerabilities
- Assess physical security of key storage

## Best Practices

### When Reading Keys

1. **Document everything**: Record key IDs, locations, and access levels
2. **Test thoroughly**: Verify reads work consistently before relying on them
3. **Respect authorization**: Only work with keys you own or have permission to test
4. **Keep backups**: Save key data in multiple locations

### When Emulating Keys

1. **Verify the read**: Make sure you captured the correct ID
2. **Test in controlled environment**: Don't test on production systems without permission
3. **Monitor for issues**: Some systems detect cloned/emulated keys

## References

- [Flipper Zero iButton Guide](https://blog.flipperzero.one/taming-ibutton/)
- [1-Wire Protocol Specification](https://www.maximintegrated.com/en/design/design-help/design-resources/1-wire-protocol.html)
- [Dallas Semiconductor iButton Documentation](https://www.maximintegrated.com/en/products/design-center/ibutton.html)

## Quick Reference

### Flipper Zero iButton Commands

```
iButton Menu:
├── Read          - Capture key ID (Master mode)
├── Emulate       - Act as a key (Slave mode)
├── Generate      - Create test keys
└── Settings      - Configure options
```

### Key ID Format

- **Dallas**: 64-bit ROM code (8 bytes)
- **Format**: Typically displayed as hex string
- **Example**: `01 23 45 67 89 AB CD EF`

### When to Use This Skill

Use this skill when you need to:
- Read iButton/Dallas keys with Flipper Zero
- Understand 1-Wire protocol operation
- Troubleshoot iButton reading issues
- Work with physical access control systems
- Analyze or emulate contact-based access keys
- Learn about iButton security and vulnerabilities
