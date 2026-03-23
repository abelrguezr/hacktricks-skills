---
name: discord-cache-forensics
description: Forensic analysis of Discord Desktop cache to recover exfiltrated files, webhook endpoints, and activity timelines. Use this skill whenever investigating Discord-related incidents, analyzing compromised systems for Discord artifacts, recovering deleted message attachments, hunting for C2 webhooks, or building timelines from Discord activity. Trigger on any request involving Discord cache analysis, Chromium cache forensics, Discord artifact recovery, or Discord-based exfiltration investigation.
---

# Discord Cache Forensics

A skill for triaging Discord Desktop cache artifacts to recover exfiltrated files, webhook endpoints, and activity timelines. Discord Desktop is an Electron/Chromium app that uses Chromium Simple Cache on disk.

## When to Use This Skill

Use this skill when:
- Investigating Discord-related security incidents
- Analyzing compromised systems for Discord artifacts
- Recovering deleted message attachments and media
- Hunting for malicious webhooks or C2 infrastructure
- Building activity timelines from Discord usage
- Correlating Discord activity with other forensic artifacts
- Performing DFIR on systems where Discord was installed

## Cache Locations

### Platform-Specific Paths

| Platform | Cache Path |
|----------|------------|
| Windows | `%AppData%\discord\Cache\Cache_Data` |
| macOS | `~/Library/Application Support/discord/Cache/Cache_Data` |
| Linux | `~/.config/discord/Cache/Cache_Data` |

### Key On-Disk Structures

Inside `Cache_Data`:
- `index`: Simple Cache index database
- `data_#`: Binary cache block files (can contain multiple cached objects)
- `f_######`: Individual cached entries (often larger bodies)

**Important**: Deleting messages/channels/servers in Discord does NOT purge this local cache. Cached items often remain with file timestamps aligned to user activity.

## What Can Be Recovered

- **Exfiltrated attachments** and thumbnails from `cdn.discordapp.com` / `media.discordapp.net`
- **Media files**: Images (.jpg, .png, .gif, .webp), videos (.mp4, .webm)
- **Webhook URLs**: `https://discord.com/api/webhooks/...`
- **Discord API calls**: `https://discord.com/api/vX/...`
- **Timeline data**: File modification times reflect when objects hit cache

## Quick Triage Workflow

### Step 1: Acquire the Cache

```bash
# Copy the entire Cache directory for offline analysis
# Windows
xcopy "%AppData%\discord\Cache" "C:\IR\discord-cache" /E /I /H

# macOS/Linux
cp -r ~/Library/Application\ Support/discord/Cache /tmp/discord-cache
```

### Step 2: Scan for High-Signal Artifacts

Use the `scan_discord_cache.sh` script for automated scanning:

```bash
./scan_discord_cache.sh --cache /path/to/Cache_Data --output /path/to/results
```

Or manually grep for artifacts:

**Webhook endpoints:**
```bash
# Linux/macOS
strings -a Cache_Data/* | grep -i "https://discord.com/api/webhooks/"

# Windows
findstr /S /I /C:"https://discord.com/api/webhooks/" "%AppData%\discord\Cache\Cache_Data\*"
```

**Attachment/CDN URLs:**
```bash
strings -a Cache_Data/* | grep -Ei "https://(cdn|media)\.discord(app)?\.com/attachments/"
```

**Discord API calls:**
```bash
strings -a Cache_Data/* | grep -Ei "https://discord(app)?\.com/api/v[0-9]+/"
```

### Step 3: Build Timeline

Generate a timeline from cache file modification times:

```bash
./generate_timeline.py --cache /path/to/Cache_Data --output timeline.csv
```

Or manually (Windows PowerShell):
```powershell
Get-ChildItem "$env:AppData\discord\Cache\Cache_Data" -File -Recurse | 
  Sort-Object LastWriteTime | 
  Select-Object LastWriteTime, FullName, Length
```

### Step 4: Parse f_* Entries

Files starting with `f_` contain HTTP response headers followed by the body. The header block ends with `\r\n\r\n`.

Use the `parse_cache_entries.py` script:

```bash
./parse_cache_entries.py --cache /path/to/Cache_Data --output /path/to/extracted
```

Key headers to examine:
- `Content-Type`: Infer media type
- `Content-Location` or `X-Original-URL`: Original remote URL
- `Content-Encoding`: May be gzip/deflate/br (Brotli)

### Step 5: Extract Media

Carve media files from cache:

```bash
./extract_media.py --cache /path/to/Cache_Data --output /path/to/media
```

This script:
- Scans for magic bytes (JPEG, PNG, GIF, WebP, MP4, WebM)
- Extracts complete files from cache blocks
- Generates SHA-256 hashes for each file
- Outputs a manifest with file metadata

## Automated Analysis: Discord Forensic Suite

For comprehensive analysis, use the Discord Forensic Suite:

```bash
python3 discord_forensic_suite_cli \
  --cache /path/to/Cache_Data \
  --outdir /path/to/output \
  --output discord_cache_report \
  --format both \
  --timeline \
  --extra \
  --carve \
  --verbose
```

**Key options:**
- `--cache`: Path to Cache_Data
- `--format`: html|csv|both
- `--timeline`: Emit ordered CSV timeline
- `--extra`: Scan sibling Code Cache and GPUCache
- `--carve`: Carve media from raw bytes
- `--verbose`: Detailed output

**Outputs:**
- HTML report with findings
- CSV report with all artifacts
- CSV timeline (ordered by mtime)
- Media folder with carved/extracted files

## Analyst Tips

1. **Correlate mtimes**: Match cache file modification times with user/attacker activity windows to reconstruct timelines
2. **Hash recovered media**: Generate SHA-256 hashes and compare against known-bad or exfiltration datasets
3. **Test webhooks**: Extracted webhook URLs can be tested for liveness; consider adding to blocklists
4. **Cache persistence**: Cache persists after server-side "wiping". Collect entire Cache directory plus sibling caches (Code Cache, GPUCache)
5. **Magic-byte sniffing**: When Content-Type is absent, use magic bytes to identify media types
6. **Decompression**: Check Content-Encoding header; decompress gzip/deflate/br as needed

## Output Formats

### Timeline CSV
```csv
timestamp,file_path,file_size,sha256,artifact_type
2024-01-15T10:23:45,f_123456,1024,abc123...,webhook_url
2024-01-15T10:24:12,f_123457,524288,def456...,image_attachment
```

### Artifact Report
```json
{
  "webhooks": [
    {
      "url": "https://discord.com/api/webhooks/...",
      "found_in": "f_123456",
      "timestamp": "2024-01-15T10:23:45"
    }
  ],
  "attachments": [
    {
      "url": "https://cdn.discordapp.com/attachments/...",
      "file_path": "extracted/abc123.jpg",
      "sha256": "abc123...",
      "content_type": "image/jpeg"
    }
  ],
  "api_calls": [...]
}
```

## References

- [Discord as a C2 and the cached evidence left behind](https://www.pentestpartners.com/security-blog/discord-as-a-c2-and-the-cached-evidence-left-behind/)
- [Discord Forensic Suite (CLI/GUI)](https://github.com/jwdfir/discord_cache_parser)
- [Discord Webhooks – Execute Webhook](https://discord.com/developers/docs/resources/webhook#execute-webhook)
