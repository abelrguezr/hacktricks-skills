---
name: ios-backup-forensics
description: iOS backup forensics for messaging app analysis and 0-click exploit detection. Use this skill whenever investigating iOS devices for spyware, analyzing encrypted backups, extracting messaging attachments (iMessage/WhatsApp/Signal/Telegram/Viber), or scanning for structural file format exploits. Trigger on any iOS forensics task, backup analysis, or mobile device investigation involving Apple devices.
---

# iOS Backup Forensics

A skill for reconstructing and analyzing iOS backups to detect 0-click exploit delivery via messaging app attachments.

## Quick Start

```bash
# Reconstruct backup → Extract attachments → Scan for exploits
./scripts/reconstruct_backup.sh /path/to/backup
./scripts/scan_attachments.sh /path/to/reconstructed
```

## Workflow Overview

1. **Acquire & decrypt** the iOS backup (encrypted preferred for keychain data)
2. **Reconstruct** the hashed backup into readable paths using Manifest.db
3. **Enumerate** messaging app attachments via SQL queries
4. **Scan** attachments with structural detectors for exploit signatures

---

## Step 1: Acquire the Backup

### Encrypted Backup (Recommended)

Encrypted backups preserve keychain items and are required for full forensic value.

**macOS Finder:**
- Connect device → Finder → "Encrypt local backup" → Set password → Back Up Now

**Cross-platform (libimobiledevice ≥1.4.0):**
```bash
idevicepair pair
idevicebackup2 backup --full --encrypt --password '<pwd>' ~/backups/iphone-backup
```

### Decrypt Existing Backup

If you have an encrypted backup, decrypt it first:
```bash
mvt-ios decrypt-backup -p '<pwd>' -d /tmp/dec-backup /path/to/encrypted-backup
```

---

## Step 2: Reconstruct the Backup

iOS backups use hashed filenames. Reconstruct them to readable paths:

```bash
./scripts/reconstruct_backup.sh /path/to/backup /tmp/reconstructed
```

This reads `Manifest.db` and recreates the original folder hierarchy.

**Manual approach:**
```bash
elegant-bouncer --ios-extract /path/to/backup --output /tmp/reconstructed
```

---

## Step 3: Enumerate Messaging Attachments

### iMessage (sms.db)

```bash
sqlite3 /path/to/reconstructed/Library/SMS/sms.db < scripts/extract_imessage_attachments.sql
```

**What it does:**
- Joins `message`, `attachment`, and `message_attachment_join` tables
- Returns attachment paths, message dates, sender/receiver info
- Includes chat names via `chat_message_join`

### WhatsApp (ChatStorage.sqlite)

```bash
sqlite3 /path/to/reconstructed/AppDomainGroup-group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite < scripts/extract_whatsapp_attachments.sql
```

**What it does:**
- Queries `ZWAMEDIAITEM` for media paths
- Converts Apple epoch timestamps to readable dates
- Shows message direction (incoming/outgoing)

### Other Apps

- **Signal**: Message DB is encrypted, but scan `Library/Caches/` for cached attachments
- **Telegram**: Check `Library/Caches/` for residual media (iOS 18 has cache-clearing bugs)
- **Viber**: Query `Viber.sqlite` for message/attachment tables

---

## Step 4: Scan for Structural Exploits

Run structural detectors on extracted attachments:

```bash
./scripts/scan_attachments.sh /path/to/reconstructed
```

**Detections include:**
- **PDF/JBIG2 FORCEDENTRY** (CVE-2021-30860): Impossible dictionary states
- **WebP/VP8L BLASTPASS** (CVE-2023-4863): Oversized Huffman tables
- **TrueType TRIANGULATION** (CVE-2023-41990): Undocumented bytecode opcodes
- **DNG/TIFF CVE-2025-43300**: Metadata vs. stream mismatches

---

## IOC-Driven Triage (Optional)

Use MVT for automated IOC matching:

```bash
mvt-ios check-backup -i indicators.csv /path/to/dec-backup
```

Results land in `mvt-results/` (e.g., `analytics_detected.json`, `safari_history_detected.json`).

---

## General Artifact Parsing

For timeline/metadata beyond messaging:

```bash
python3 ileapp.py -b /path/to/dec-backup -o /tmp/ileapp-report
```

Supports iOS 11-17 schemas.

---

## Important Notes

### Time Conversions
- iMessage uses Apple epoch units on some versions
- WhatsApp uses `ZMESSAGEDATE` (Unix epoch + 978307200 offset)
- Convert appropriately during reporting

### Schema Drift
- App SQLite schemas change over time
- Verify table/column names per device build
- Check `PRAGMA table_info(table_name)` if queries fail

### False Positives
- Structural heuristics are conservative
- May flag rare malformed but benign media
- Always validate detections manually

### Recursive Extraction
- PDFs may embed JBIG2 streams and fonts
- Extract and scan inner objects for nested exploits

---

## References

- [ElegantBouncer](https://github.com/msuiche/elegant-bouncer) - iOS backup forensics tool
- [MVT iOS Backup Workflow](https://docs.mvt.re/en/latest/ios/backup/check/)
- [libimobiledevice 1.4.0](https://libimobiledevice.org/news/2025/10/10/libimobiledevice-1.4.0-release/)
