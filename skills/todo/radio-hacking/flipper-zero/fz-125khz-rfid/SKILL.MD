---
name: flipper-zero-125khz-rfid
description: How to use Flipper Zero for 125kHz RFID operations including reading, emulating, and writing RFID tags. Use this skill whenever the user mentions Flipper Zero, RFID, 125kHz tags, EM Marin, HID cards, access control systems, intercoms, or wants to work with low-frequency RFID technology.
---

# Flipper Zero 125kHz RFID Operations

A guide for working with 125kHz RFID tags using Flipper Zero.

## Quick Start

1. Navigate to **RFID** in the Flipper Zero menu
2. Select **125kHz** mode
3. Choose your operation: Read, Emulate, or Add Manually

## Reading RFID Cards

### Basic Read

1. Hold the Flipper Zero near the RFID card/tag
2. The device will attempt to read the card info
3. If successful, the card data is saved and can be emulated

### Important Warning

Some intercoms try to protect themselves from key duplication by sending a write command prior to reading. If the write succeeds, that tag is considered fake. When Flipper emulates RFID there is no way for the reader to distinguish it from the original one, so no such problems occur.

## Adding Cards Manually

You can create fake cards in Flipper Zero by indicating the data manually and then emulate it.

### Finding IDs on Physical Cards

Sometimes the ID (or part of it) is printed on the card itself:

#### EM Marin Cards

- The last 3 of 5 bytes are visible in clear on the physical card
- The other 2 bytes can be brute-forced if you cannot read them from the card

#### HID Cards

- Only 2 out of 3 bytes are typically printed on the card
- The remaining byte(s) may need to be discovered through other means

## Emulating and Writing

After copying a card or entering the ID manually, you can:

### Emulate

- Select the saved card from your Flipper Zero
- Choose **Emulate** to act as that card
- Hold near the reader to authenticate

### Write to Real Card

- Select the saved card data
- Choose **Write** to program a blank RFID card
- Hold the blank card near the Flipper Zero

## Workflow Summary

```
Read Card → Save to Flipper → Emulate OR Write to Blank Card
     ↓
Add Manually (if ID known) → Emulate OR Write to Blank Card
```

## References

- [Flipper Zero RFID Blog](https://blog.flipperzero.one/rfid/)
- For more info about how 125kHz tags work, see the pentesting-rfid documentation

## Tips

- Always test emulation before relying on it for access
- Keep backups of important card data
- Some systems may have additional security beyond simple RFID
- Document which cards you've copied for future reference
