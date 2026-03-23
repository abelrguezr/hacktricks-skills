#!/bin/bash
# macOS Test Persistence Creation Script
# WARNING: Only use on systems you own or have authorization to test
# Usage: ./create_test_persistence.sh [type]
# Types: launchagent, shell, loginitem, cron, all

set -e

TEST_LABEL="com.test.persistence"
TEST_MARKER="/tmp/persistence_test_$$"

log() {
    echo "[INFO] $1"
}

error() {
    echo "[ERROR] $1" >&2
}

cleanup() {
    log "Cleaning up test marker: $TEST_MARKER"
    rm -f "$TEST_MARKER" 2>/dev/null || true
}

trap cleanup EXIT

create_launchagent() {
    log "Creating test LaunchAgent..."
    
    mkdir -p ~/Library/LaunchAgents
    
    cat > ~/Library/LaunchAgents/${TEST_LABEL}.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${TEST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>touch ${TEST_MARKER}_launchagent</string>
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
EOF
    
    log "LaunchAgent created at ~/Library/LaunchAgents/${TEST_LABEL}.plist"
    log "To load: launchctl load ~/Library/LaunchAgents/${TEST_LABEL}.plist"
    log "To unload: launchctl unload ~/Library/LaunchAgents/${TEST_LABEL}.plist"
}

create_shell_persistence() {
    log "Creating test shell persistence..."
    
    echo "# Test persistence marker" >> ~/.zshrc
    echo "touch ${TEST_MARKER}_zshrc" >> ~/.zshrc
    
    log "Added to ~/.zshrc"
    log "To remove: sed -i '' '/${TEST_MARKER}_zshrc/d' ~/.zshrc"
}

create_loginitem() {
    log "Creating test login item..."
    
    # Create a simple test script
    cat > /tmp/test_login_item.sh << 'EOF'
#!/bin/bash
touch /tmp/login_item_test
EOF
    chmod +x /tmp/test_login_item.sh
    
    log "Test script created at /tmp/test_login_item.sh"
    log "To add as login item:"
    log "  osascript -e 'tell application \"System Events\" to make login item at end with properties {path:\"/tmp/test_login_item.sh\", hidden:true}'"
    log "To remove:"
    log "  osascript -e 'tell application \"System Events\" to delete login item \"test_login_item.sh\"'"
}

create_cron() {
    log "Creating test cron job..."
    
    # Create temporary crontab
    TEMP_CRON=$(mktemp)
    
    # Get existing crontab or create empty
    crontab -l > "$TEMP_CRON" 2>/dev/null || true
    
    # Add test job
    echo "* * * * * touch ${TEST_MARKER}_cron" >> "$TEMP_CRON"
    
    # Install new crontab
    crontab "$TEMP_CRON"
    rm "$TEMP_CRON"
    
    log "Cron job created"
    log "To remove: crontab -l | grep -v '${TEST_MARKER}_cron' | crontab -"
}

create_all() {
    log "Creating all test persistence mechanisms..."
    create_launchagent
    create_shell_persistence
    create_loginitem
    create_cron
    log "All test persistence mechanisms created"
}

show_help() {
    echo "Usage: $0 [type]"
    echo "Types:"
    echo "  launchagent - Create test LaunchAgent"
    echo "  shell - Create test shell persistence"
    echo "  loginitem - Create test login item"
    echo "  cron - Create test cron job"
    echo "  all - Create all test mechanisms"
    echo ""
    echo "WARNING: Only use on systems you own or have authorization to test"
}

case "${1:-help}" in
    launchagent)
        create_launchagent
        ;;
    shell)
        create_shell_persistence
        ;;
    loginitem)
        create_loginitem
        ;;
    cron)
        create_cron
        ;;
    all)
        create_all
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown type: $1"
        show_help
        exit 1
        ;;
esac
