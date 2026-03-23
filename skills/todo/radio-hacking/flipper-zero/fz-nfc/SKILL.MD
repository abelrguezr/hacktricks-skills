---
name: flipper-zero-nfc
description: How to use Flipper Zero for NFC card operations including reading, analyzing, and emulating NFC cards. Use this skill whenever the user mentions Flipper Zero, NFC cards, RFID, EMV bank cards, Mifare cards, NTAG, or wants to work with contactless smart cards, even if they don't explicitly ask for Flipper Zero help.
---

# Flipper Zero NFC Operations

A skill for working with Flipper Zero's NFC capabilities.

## Overview

Flipper Zero supports NFC (ISO 14443) operations for reading, analyzing, and emulating various card types. This skill covers the supported card types, reading procedures, and important limitations.

## Supported Card Types

### NFC Type A (ISO 14443A)

| Card Type | Read | Save | Emulate |
|-----------|------|------|---------|
| **Bank cards (EMV)** | UID, SAK, ATQA | ❌ No | ❌ No |
| **Unknown cards** | UID, SAK, ATQA | ✅ Yes | UID only |
| **Mifare Classic** | Full data | ✅ Yes | ✅ Yes |
| **Mifare Ultralight** | Full data | ✅ Yes | ✅ Yes |
| **NTAG** | Full data | ✅ Yes | ✅ Yes |

### NFC Type B, F, and V

- **Read UID only** — No saving capability
- **No emulation** — Cannot emulate these card types

## Reading Operations

### Low-Level Read

Reads only the UID, SAK, and ATQA. Flipper attempts to identify the card type from this data, though this identification isn't always reliable.

**When to use:**
- First step for any unknown card
- When you only need the UID for primitive readers
- When high-level protocol is unknown

### High-Level Read

Reads data from card memory using specific protocols:

- **Mifare Classic:** Read sectors and keys
- **Mifare Ultralight:** Read memory pages
- **EMV:** Read card attributes (number, expiry, name, transactions)

**When to use:**
- After low-level read identifies card type
- When you need actual card data, not just UID

### Read Specific Card Type

When automatic detection fails, manually select the card type in Extra Actions.

**Steps:**
1. Navigate to Extra Actions
2. Select "Read Specific Card Type"
3. Choose the card type you want to read
4. Hold card to Flipper antenna

## EMV Bank Cards

### What You Can Read

- ✅ Full card number (16 digits on front)
- ✅ Validity date
- ✅ Owner's name (sometimes)
- ✅ Recent transactions (sometimes)

### What You Cannot Read

- ❌ CVV (3 digits on back)
- ❌ Cannot emulate for payment (protected from replay attacks)

### Important Warning

Bank cards are protected from replay attacks. Copying a bank card with Flipper and trying to emulate it for payment **will not work**. This is a security feature of EMV cards.

## Important Limitations

1. **Bank cards cannot be emulated for payment** — Protected from replay attacks
2. **Type B, F, V cards** — UID only, no saving or emulation
3. **Unknown cards** — Only UID emulation possible, no data access
4. **Not all ISO 14443 protocols** — Flipper doesn't understand all high-level protocols
5. **UID-only readers** — Some primitive readers use UID for authorization; these can be emulated

## Workflow

### Standard Reading Process

1. **Identify card type** — Use low-level read first
2. **Attempt high-level read** — If card type is known and supported
3. **Manual selection** — If automatic detection fails, use "Read Specific Card Type"
4. **Save and emulate** — If supported by card type

### When Automatic Detection Fails

1. Go to Extra Actions
2. Select "Read Specific Card Type"
3. Manually choose the card type
4. Hold card to antenna
5. Save if successful

## Common Use Cases

### Reading Access Cards

Many access control systems use Mifare Classic or similar cards. Flipper can:
- Read the card data
- Save to internal storage
- Emulate the card for access

### Analyzing Unknown Cards

When you encounter an unknown card:
1. Perform low-level read to get UID, SAK, ATQA
2. Check if Flipper identifies the type
3. If not, try manual card type selection
4. Document the card characteristics for further research

### Testing NFC Readers

Flipper can help test NFC reader security by:
- Emulating known cards
- Testing UID-only authentication
- Identifying weak access controls

## References

- [Flipper Zero RFID Blog](https://blog.flipperzero.one/rfid/)
- [HackTricks Pentesting RFID](../pentesting-rfid.md)
- [ISO 14443 Standard](https://en.wikipedia.org/wiki/ISO/IEC_14443)

## Safety and Ethics

- Only use Flipper Zero on cards you own or have permission to test
- Do not use for unauthorized access or payment fraud
- Understand local laws regarding RFID/NFC testing
- Use responsibly for security research and education
