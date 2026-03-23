---
name: synology-archive-decryption
description: Decrypt Synology PAT/SPK encrypted firmware and application archives to extract their contents. Use this skill whenever the user needs to analyze Synology NAS firmware, extract packages from .pat or .spk files, inspect Synology system updates, or reverse engineer Synology applications. Trigger on mentions of Synology, DSM, BSM, PAT files, SPK files, firmware extraction, or NAS package analysis.
---

# Synology Archive Decryption

Decrypt Synology PAT (system update) and SPK (application) encrypted archives to recover the underlying TAR contents.

## When to Use This Skill

Use this skill when:
- The user has a `.pat` or `.spk` file and wants to extract its contents
- The user needs to analyze Synology firmware or applications
- The user mentions Synology NAS, DSM, BSM, or firmware extraction
- The user wants to inspect what's inside a Synology package

## Quick Start

```bash
# Decrypt an SPK or PAT file
python3 scripts/decrypt_synology_archive.py <archive-file>

# Extract the resulting TAR
tar xf <output>.tar
```

## How It Works

Synology encrypts their firmware and application packages using hard-coded keys embedded in their extraction libraries. This skill automates the decryption process:

1. **Detect archive type** - PAT (system) or SPK (application)
2. **Verify header signature** - Ed25519 signature validation
3. **Derive encryption key** - Using the hard-coded master key and archive-specific subkey
4. **Decrypt with XChaCha20-Poly1305** - Stream decryption of all entries
5. **Output clean TAR** - Standard tar archive ready for extraction

## Archive Structure

### PAT Files (System Updates)
```
.pat (encrypted archive)
├── Header (MessagePack + Ed25519 signature)
├── Encrypted entries (XChaCha20-Poly1305)
└── → .tar (decrypted output)
    ├── hda1.tgz (root filesystem)
    ├── rd.bin (initramfs)
    ├── packages/ (embedded SPKs)
    └── ...
```

### SPK Files (Applications)
```
.spk (encrypted archive)
├── Header (MessagePack + Ed25519 signature)
├── Encrypted entries (XChaCha20-Poly1305)
└── → .tar (decrypted output)
    ├── app/ (application files)
    ├── conf/ (configuration)
    └── ...
```

## Key Technical Details

### Cryptographic Components

| Component | Purpose | Algorithm |
|-----------|---------|----------|
| signature_key | Verify archive header | Ed25519 |
| master_key | Derive per-archive key | Hard-coded 128-bit |
| subkey_id | Archive-specific identifier | uint64 at offset 0x10 |
| stream_key | Actual encryption key | crypto_kdf_derive_from_key |
| nonce | Per-chunk IV | 18 bytes, prepended to ciphertext |
| cipher | Data encryption | XChaCha20-Poly1305 secretstream |

### File Format

1. **Magic bytes**: `0xBFBAAD` or `0xADBEEF` (3 bytes)
2. **Header length**: Little-endian uint32
3. **Header data**: MessagePack-encoded metadata
4. **Signature**: 64-byte Ed25519 signature
5. **Encrypted data**: Chunks of up to 0x400000 + 0x11 bytes

## Usage Examples

### Example 1: Decrypt a System Update
```bash
# Download a PAT file
wget https://archive.synology.com/download/Os/BSM/BSM_BST150-4T_65374.pat

# Decrypt it
python3 scripts/decrypt_synology_archive.py BSM_BST150-4T_65374.pat

# Extract the contents
tar xf BSM_BST150-4T_65374.tar
```

### Example 2: Decrypt an Application Package
```bash
# Decrypt an SPK
python3 scripts/decrypt_synology_archive.py SynologyPhotos-rtd1619b-1.7.0-0794.spk

# Inspect the application
tar xf SynologyPhotos-rtd1619b-1.7.0-0794.tar
ls -la app/
```

### Example 3: Inspect PAT Structure First
```bash
# Optional: dump PAT structure to see what's inside
python3 scripts/inspect_pat_structure.py BSM_BST150-4T_65374.pat

# Then decrypt specific embedded packages
python3 scripts/decrypt_synology_archive.py packages/SomeApp.spk
```

## Common Issues

### "No matching keys found"
- The archive may be from a DSM version not yet in the key database
- Check if the file is actually a valid PAT/SPK: `file yourfile.pat`
- Try extracting from a different DSM version

### "Signature verification failed"
- The archive may be corrupted or modified
- Ensure the file was downloaded completely
- Check for network corruption during download

### "Invalid archive format"
- Verify the magic bytes: `xxd -l 4 yourfile.pat`
- Should show `bf ba ad` or `ad be ef`
- The file may not be a Synology archive

### "Decryption failed at offset X"
- The archive may be truncated
- Check file size matches expected download size
- Try re-downloading the archive

## Dependencies

Required Python packages:
```bash
pip install msgpack pycryptodomex
```

Optional for PAT inspection:
```bash
pip install patology  # or use the bundled script
```

## Security Notes

- This skill uses publicly documented hard-coded keys from Synology's own libraries
- The decryption is performed offline - no network access required
- All keys are embedded in the official Synology extraction tools
- This is for legitimate firmware analysis and security research

## References

- [Synacktiv Research - Pwn2Own Ireland 2024](https://www.synacktiv.com/publications/extraction-des-archives-chiffrees-synology-pwn2own-irlande-2024.html)
- [synodecrypt on GitHub](https://github.com/synacktiv/synodecrypt)
- [patology on GitHub](https://github.com/sud0woodo/patology)
- [libsodium documentation](https://doc.libsodium.org/)
