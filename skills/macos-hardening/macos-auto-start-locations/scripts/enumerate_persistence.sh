#!/bin/bash
# macOS Persistence Enumeration Script
# Usage: ./enumerate_persistence.sh [--output FILE]

set -e

OUTPUT_FILE="${1:-/dev/null}"

log() {
    echo "$1" | tee -a "$OUTPUT_FILE"
}

log "=== macOS Persistence Enumeration ==="
log "Timestamp: $(date)"
log "User: $(whoami)"
log ""

# Launch Agents
log "=== User Launch Agents ==="
if [ -d "~/Library/LaunchAgents" ]; then
    ls -la ~/Library/LaunchAgents/ 2>/dev/null | tee -a "$OUTPUT_FILE"
    for plist in ~/Library/LaunchAgents/*.plist; do
        if [ -f "$plist" ]; then
            log "--- $plist ---"
            grep -E "(Label|ProgramArguments|RunAtLoad)" "$plist" 2>/dev/null | head -10 | tee -a "$OUTPUT_FILE"
        fi
    done
else
    log "No LaunchAgents directory found"
fi
log ""

# Launch Daemons (requires sudo)
log "=== System Launch Daemons ==="
if sudo -n true 2>/dev/null; then
    sudo ls -la /Library/LaunchDaemons/ 2>/dev/null | tee -a "$OUTPUT_FILE"
else
    log "Skipping LaunchDaemons (requires sudo)"
fi
log ""

# Shell Startup Files
log "=== Shell Startup Files ==="
for file in ~/.zshrc ~/.bashrc ~/.profile ~/.zprofile ~/.zshenv ~/.bash_profile; do
    if [ -f "$file" ]; then
        log "--- $file ---"
        tail -20 "$file" | tee -a "$OUTPUT_FILE"
    fi
done
log ""

# Login Items
log "=== Login Items ==="
osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | tee -a "$OUTPUT_FILE" || log "Could not retrieve login items"
log ""

# Cron Jobs
log "=== Cron Jobs ==="
crontab -l 2>/dev/null | tee -a "$OUTPUT_FILE" || log "No user cron jobs"
log ""

# SSH RC
log "=== SSH RC ==="
if [ -f "~/.ssh/rc" ]; then
    cat ~/.ssh/rc | tee -a "$OUTPUT_FILE"
else
    log "No ~/.ssh/rc found"
fi
log ""

# Terminal Preferences
log "=== Terminal Preferences ==="
if [ -f "~/Library/Preferences/com.apple.Terminal.plist" ]; then
    plutil -p ~/Library/Preferences/com.apple.Terminal.plist 2>/dev/null | grep -A3 "CommandString" | tee -a "$OUTPUT_FILE" || log "No CommandString found"
else
    log "No Terminal preferences found"
fi
log ""

# iTerm2
log "=== iTerm2 AutoLaunch ==="
if [ -d "$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch" ]; then
    ls -la "$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch/" 2>/dev/null | tee -a "$OUTPUT_FILE"
else
    log "No iTerm2 AutoLaunch directory"
fi
log ""

# Folder Actions
log "=== Folder Actions ==="
if [ -d "$HOME/Library/Scripts/Folder Action Scripts" ]; then
    ls -la "$HOME/Library/Scripts/Folder Action Scripts/" 2>/dev/null | tee -a "$OUTPUT_FILE"
else
    log "No Folder Action Scripts directory"
fi
log ""

# QuickLook Plugins
log "=== QuickLook Plugins ==="
if [ -d "~/Library/QuickLook" ]; then
    ls -la ~/Library/QuickLook/ 2>/dev/null | tee -a "$OUTPUT_FILE"
else
    log "No QuickLook directory"
fi
log ""

# Screen Savers
log "=== Screen Savers ==="
if [ -d "~/Library/Screen Savers" ]; then
    ls -la ~/Library/Screen\ Savers/ 2>/dev/null | tee -a "$OUTPUT_FILE"
else
    log "No Screen Savers directory"
fi
log ""

# Spotlight Importers
log "=== Spotlight Importers ==="
if [ -d "~/Library/Spotlight" ]; then
    ls -la ~/Library/Spotlight/ 2>/dev/null | tee -a "$OUTPUT_FILE"
else
    log "No Spotlight directory"
fi
log ""

# Audio Plugins
log "=== Audio Plugins ==="
if [ -d "~/Library/Audio/Plug-ins/Components" ]; then
    ls -la ~/Library/Audio/Plug-ins/Components/ 2>/dev/null | tee -a "$OUTPUT_FILE"
else
    log "No Audio Plugins directory"
fi
log ""

log "=== Enumeration Complete ==="
log "Output saved to: $OUTPUT_FILE"
