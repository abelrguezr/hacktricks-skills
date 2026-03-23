---
name: local-cloud-storage-forensics
description: Use this skill whenever investigating Windows systems for cloud storage artifacts, analyzing OneDrive/Google Drive/Dropbox data, recovering synchronized file information, or examining local cloud storage client configurations. Trigger this skill for any digital forensics task involving cloud storage synchronization logs, database analysis, or artifact extraction from OneDrive, Google Drive, or Dropbox installations.
---

# Local Cloud Storage Forensics

This skill helps you extract forensic artifacts from local cloud storage clients on Windows systems. Cloud storage clients leave behind valuable evidence including file metadata, synchronization history, account information, and even deleted file records.

## Why This Matters

Cloud storage artifacts can reveal:
- What files were synchronized and when
- Account credentials and identifiers
- Deleted files that no longer exist in the cloud
- User activity patterns and file access history
- Cross-references between local and cloud file systems

## Quick Reference: Artifact Locations

| Service | Primary Path | Key Artifacts |
|---------|--------------|---------------|
| OneDrive | `\Users\<user>\AppData\Local\Microsoft\OneDrive` | SyncDiagnostics.log, CID files |
| Google Drive | `\Users\<user>\AppData\Local\Google\Drive\user_default` | Sync_log.log, Cloud_graph.db, Sync_config.db |
| Dropbox | `\Users\<user>\AppData\Local\Dropbox` | *.dbx encrypted databases |

---

## OneDrive Analysis

### Finding OneDrive Artifacts

OneDrive stores synchronization logs and configuration data in:
```
\Users\<username>\AppData\Local\Microsoft\OneDrive\logs\Personal\SyncDiagnostics.log
```

### What SyncDiagnostics.log Contains

This log file provides:
- File sizes in bytes
- Creation and modification dates
- File counts (cloud vs local)
- **CID (Customer ID)**: Unique OneDrive user identifier
- Report generation timestamps
- OS hard drive size

### Extracting the CID

The CID is critical for finding additional artifacts. Use the helper script:

```bash
python scripts/extract_onedrive_cid.py <path-to-SyncDiagnostics.log>
```

Or manually search for the CID pattern in the log file.

### CID-Based Artifact Hunting

Once you have the CID, search the system for files containing this ID:
- `<CID>.ini` - Configuration files
- `<CID>.dat` - Data files with synchronized file names

These files often contain file names and metadata not visible elsewhere.

### Example Workflow

**Input:** You need to find what files a user synchronized to OneDrive

**Steps:**
1. Locate `SyncDiagnostics.log` in the user's OneDrive logs folder
2. Extract the CID from the log
3. Search the system for `<CID>.ini` and `<CID>.dat` files
4. Parse these files for file names and timestamps

---

## Google Drive Analysis

### Finding Google Drive Artifacts

Google Drive for Desktop stores data in:
```
\Users\<username>\AppData\Local\Google\Drive\user_default\
```

### Key Artifacts

#### Sync_log.log

This text log contains:
- Account email address
- File names (including deleted files)
- Timestamps
- MD5 hashes of files

**Why this matters:** Deleted files still appear in this log with their MD5 hashes, allowing you to track file history even after deletion.

#### Cloud_graph.db (SQLite)

This database contains the `cloud_graph_entry` table with:
- File names of synchronized files
- Modified timestamps
- File sizes
- MD5 checksums

Query it with:
```bash
python scripts/query_gdrive_db.py <path-to-Cloud_graph.db> cloud_graph_entry
```

#### Sync_config.db (SQLite)

This database contains:
- Account email address
- Shared folder paths
- Google Drive version information

---

## Dropbox Analysis

### Finding Dropbox Artifacts

Dropbox stores encrypted databases in multiple locations:
```
\Users\<username>\AppData\Local\Dropbox\
\Users\<username>\AppData\Local\Dropbox\Instance1\
\Users\<username>\AppData\Roaming\Dropbox\
```

### Main Databases

| Database | Purpose |
|----------|---------|
| Sigstore.dbx | Signature verification |
| Filecache.dbx | File metadata and journal |
| Deleted.dbx | Deleted file records |
| Config.dbx | User configuration |

### Understanding Dropbox Encryption

Dropbox uses **DPAPI** (Data Protection API) with these parameters:
- **Entropy:** `d114a55212655f74bd772e37e64aee9b`
- **Salt:** `0D638C092E8B82FC452883F95F355B8E`
- **Algorithm:** PBKDF2
- **Iterations:** 1066

### Decryption Requirements

To decrypt Dropbox databases, you need:

1. **Encrypted DPAPI key** from registry:
   - Path: `NTUSER.DAT\Software\Dropbox\ks\client`
   - Export as binary

2. **SYSTEM and SECURITY hives** from the Windows registry

3. **DPAPI master keys** from:
   - `\Users\<username>\AppData\Roaming\Microsoft\Protect`

4. **Windows user credentials** (username and password)

### Decryption Workflow

Use the helper script to orchestrate decryption:

```bash
python scripts/decrypt_dropbox_db.py \
  --dbx-file <path-to-config.dbx> \
  --dpapi-key <path-to-encrypted-key> \
  --system-hive <path-to-SYSTEM> \
  --security-hive <path-to-SECURITY> \
  --master-key <path-to-master-key> \
  --username <windows-username> \
  --password <windows-password>
```

Or use the manual process:

1. Use **DataProtectionDecryptor** (NirSoft) to decrypt the DPAPI key
2. The tool shows the **primary key** needed for decryption
3. Use CyberChef PBKDF2 recipe to derive the final key:
   - Passphrase: Primary key from step 2
   - Salt: `0D638C092E8B82FC452883F95F355B8E`
   - Iterations: 1066
   - Algorithm: SHA1
4. Decrypt the database:
   ```bash
   sqlite -k <Obtained Key> config.dbx ".backup config.db"
   ```

### Config.db Contents

After decryption, `config.db` contains:
- **Email:** User's Dropbox email
- **usernamedisplayname:** Display name
- **dropbox_path:** Local Dropbox folder location
- **Host_id:** Authentication hash (revocable only from web)
- **Root_ns:** User identifier

### Filecache.db Contents

The `File_journal` table contains:
- **Server_path:** File path on Dropbox server (prefixed with host_id)
- **local_sjid:** File version
- **local_mtime:** Modification date
- **local_ctime:** Creation date

Other useful tables:
- **block_cache:** Hashes of all files and folders
- **block_ref:** Links block_cache hashes to file_journal file IDs
- **mount_table:** Shared folder information
- **deleted_fields:** Deleted file records with date_added

---

## Common Investigation Patterns

### Pattern 1: Find All Cloud Storage Artifacts

Use the artifact locator script:
```bash
python scripts/list_cloud_artifacts.py <user-profile-path>
```

This scans for all known cloud storage artifact locations.

### Pattern 2: Cross-Reference File Hashes

When you have an MD5 hash from one service, search for it in others:
- Google Drive logs contain MD5 hashes
- Dropbox block_cache contains file hashes
- This can help identify the same file across services

### Pattern 3: Timeline Analysis

Combine timestamps from:
- OneDrive SyncDiagnostics.log
- Google Drive Sync_log.log
- Dropbox File_journal table

This creates a unified timeline of file synchronization activity.

### Pattern 4: Deleted File Recovery

Check these locations for deleted file records:
- Google Drive Sync_log.log (deleted files still appear)
- Dropbox Deleted.dbx and deleted_fields table
- OneDrive may have deleted file references in CID files

---

## Tips and Best Practices

1. **Always check multiple user profiles** - Cloud storage artifacts are per-user
2. **Preserve original files** - Work on copies, especially when decrypting
3. **Document the CID** - OneDrive CIDs are critical for finding related artifacts
4. **Check for multiple Dropbox instances** - Look in Instance1, Instance2, etc.
5. **Verify timestamps** - Cloud services may use different time formats
6. **Cross-reference with cloud-side data** - Local artifacts may be incomplete

---

## Helper Scripts

### Available Scripts

| Script | Purpose |
|--------|--------|
| `extract_onedrive_cid.py` | Extract CID from SyncDiagnostics.log |
| `query_gdrive_db.py` | Query Google Drive SQLite databases |
| `decrypt_dropbox_db.py` | Decrypt Dropbox .dbx files |
| `list_cloud_artifacts.py` | Find all cloud storage artifacts |

### Using the Scripts

All scripts are designed to be run from the command line. They accept file paths as arguments and output results to stdout or create output files as specified.

Example:
```bash
# Extract OneDrive CID
python scripts/extract_onedrive_cid.py \
  "C:\\Users\\john\\AppData\\Local\\Microsoft\\OneDrive\\logs\\Personal\\SyncDiagnostics.log"

# Query Google Drive database
python scripts/query_gdrive_db.py \
  "C:\\Users\\john\\AppData\\Local\\Google\\Drive\\user_default\\Cloud_graph\\Cloud_graph.db" \
  cloud_graph_entry

# List all cloud artifacts
python scripts/list_cloud_artifacts.py "C:\\Users\\john"
```

---

## References

- [Dropbox DPAPI Decryption Guide](https://blog.digital-forensics.it/2017/04/brush-up-on-dropbox-dbx-decryption.html)
- [Microsoft DPAPI Documentation](https://docs.microsoft.com/en-us/previous-versions/ms995355(v=msdn.10))
- [NirSoft DataProtectionDecryptor](https://nirsoft.net/utils/dpapi_data_decryptor.html)
- [CyberChef PBKDF2 Recipe](https://gchq.github.io/CyberChef/index.html#recipe=Derive_PBKDF2_key)
