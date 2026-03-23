---
name: macos-persistence
description: macOS persistence and auto-start location guide. Use this skill whenever the user asks about macOS persistence mechanisms, auto-start locations, launch agents, launch daemons, shell startup files, or any technique for maintaining access on macOS systems. This includes security testing, penetration testing, red teaming, or understanding how malware maintains persistence on macOS. Trigger for questions about launchd, cron, shell rc files, login items, terminal preferences, or any macOS startup/persistence technique.
---

# macOS Persistence & Auto-Start Locations

This skill provides comprehensive guidance on macOS persistence mechanisms and auto-start locations for security testing and analysis.

> **⚠️ IMPORTANT**: Only use these techniques on systems you own or have explicit authorization to test. Unauthorized access is illegal.

## Quick Reference

| Category | Location | Trigger | Root Required |
|----------|----------|---------|---------------|
| LaunchAgents | `~/Library/LaunchAgents/` | User login | No |
| LaunchDaemons | `/Library/LaunchDaemons/` | System boot | Yes |
| Shell Startup | `~/.zshrc`, `~/.bashrc` | Terminal open | No |
| Login Items | `~/Library/Application Support/com.apple.backgroundtaskmanagementagent` | User login | No |
| Cron | `/usr/lib/cron/tabs/` | Scheduled | Yes (or crontab access) |

## 1. Launchd Persistence

### User LaunchAgents

**Location**: `~/Library/LaunchAgents/`

**Trigger**: User login

**Permissions**: User-owned (no root required)

**Example plist**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.example.persistence</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>touch /tmp/persistence_test</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
</dict>
</plist>
```

**Commands**:
```bash
# List all launch agents
cat ~/Library/LaunchAgents/*.plist

# Load a plist
launchctl load ~/Library/LaunchAgents/com.example.plist

# Unload a plist
launchctl unload ~/Library/LaunchAgents/com.example.plist

# List running agents
cat ~/Library/LaunchAgents/*.plist | grep -A5 "Label"
```

### System LaunchDaemons

**Location**: `/Library/LaunchDaemons/`

**Trigger**: System boot

**Permissions**: Root required

**Commands**:
```bash
# List all launch daemons
sudo ls -la /Library/LaunchDaemons/

# Load a daemon
sudo launchctl load /Library/LaunchDaemons/com.example.plist

# Check loaded daemons
sudo launchctl list | grep -i daemon
```

### PreLoginAgents

**Location**: `/Library/LaunchAgents/` (with PreLoginAgent key)

**Trigger**: Before user login (for assistive technology)

**Note**: Requires specific configuration in the plist

## 2. Shell Startup Files

### Zsh (Default on macOS)

**Locations**:
- `~/.zshrc` - Interactive shell
- `~/.zprofile` - Login shell
- `~/.zshenv` - All zsh instances
- `~/.zlogin` - Login shell (after .zprofile)
- `/etc/zshrc` - System-wide (root required)

**Trigger**: Terminal opens with zsh

**Example**:
```bash
# Add to .zshrc
echo 'touch /tmp/zshrc_test' >> ~/.zshrc

# Verify
cat ~/.zshrc | tail -5
```

### Bash

**Locations**:
- `~/.bashrc` - Interactive shell
- `~/.bash_profile` - Login shell
- `~/.profile` - Fallback login shell
- `/etc/bashrc` - System-wide (root required)

**Trigger**: Terminal opens with bash

## 3. Login Items

**Location**: `~/Library/Application Support/com.apple.backgroundtaskmanagementagent`

**Trigger**: User login

**Commands**:
```bash
# List login items
osascript -e 'tell application "System Events" to get the name of every login item'

# Add login item
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/path/to/app.app", hidden:false}'

# Remove login item
osascript -e 'tell application "System Events" to delete login item "itemname"'
```

## 4. Terminal Preferences

**Location**: `~/Library/Preferences/com.apple.Terminal.plist`

**Trigger**: Terminal app opens

**Commands**:
```bash
# Set startup command
/usr/libexec/PlistBuddy -c "Set :\"Window Settings\":\"Basic\":\"CommandString\" 'touch /tmp/terminal_test'" $HOME/Library/Preferences/com.apple.Terminal.plist

# Remove startup command
/usr/libexec/PlistBuddy -c "Set :\"Window Settings\":\"Basic\":\"CommandString\" ''" $HOME/Library/Preferences/com.apple.Terminal.plist
```

## 5. iTerm2 Persistence

**Location**: `~/Library/Application Support/iTerm2/Scripts/AutoLaunch/`

**Trigger**: iTerm2 opens

**Example**:
```bash
# Create auto-launch script
mkdir -p "$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch"
cat > "$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch/persistence.sh" << 'EOF'
#!/bin/bash
touch /tmp/iterm2_persistence
EOF
chmod +x "$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch/persistence.sh"

# Or use preferences
/usr/libexec/PlistBuddy -c "Set :\"New Bookmarks\":0:\"Initial Text\" 'touch /tmp/iterm_prefs'" $HOME/Library/Preferences/com.googlecode.iterm2.plist
```

## 6. Cron Jobs

**Locations**:
- `/usr/lib/cron/tabs/` - User cron jobs (root to view)
- `/etc/periodic/` - Periodic scripts
- `~/.crontab` - User crontab

**Trigger**: Scheduled time

**Commands**:
```bash
# List user cron jobs
crontab -l

# Add cron job
echo '* * * * * /bin/bash -c "touch /tmp/cron_test"' | crontab -

# List periodic scripts
ls -la /etc/periodic/daily/

# Run periodic scripts manually
sudo periodic daily
```

## 7. SSH RC Files

**Locations**:
- `~/.ssh/rc` - User SSH RC
- `/etc/ssh/sshrc` - System SSH RC (root required)

**Trigger**: SSH login

**Example**:
```bash
# Create SSH RC
cat > ~/.ssh/rc << 'EOF'
#!/bin/bash
touch /tmp/ssh_rc_test
EOF
chmod +x ~/.ssh/rc
```

## 8. Folder Actions

**Location**: `~/Library/Scripts/Folder Action Scripts/`

**Trigger**: Folder accessed in Finder

**Example**:
```bash
# Create folder action script
cat > /tmp/folder_action.js << 'EOF'
var app = Application.currentApplication();
app.includeStandardAdditions = true;
app.doShellScript("touch /tmp/folder_action_test");
EOF

# Compile script
osacompile -l JavaScript -o /tmp/folder_action.scpt /tmp/folder_action.js

# Move to folder actions directory
mkdir -p "$HOME/Library/Scripts/Folder Action Scripts"
mv /tmp/folder_action.scpt "$HOME/Library/Scripts/Folder Action Scripts/"
```

## 9. QuickLook Plugins

**Locations**:
- `~/Library/QuickLook/`
- `/Library/QuickLook/` (root required)
- `/System/Library/QuickLook/` (root required)

**Trigger**: File preview (space bar in Finder)

**Note**: Requires compiled plugin bundle

## 10. Audio Plugins

**Locations**:
- `~/Library/Audio/Plug-ins/Components/`
- `/Library/Audio/Plug-ins/Components/` (root required)
- `/Library/Audio/Plug-Ins/HAL/` (root required)

**Trigger**: Audio service restart

## 11. Screen Savers

**Locations**:
- `~/Library/Screen Savers/`
- `/Library/Screen Savers/` (root required)
- `/System/Library/Screen Savers/` (root required)

**Trigger**: Screen saver activated

## 12. Spotlight Importers

**Locations**:
- `~/Library/Spotlight/`
- `/Library/Spotlight/` (root required)
- `/System/Library/Spotlight/` (root required)

**Trigger**: File with supported extension created

**Commands**:
```bash
# List loaded importers
mdimport -L

# Check specific importer
plutil -p /Library/Spotlight/iBooksAuthor.mdimporter/Contents/Info.plist
```

## 13. Authorization Plugins

**Location**: `/Library/Security/SecurityAgentPlugins/`

**Trigger**: User authentication

**Permissions**: Root required + authorization database configuration

**Note**: Complex setup, can lock out users if misconfigured

## 14. PAM Modules

**Location**: `/etc/pam.d/`

**Trigger**: Authentication events

**Permissions**: Root required

**Example** (for testing only):
```bash
# Check PAM configuration
sudo cat /etc/pam.d/sudo
```

## 15. Periodic Scripts

**Locations**:
- `/etc/periodic/daily/`
- `/etc/periodic/weekly/`
- `/etc/periodic/monthly/`
- `/etc/daily.local`
- `/etc/weekly.local`
- `/etc/monthly.local`

**Trigger**: Scheduled (daily/weekly/monthly)

**Permissions**: Root required

## Detection & Enumeration

### Comprehensive Check Script

```bash
#!/bin/bash
# macOS Persistence Enumeration

echo "=== Launch Agents ==="
ls -la ~/Library/LaunchAgents/ 2>/dev/null

echo "\n=== Launch Daemons ==="
sudo ls -la /Library/LaunchDaemons/ 2>/dev/null

echo "\n=== Shell Startup Files ==="
ls -la ~/.zshrc ~/.bashrc ~/.profile ~/.zprofile 2>/dev/null

echo "\n=== Login Items ==="
osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null

echo "\n=== Cron Jobs ==="
crontab -l 2>/dev/null

echo "\n=== SSH RC ==="
cat ~/.ssh/rc 2>/dev/null

echo "\n=== Terminal Preferences ==="
plutil -p ~/Library/Preferences/com.apple.Terminal.plist 2>/dev/null | grep -A2 "CommandString"

echo "\n=== iTerm2 AutoLaunch ==="
ls -la "$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch/" 2>/dev/null

echo "\n=== Folder Actions ==="
ls -la "$HOME/Library/Scripts/Folder Action Scripts/" 2>/dev/null

echo "\n=== QuickLook Plugins ==="
ls -la ~/Library/QuickLook/ 2>/dev/null

echo "\n=== Screen Savers ==="
ls -la ~/Library/Screen\ Savers/ 2>/dev/null

echo "\n=== Spotlight Importers ==="
ls -la ~/Library/Spotlight/ 2>/dev/null

echo "\n=== Audio Plugins ==="
ls -la ~/Library/Audio/Plug-ins/Components/ 2>/dev/null
```

## Removal & Cleanup

### Remove Launch Agent
```bash
launchctl unload ~/Library/LaunchAgents/com.example.plist
rm ~/Library/LaunchAgents/com.example.plist
```

### Remove Login Item
```bash
osascript -e 'tell application "System Events" to delete login item "itemname"'
```

### Remove Cron Job
```bash
crontab -r
```

### Remove Shell Persistence
```bash
# Edit and remove malicious lines
nano ~/.zshrc
# or
sed -i '' '/malicious_command/d' ~/.zshrc
```

## Best Practices for Security Testing

1. **Document everything** - Keep track of all persistence mechanisms you create
2. **Test in isolated environments** - Use VMs or test machines
3. **Have removal procedures ready** - Know how to clean up after testing
4. **Check for conflicts** - Some mechanisms may interfere with each other
5. **Verify triggers** - Test that each mechanism actually executes
6. **Monitor logs** - Check system logs for detection

## References

- [Beyond the good ol' LaunchAgents](https://theevilbit.github.io/beyond/)
- [HackTricks macOS Persistence](https://book.hacktricks.xyz/pentesting/mac-os/mac-os-persistence)
- [SpecterOps Audio Unit Plug-ins](https://posts.specterops.io/audio-unit-plug-ins-89d3434a882)
- [Objective-See Finder Sync Extensions](https://objective-see.org/blog/blog_0x11.html)
