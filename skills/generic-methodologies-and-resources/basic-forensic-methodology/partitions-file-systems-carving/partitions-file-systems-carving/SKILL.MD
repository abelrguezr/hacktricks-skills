---
name: forensic-partition-analysis
description: Use this skill whenever analyzing disk images, recovering deleted files, examining partition tables (MBR/GPT), performing file carving, or conducting digital forensics on storage media. Trigger this skill for any task involving disk forensics, file system analysis, data recovery, or metadata extraction from digital evidence.
---

# Forensic Partition Analysis

A comprehensive skill for digital forensics involving disk partitions, file systems, and data recovery.

## When to Use This Skill

Use this skill when you need to:
- Analyze disk images or raw storage media
- Examine partition tables (MBR or GPT)
- Recover deleted files from file systems
- Perform file carving on raw data
- Extract metadata from files
- Understand file system structures (FAT, NTFS, EXT)
- Investigate storage media for forensic purposes

## Core Concepts

### Partition Structures

#### MBR (Master Boot Record)
- Located in the **first sector** (512 bytes) of the disk
- Contains boot code (446 bytes) + partition table (64 bytes) + signature (2 bytes: 0x55AA)
- Supports up to **4 primary partitions** (only 1 can be active/bootable)
- Maximum disk size: **2.2TB**
- Windows Disk Signature found at bytes 440-443

**MBR Format:**
```
Offset 0x00-0x1BD (446 bytes): Boot code
Offset 0x1BE-0x1CD (16 bytes): First partition entry
Offset 0x1CE-0x1DD (16 bytes): Second partition entry
Offset 0x1DE-0x1ED (16 bytes): Third partition entry
Offset 0x1EE-0x1FD (16 bytes): Fourth partition entry
Offset 0x1FE-0x1FF (2 bytes): Signature 0x55AA
```

**Partition Entry Format (16 bytes each):**
```
Byte 0: Active flag (0x80 = bootable)
Byte 1-3: CHS start (cylinder/head/sector)
Byte 4: Partition type (0x83 = Linux, 0x07 = NTFS, 0x0B = FAT32)
Byte 5-7: CHS end
Byte 8-11: Starting sector (LBA, little endian)
Byte 12-15: Sector count (little endian)
```

#### GPT (GUID Partition Table)
- Modern standard, supports disks up to **9.4ZB**
- Up to **128 partitions** on Windows
- Uses 64-bit addressing
- Contains redundant copies for data integrity
- Signature: "EFI PART" at LBA 1
- Protective MBR at LBA 0 for backward compatibility

**GPT Header (LBA 1):**
```
Offset 0x00 (8 bytes): Signature "EFI PART"
Offset 0x08 (4 bytes): Revision (1.0 = 0x00000100)
Offset 0x0C (4 bytes): Header size (usually 92 bytes)
Offset 0x10 (4 bytes): CRC32 of header
Offset 0x18 (8 bytes): Current LBA
Offset 0x20 (8 bytes): Backup LBA
Offset 0x28 (8 bytes): First usable LBA
Offset 0x30 (8 bytes): Last usable LBA
Offset 0x38 (16 bytes): Disk GUID
Offset 0x48 (8 bytes): Partition entries start LBA (usually 2)
Offset 0x50 (4 bytes): Number of partition entries
Offset 0x54 (4 bytes): Size of each entry (usually 128)
Offset 0x58 (4 bytes): CRC32 of partition entries
```

### File Systems

#### FAT (File Allocation Table)
- **FAT12**: Up to 4,078 clusters, 12-bit addresses
- **FAT16**: Up to 65,517 clusters, 16-bit addresses
- **FAT32**: Up to 268,435,456 clusters, 32-bit addresses
- **Maximum file size**: 4GB (32-bit field limitation)
- Maintains **two copies** of the FAT for redundancy
- Basic unit: **cluster** (multiple sectors, typically 512B+)

**FAT Directory Entry (32 bytes):**
```
Bytes 0-10: Filename (8.3 format)
Byte 11: Attributes
Bytes 12-13: Creation time
Bytes 14-15: Creation date
Bytes 16-17: Last access date
Bytes 18-19: First cluster (high word)
Bytes 20-21: Modification time
Bytes 22-23: Modification date
Bytes 24-27: First cluster (low word)
Bytes 28-31: File size
```

#### NTFS (New Technology File System)
- Used by Windows XP and later
- Journaling file system
- Uses Master File Table (MFT) to track all files
- Supports file streams, permissions, encryption
- Deleted files remain in MFT until overwritten

#### EXT (Extended File System)
- **EXT2**: Non-journaling, used for boot partitions
- **EXT3/4**: Journaling, used for data partitions
- Common on Linux systems

## Forensic Analysis Workflow

### Step 1: Initial Assessment

1. **Identify the disk image format** (raw .dd, .img, .E01, etc.)
2. **Determine partition table type** (MBR or GPT)
3. **Calculate partition offsets** for mounting
4. **Document the chain of custody**

### Step 2: Partition Analysis

**For MBR disks:**
```bash
# Examine the first sector
xxd -l 512 disk_image.dd

# Check for MBR signature (0x55AA at offset 0x1FE)
# Look for partition entries at offsets 0x1BE, 0x1CE, 0x1DE, 0x1EE

# Use fdisk to list partitions
fdisk -l disk_image.dd

# Mount a partition (calculate offset: start_sector * 512)
mount -o ro,loop,offset=$((start_sector * 512)) disk_image.dd /mnt/forensics
```

**For GPT disks:**
```bash
# Check LBA 1 for "EFI PART" signature
xxd -s 512 -l 512 disk_image.dd

# Use parted or fdisk to examine GPT
parted disk_image.dd print

# Mount using the partition offset from GPT header
```

### Step 3: File System Analysis

**For FAT file systems:**
```bash
# Use fatx or similar tools
fatx -l disk_image.dd

# Examine the FAT table and directory entries
```

**For NTFS file systems:**
```bash
# Use ntfs-3g or specialized forensic tools
ntfs-3g -o ro disk_image.dd /mnt/forensics

# Examine MFT for deleted files
mftparser disk_image.dd
```

**For EXT file systems:**
```bash
# Use extundelete or debugfs
debugfs disk_image.dd
```

### Step 4: Deleted File Recovery

**Logged Deleted Files:**
- Check MFT (NTFS) for deleted entries
- Examine $MFT and $LOGFILE
- Look in Volume Shadow Copies
- Review file system journals

**File Carving:**
- Search for file headers/footers in raw data
- Use tools like `foremost`, `scalpel`, `photorec`
- Note: **Cannot recover fragmented files**

**Data Stream Carving:**
- Search for specific patterns (URLs, emails, etc.)
- Useful when complete files aren't recoverable

### Step 5: Metadata Extraction

Use tools like `exiftool` or `Metadiver` to extract:
- Creation/modification dates
- Author information
- GPS coordinates (images)
- Software versions
- Camera models

## Common Partition Type Codes

**MBR Partition Types:**
- 0x01: FAT12
- 0x04: FAT16 (<32MB)
- 0x06: FAT16 (>32MB)
- 0x07: NTFS
- 0x0B: FAT32 (Chs)
- 0x0C: FAT32 (LBA)
- 0x83: Linux
- 0x8E: Linux LVM

**GPT Partition Types:**
- EFI System: C12A7328-F81F-11D2-BA4B-00A0C93EC93B
- Microsoft Basic Data: E3C9E316-0B5C-4DB8-817D-F92DF00215AE
- Linux Root: 0FC63DAF-8483-4772-8E79-3D69D8477DE4
- Linux Swap: 0657FD6D-A4AB-43C4-84E5-0933C84B4F4F

## Tools Reference

| Tool | Purpose |
|------|--------|
| `fdisk` | Partition table examination |
| `parted` | GPT/MBR partition management |
| `xxd` | Hex dump of disk sectors |
| `exiftool` | Metadata extraction |
| `foremost` | File carving |
| `scalpel` | File carving |
| `photorec` | File recovery |
| `debugfs` | EXT file system analysis |
| `mftparser` | NTFS MFT analysis |
| `Active Disk Editor` | Windows partition analysis |
| `ArsenalImageMounter` | Mount disk images on macOS |

## Best Practices

1. **Always work on copies** - Never analyze the original evidence
2. **Use read-only mounts** - `mount -o ro` to prevent modifications
3. **Document everything** - Record all commands and findings
4. **Verify integrity** - Use hash values (MD5, SHA256) to verify evidence
5. **Understand limitations** - File carving cannot recover fragmented files
6. **Consider secure deletion** - Overwritten data may still be partially recoverable

## Example Analysis Commands

```bash
# Calculate partition offset for mounting
# If fdisk shows start sector 2048:
OFFSET=$((2048 * 512))  # = 1048576 bytes

# Mount the partition
mount -o ro,loop,offset=$OFFSET disk_image.dd /mnt/forensics

# Extract metadata from all files
find /mnt/forensics -type f -exec exiftool {} \;

# Carve JPEG files from raw image
foremost -t jpg -i disk_image.dd -o ./carved_output

# Search for specific strings in raw data
strings disk_image.dd | grep -i "password"
```

## Troubleshooting

**Cannot mount partition:**
- Verify the offset calculation (sector * 512)
- Check if the partition type is supported
- Try mounting without loop option

**File carving not finding files:**
- Files may be fragmented
- Headers may be corrupted
- Try different file type signatures

**GPT not detected:**
- Check LBA 1 for "EFI PART" signature
- Verify protective MBR at LBA 0
- Some tools may not support GPT

## References

- [GPT Wikipedia](https://en.wikipedia.org/wiki/GUID_Partition_Table)
- [NTFS Permissions](http://ntfs.com/ntfs-permissions.htm)
- [OSForensics MFT Guide](https://www.osforensics.com/)
- [ExifTool Documentation](https://exiftool.org/)
- [Active Disk Editor](https://www.disk-editor.org/)
