# Mach-O Entitlements Extraction Scripts

This directory contains scripts for extracting and analyzing entitlements from Mach-O binaries and Apple IPSW firmwares.

## Scripts

### extract_entitlements.py
Extract entitlements from individual Mach-O binaries.

**Usage:**
```bash
# Extract from a single binary
python extract_entitlements.py /usr/bin/launchd

# Extract from fat binary with specific architecture
python extract_entitlements.py /path/to/binary --arch arm64

# Output as JSON
python extract_entitlements.py /path/to/binary --json > entitlements.json
```

**Features:**
- Handles both 32-bit and 64-bit Mach-O binaries
- Supports fat (multi-arch) binaries
- Parses LC_CODE_SIGNATURE and SuperBlob structures
- Outputs entitlements as Python dict or JSON

### index_ipsw.py
Mount and index IPSW firmware images into a SQLite database.

**Usage:**
```bash
# Index an IPSW (metadata parsed from filename)
python index_ipsw.py iPhone11,2_15.0_20A362_Restore.ipsw --output entitlements.db

# Index with explicit metadata
python index_ipsw.py firmware.ipsw --output db.sqlite --device iPhone11,2 --version 15.0 --build 20A362
```

**Requirements:**
- `ipsw` tool installed: `npm install -g @blacktop/ipsw`
- `apfs-fuse` for mounting APFS volumes
- Sufficient disk space for mounting

**Database Schema:**
- `device` - Device identifiers (e.g., iPhone11,2)
- `operating_system_version` - OS versions per device
- `executable` - Binary files with paths and hashes
- `entitlement` - Unique entitlement keys and values
- `executable_operating_system_version` - Links binaries to OS versions
- `executable_entitlement` - Links binaries to entitlements

### query_entitlements.py
Query the entitlements database for forensic analysis.

**Usage:**
```bash
# Find all entitlements for an executable
python query_entitlements.py entitlements.db --query by-executable --arg1 launchd

# Find all executables with a specific entitlement
python query_entitlements.py entitlements.db --query by-entitlement --arg1 com.apple.security.network.server

# List executables in an OS version
python query_entitlements.py entitlements.db --query by-version --arg1 15.0

# Find binaries with sensitive entitlements
python query_entitlements.py entitlements.db --query sensitive

# Compare entitlements between versions
python query_entitlements.py entitlements.db --query compare --arg1 14.0 --arg2 15.0
```

## Workflow Example

```bash
# 1. Download IPSW
ipsw download ipsw -y --device iPhone11,2 --latest

# 2. Index the firmware
python index_ipsw.py iPhone11,2_15.0_20A362_Restore.ipsw --output entitlements.db

# 3. Query for sensitive entitlements
python query_entitlements.py entitlements.db --query sensitive

# 4. Compare with previous version
python query_entitlements.py entitlements.db --query compare --arg1 14.0 --arg2 15.0
```

## Troubleshooting

**"Failed to mount IPSW"**: Ensure `ipsw` tool and `apfs-fuse` are installed.

**"No entitlements found"**: The binary may not be code-signed or may use DER entitlements (special slot).

**"Fat binary with multiple architectures"**: Use `--arch` flag to specify target architecture.

## References

- [appledb_rs](https://github.com/synacktiv/appledb_rs) - Large-scale Apple binary indexer
- [ipsw](https://github.com/blacktop/ipsw) - IPSW download and mounting
- [XNU cs_blobs.h](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/cs_blobs.h) - Code signing structures
