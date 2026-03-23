---
name: macho-entitlements-extractor
description: Extract entitlements from Mach-O binaries and index Apple IPSW firmwares for forensic analysis. Use this skill whenever you need to analyze iOS/macOS binaries for security entitlements, enumerate privileged capabilities across firmware versions, or perform attack surface mapping on Apple platforms. Trigger this skill for any request involving Mach-O parsing, code signature analysis, entitlement extraction, IPSW mounting, or Apple platform forensics—even if the user doesn't explicitly mention "entitlements" or "Mach-O".
---

# Mach-O Entitlements Extraction & IPSW Indexing

This skill enables forensic extraction of entitlements from Mach-O binaries and scalable indexing across Apple IPSW firmwares for security research and attack surface mapping.

## When to Use This Skill

Use this skill when the user needs to:
- Extract entitlements from iOS/macOS binaries (Mach-O format)
- Parse code signatures and SuperBlob structures
- Enumerate privileged capabilities in Apple binaries
- Mount and index IPSW firmware images
- Compare entitlements across OS versions or devices
- Perform Apple platform security research or forensics
- Analyze code signing data in Mach-O files

## Core Capabilities

### 1. Entitlement Extraction from Mach-O Binaries

Extract entitlements by parsing the `LC_CODE_SIGNATURE` load command and walking the code signing SuperBlob to find the entitlements blob (type `0xfade7171`). The entitlements are stored as an Apple Binary Property List (bplist00).

**Key structures:**
- `LC_CODE_SIGNATURE` (cmd=0x1d) - Points to code signature data in `__LINKEDIT`
- `CS_SuperBlob` (magic=0xfade0cc0) - Container for all signature blobs
- `CS_GenericBlob` (type=0xfade7171) - Contains entitlements as bplist

### 2. IPSW Mounting and Indexing

Scale entitlement extraction across firmware images by mounting IPSW filesystems and indexing executables into a searchable database.

## Quick Start

### Extract entitlements from a single binary

```bash
python scripts/extract_entitlements.py /path/to/binary
```

This outputs entitlements as JSON. For validation on macOS:
```bash
codesign -d --entitlements :- /path/to/binary
```

### Index an IPSW firmware

```bash
# Download IPSW (requires ipsw tool)
ipsw download ipsw -y --device iPhone11,2 --latest

# Mount and index
python scripts/index_ipsw.py <IPSW_FILE> --output entitlements.db
```

## Detailed Workflow

### Step 1: Parse Mach-O Header

1. Read the Mach-O magic number to determine 32-bit vs 64-bit
2. Extract `ncmds` (number of load commands) and `sizeofcmds`
3. Iterate through load commands starting at offset 0x20 (64-bit) or 0x18 (32-bit)

### Step 2: Locate Code Signature

1. Find `LC_CODE_SIGNATURE` (cmd=0x1d) in load commands
2. Read `dataoff` and `datasize` from `linkedit_data_command`
3. Map the SuperBlob from `__LINKEDIT` segment

### Step 3: Walk SuperBlob

1. Validate `CS_SuperBlob.magic == 0xfade0cc0`
2. Read `count` to get number of blob indices
3. Iterate `CS_BlobIndex` entries (8 bytes each after 12-byte header)
4. Find entry with `type == 0xfade7171` (embedded entitlements)

### Step 4: Decode Entitlements

1. Read `CS_GenericBlob` at the entitlements offset
2. Extract bplist data (after 8-byte big-endian header)
3. Parse with `plistlib.loads()` to get key/value entitlements

### Step 5: Handle Fat Binaries (Multi-Arch)

For universal binaries:
1. Check for `FAT_MAGIC` (0xcafebabe) or `FAT_MAGIC_64` (0xcefaedfe)
2. Read `fat_arch` entries to find desired architecture
3. Extract the slice and pass to entitlement parser

## Database Schema for Indexing

When scaling across IPSWs, use this normalized schema:

```sql
-- Core tables
CREATE TABLE device (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,  -- e.g., "iPhone11,2"
    model TEXT           -- e.g., "iPhone XS"
);

CREATE TABLE operating_system_version (
    id INTEGER PRIMARY KEY,
    device_id INTEGER REFERENCES device(id),
    version TEXT NOT NULL,  -- e.g., "15.0"
    build TEXT,             -- e.g., "20A362"
    ipsw_path TEXT
);

CREATE TABLE executable (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,     -- e.g., "launchd"
    path TEXT NOT NULL,     -- Full path in firmware
    sha256 TEXT             -- For deduplication
);

CREATE TABLE entitlement (
    id INTEGER PRIMARY KEY,
    key TEXT NOT NULL,      -- e.g., "com.apple.security.network.server"
    value TEXT              -- e.g., "true" or JSON array
);

-- Many-to-many relationships
CREATE TABLE executable_operating_system_version (
    executable_id INTEGER REFERENCES executable(id),
    operating_system_version_id INTEGER REFERENCES operating_system_version(id),
    PRIMARY KEY (executable_id, operating_system_version_id)
);

CREATE TABLE executable_entitlement (
    executable_id INTEGER REFERENCES executable(id),
    entitlement_id INTEGER REFERENCES entitlement(id),
    PRIMARY KEY (executable_id, entitlement_id)
);
```

## Example Queries

### Find all OS versions containing a specific executable
```sql
SELECT osv.version AS "Versions"
FROM device d
LEFT JOIN operating_system_version osv ON osv.device_id = d.id
LEFT JOIN executable_operating_system_version eosv ON eosv.operating_system_version_id = osv.id
LEFT JOIN executable e ON e.id = eosv.executable_id
WHERE e.name = "launchd";
```

### Find executables with sensitive entitlements
```sql
SELECT e.name, e.path, ent.key, ent.value
FROM executable e
JOIN executable_entitlement ee ON e.id = ee.executable_id
JOIN entitlement ent ON ee.entitlement_id = ent.id
WHERE ent.key LIKE '%kernel%' OR ent.key LIKE '%rootless%';
```

### Compare entitlements between OS versions
```sql
SELECT e.name, v1.version AS "Old", v2.version AS "New"
FROM executable e
JOIN executable_entitlement ee1 ON e.id = ee1.executable_id
JOIN executable_operating_system_version eosv1 ON e.id = eosv1.executable_id
JOIN operating_system_version v1 ON eosv1.operating_system_version_id = v1.id
JOIN executable_operating_system_version eosv2 ON e.id = eosv2.executable_id
JOIN operating_system_version v2 ON eosv2.operating_system_version_id = v2.id
WHERE v1.version = '14.0' AND v2.version = '15.0'
GROUP BY e.name, v1.version, v2.version
HAVING COUNT(DISTINCT ee1.entitlement_id) != COUNT(DISTINCT ee2.entitlement_id);
```

## Sensitive Entitlements to Watch For

These entitlements indicate elevated privileges:

| Entitlement | Meaning |
|-------------|----------|
| `com.apple.security.network.server` | Can bind to network ports |
| `com.apple.rootless.storage.*` | Access to protected system paths |
| `com.apple.private.kernel.*` | Kernel-level operations |
| `com.apple.private.pmap.*` | Process memory access |
| `com.apple.security.get-task-allow` | Debugging/attach permissions |
| `com.apple.security.app-sandbox` | Sandbox status (false = no sandbox) |

## Tooling and Dependencies

### Required Tools
- `ipsw` - Download and mount IPSW firmwares (https://github.com/blacktop/ipsw)
- `apfs-fuse` - Mount APFS volumes (bundled with ipsw)
- Python 3.8+ with `plistlib` (stdlib)

### Optional Tools
- `codesign` - macOS validation tool
- `otool` - Mach-O inspection
- SQLite or PostgreSQL - For indexing

## References

- [appledb_rs](https://github.com/synacktiv/appledb_rs) - Large-scale Apple binary indexer
- [ipsw](https://github.com/blacktop/ipsw) - IPSW download and mounting
- [entdb](https://github.com/ChiChou/entdb) - Entitlement database
- [Jonathan Levin's entitlement DB](https://newosxbook.com/ent.php) - Entitlement reference
- [XNU cs_blobs.h](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/cs_blobs.h) - Code signing structures
- [XNU loader.h](https://github.com/apple-oss-distributions/xnu/blob/main/EXTERNAL_HEADERS/mach-o/loader.h) - Mach-O structures

## Bundled Scripts

- `scripts/extract_entitlements.py` - Extract entitlements from Mach-O binaries
- `scripts/index_ipsw.py` - Mount and index IPSW firmwares into database

Run `python scripts/extract_entitlements.py --help` for usage details.
