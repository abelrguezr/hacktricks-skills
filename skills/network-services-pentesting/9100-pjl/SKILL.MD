---
name: pjl-printer-pentest
description: Pentest network printers via PJL (Printer Job Language) on port 9100/tcp. Use this skill whenever the user mentions printer security, port 9100, JetDirect, AppSocket, PJL commands, printer enumeration, printer exploitation, PRET tool, or any printer-related security testing. This includes tasks like enumerating printer info, accessing printer filesystems, uploading/downloading files, or exploiting printer vulnerabilities like TrueType VM bugs.
---

# PJL Printer Pentesting (Port 9100/tcp)

A skill for security testing network printers via the Printer Job Language (PJL) protocol on port 9100/tcp.

## Overview

Port 9100/tcp (JetDirect/AppSocket) is the default raw printing protocol used by CUPS and Windows printing architecture. Unlike LPD, IPP, or SMB, it provides a **bidirectional channel** that gives direct access to results of PJL, PostScript, or PCL commands. This makes it ideal for security analysis and exploitation.

**Key characteristics:**
- Default port: 9100/tcp
- Bidirectional communication (sends direct feedback including status and error messages)
- Supported by almost any network printer
- Used as the channel for security analysis with PRET and PFT

## Quick Start

### Basic Connection

```bash
nc -vn <IP> 9100
```

### Automated Enumeration

Use the bundled script for quick enumeration:

```bash
./scripts/pjl-enumerate.sh <IP>
```

## Enumeration

### Manual PJL Commands

Connect to port 9100 and send these commands:

| Command | Purpose |
|---------|---------|
| `@PJL INFO STATUS` | Printer status (sleep, online, etc.) |
| `@PJL INFO ID` | Brand and version information |
| `@PJL INFO PRODINFO` | Product information |
| `@PJL INFO VARIABLES` | Environment variables |
| `@PJL INFO FILESYS` | Filesystem information |
| `@PJL INFO TIMEOUT` | Timeout variables |
| `@PJL RDYMSG` | Ready message |
| `@PJL FSDIRLIST NAME="0:\" ENTRY=1 COUNT=65535` | List directory contents |
| `@PJL FSINIT` | Initialize filesystem |
| `@PJL FSUPLOAD` | Upload a file |
| `@PJL FSDOWNLOAD` | Download a file |
| `@PJL FSDELETE` | Delete a file |

### Automated Tools

**Nmap:**
```bash
nmap -sV --script pjl-ready-message -p 9100 <IP>
```

**Metasploit modules:**
```
use auxiliary/scanner/printer/printer_env_vars
use auxiliary/scanner/printer/printer_list_dir
use auxiliary/scanner/printer/printer_list_volumes
use auxiliary/scanner/printer/printer_ready_message
use auxiliary/scanner/printer/printer_version_info
use auxiliary/scanner/printer/printer_download_file
use auxiliary/scanner/printer/printer_upload_file
use auxiliary/scanner/printer/printer_delete_file
```

## File Operations

Use the bundled script for filesystem operations:

```bash
./scripts/pjl-file-ops.sh <IP> <operation> [args]
```

Operations:
- `list` - List directory contents
- `upload <local_file> <remote_path>` - Upload a file
- `download <remote_path> <local_file>` - Download a file
- `delete <remote_path>` - Delete a file

## Exploitation

### PRET Tool

The primary tool for printer exploitation is [PRET](https://github.com/RUB-NDS/PRET). Install and use it for advanced attacks.

### XPS/TrueType VM Exploitation (Canon ImageCLASS)

For Canon printers vulnerable to TrueType VM bugs:

1. **Create XPS payload** with malicious font:
   - XPS is a ZIP containing `Documents/1/Pages/1.fpage` and `/Resources/evil.ttf`
   - The fpage references the malicious font

2. **Minimal XPS page example:**
```xml
<Glyphs Fill="#ff000000" FontUri="/Resources/evil.ttf" FontRenderingEmSize="12" OriginX="10" OriginY="10"/>
```

3. **RCE primitive (TrueType hinting VM):**
   - Hinting bytecode in TTF is executed by a TrueType VM
   - Canon's VM lacked stack bounds checks
   - `CINDEX`: OOB stack read → info leak
   - `DELTAP1`: unchecked relative stack pivot → controlled writes
   - Combine `WS`/`RS` (VM storage write/read) to stage values and perform precise 32-bit writes

4. **Exploit outline:**
   - Create XPS with malicious page and include `/Resources/evil.ttf`
   - In `fpgm`/`prep`, use `CINDEX` to leak and compute `stack_cur`
   - Stage target value with `WS`; pivot with `DELTAP1` to destination
   - Use `RS` to write to function pointer for PC control

5. **Deliver via PJL:**

Use the bundled script:
```bash
./scripts/pjl-xps-deliver.sh <IP> <xps_file>
```

Or manually:
```bash
{ printf "@PJL ENTER LANGUAGE = XPS\r\n"; cat exploit.xps; } | nc -q0 <PRINTER_IP> 9100
```

## Target Discovery

### Shodan Queries

```bash
pjl port:9100
```

## Workflow Recommendations

1. **Start with enumeration** - Use `pjl-enumerate.sh` to gather printer info
2. **Check filesystem access** - Try `pjl-file-ops.sh list` to see if you can access files
3. **Identify printer model** - Use `@PJL INFO ID` to determine brand/version
4. **Research vulnerabilities** - Check if the model has known exploits (especially Canon for TrueType VM bugs)
5. **Use PRET** - For advanced exploitation, use the PRET tool
6. **Document findings** - Save all enumeration output for reporting

## Safety Notes

- **Authorization required** - Only test printers you own or have explicit permission to test
- **Printer disruption** - Some commands may affect printer operation
- **Data loss** - File operations can delete or overwrite printer data
- **Legal compliance** - Ensure all testing complies with applicable laws and policies

## References

- [Hacking Printers Wiki](http://hacking-printers.net/wiki/index.php/Main_Page)
- [Port 9100 Printing](http://hacking-printers.net/wiki/index.php/Port_9100_printing)
- [PRET Tool](https://github.com/RUB-NDS/PRET)
- [Hacking printers using fonts (Canon ImageCLASS TrueType VM bugs)](https://haxx.in/posts/2025-09-23-canon-ttf/)
- [Apple TrueType Reference Manual](https://developer.apple.com/fonts/TrueType-Reference-Manual/RM05/Chap5.html)
