---
name: macos-enumeration
description: macOS system enumeration, information gathering, and troubleshooting. Use this skill whenever the user needs to gather system information on macOS, enumerate users and processes, check network configuration, list installed applications, troubleshoot system issues, or perform administrative tasks on macOS. Trigger for any request involving macOS commands, system_profiler, launchctl, networksetup, brew, or general macOS system exploration.
---

# macOS Enumeration & System Information

A comprehensive guide to macOS system commands for enumeration, troubleshooting, and administration.

## Quick Start

For rapid system overview, run these core commands:

```bash
# Basic system info
uname -a
system_profiler SPSoftwareDataType
launchctl list

# Network status
networksetup -listallnetworkservices
lsof -i -P -n | grep LISTEN

# Installed applications
system_profiler SPApplicationsDataType
```

## System Information

### Core System Details

```bash
# Time and uptime
date
cal
uptime

# User information
w                    # List logged-in users
whoami               # Current user
finger username      # User details

# Hardware info
uname -a             # System info
cat /proc/cpuinfo    # Processor (if available)
cat /proc/meminfo    # Memory (if available)
free                 # Memory usage
df                   # Disk space
```

### System Profiler (Comprehensive)

The `system_profiler` command is the most powerful tool for macOS enumeration:

```bash
# Get all available data types
system_profiler -listDataTypes

# Common data types
system_profiler SPSoftwareDataType        # OS version, build
system_profiler SPHardwareDataType        # Hardware overview
system_profiler SPApplicationsDataType    # Installed applications
system_profiler SPFrameworksDataType      # Installed frameworks
system_profiler SPDeveloperToolsDataType  # Xcode, command line tools
system_profiler SPStartupItemDataType     # Startup items
system_profiler SPNetworkDataType         # Network configuration
system_profiler SPFirewallDataType        # Firewall status
system_profiler SPBluetoothDataType       # Bluetooth devices
system_profiler SPEthernetDataType        # Ethernet info
system_profiler SPUSBDataType             # USB devices
system_profiler SPAirPortDataType         # Wi-Fi adapter info
system_profiler SPPrintersDataType        # Connected printers
system_profiler SPDisplaysDataType        # Display information
```

**Tip:** You can combine multiple data types:
```bash
system_profiler SPSoftwareDataType SPNetworkDataType SPHardwareDataType
```

## User & Process Management

### Launch Services (macOS equivalent to systemd)

```bash
# List all running services
launchctl list

# Print services for a specific user (replace UID)
launchctl print gui/<UID>

# Print system-level services
launchctl print system

# Print specific launch agent details
launchctl print gui/<UID>/com.company.launchagent.label

# List scheduled "at" tasks
atq
```

### Find User UID

```bash
# Get current user's UID
id -u

# Get specific user's UID
id -u username
```

## Network Analysis

### Network Configuration

```bash
# List all network services
networksetup -listallnetworkservices

# List hardware ports
networksetup -listallhardwareports

# Get Wi-Fi information
networksetup -getinfo Wi-Fi

# Proxy settings
networksetup -getautoproxyurl Wi-Fi
networksetup -getwebproxy Wi-Fi
networksetup -getftpproxy Wi-Fi
```

### Active Connections & Listening Ports

```bash
# List all listening ports (most useful)
lsof -i -P -n | grep LISTEN

# ARP table
arp -i en0 -l -a

# Network monitoring (top-style)
nettop

# SMB shares
smbutil statshares -a
```

## Application & Package Management

### Homebrew

```bash
# List installed packages
brew list

# Search for packages
brew search <text>

# Get package info
brew info <formula>

# Install/uninstall
brew install <formula>
brew uninstall <formula>

# Cleanup
brew cleanup                    # Remove old versions of all formulae
brew cleanup <formula>          # Remove old versions of specific formula
```

### Application Discovery

```bash
# List installed applications
system_profiler SPApplicationsDataType
lsappinfo list

# Open applications
open -a <Application Name>              # Open app
open -a <Application Name> --hide       # Open app hidden
open some.doc -a TextEdit               # Open file with specific app
```

## File & Data Search

### Spotlight Search (mdfind)

```bash
# Search files by content
mdfind password

# Search files by name
mdfind -name password

# Common search patterns
mdfind "kext"
mdfind "config"
mdfind "password"
mdfind "credential"
```

## Administrative Tasks

### Service Management

```bash
# Enable SSH
sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist

# Disable SSH
sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist

# Apache control
sudo apachectl start
sudo apachectl stop
sudo apachectl restart
sudo apachectl status

# Web folder location
# /Library/WebServer/Documents/
```

### System Maintenance

```bash
# Purge RAM (requires sudo)
sudo purge

# Flush DNS cache
dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Prevent sleep
caffeinate &

# Screenshot (requires permission)
screencapture -x /tmp/ss.jpg

# Clipboard
pbpaste              # Get clipboard contents
```

## Security & Anti-Analysis Detection

### VM/Sandbox Detection

Some macOS malware checks for virtualization to avoid analysis:

```bash
# Check for VM indicators
system_profiler SPHardwareDataType SPDisplaysDataType | grep -Eiq 'qemu|kvm|vmware|virtualbox'

# Common anti-analysis pattern
if system_profiler SPHardwareDataType SPDisplaysDataType | grep -Eiq 'qemu|kvm|vmware|virtualbox'; then
  exit 100
fi
```

### Suspicious Activity Indicators

```bash
# Check for suspicious applications
system_profiler SPApplicationsDataType

# Check for suspicious frameworks
system_profiler SPFrameworksDataType

# Check running services
launchctl list

# Check for suspicious launch agents
launchctl print gui/<UID>
```

## Quick Reference by Use Case

### "I need to understand this macOS system"
```bash
system_profiler SPSoftwareDataType SPHardwareDataType SPNetworkDataType
```

### "What's running on this system?"
```bash
launchctl list
lsof -i -P -n | grep LISTEN
```

### "What applications are installed?"
```bash
system_profiler SPApplicationsDataType
brew list
```

### "How is the network configured?"
```bash
networksetup -listallnetworkservices
networksetup -getinfo Wi-Fi
arp -i en0 -l -a
```

### "Who is on this system?"
```bash
w
whoami
id
```

## Notes

- `system_profiler` without arguments can consume significant memory and time
- Many commands require `sudo` for full information
- Network interface names vary (en0, en1, Wi-Fi, etc.)
- Some commands may not be available on all macOS versions
- For automated enumeration, consider using tools like MacPEAS or SwiftBelt

## External Tools

- **MacPEAS**: https://github.com/carlospolop/PEASS-ng/tree/master/macOS/PEAS
- **SwiftBelt**: https://github.com/cedowens/SwiftBelt
- **Metasploit OSX Enumeration**: https://github.com/rapid7/metasploit-framework/blob/master/modules/post/osx/gather/enum_osx.rb
