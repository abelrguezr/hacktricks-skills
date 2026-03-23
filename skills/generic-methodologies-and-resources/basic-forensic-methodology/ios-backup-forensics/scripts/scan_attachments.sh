#!/bin/bash
# Scan messaging app attachments for structural exploits
# Usage: ./scan_attachments.sh <reconstructed_backup_path>

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <reconstructed_backup_path>"
    echo "Example: $0 /tmp/reconstructed"
    exit 1
fi

BACKUP_PATH="$1"

echo "[+] Scanning messaging attachments for structural exploits..."
echo "    Target: $BACKUP_PATH"

# Check for elegant-bouncer
if ! command -v elegant-bouncer &> /dev/null; then
    echo "[!] elegant-bouncer not found. Installing..."
    pip install elegant-bouncer 2>/dev/null || {
        echo "[!] Failed to install elegant-bouncer"
        echo "[!] Manual scan instructions:"
        echo "    1. Find attachments in:"
        echo "       - Library/SMS/Attachments/ (iMessage)"
        echo "       - AppDomainGroup-group.net.whatsapp.WhatsApp.shared/Message/Media/ (WhatsApp)"
        echo "       - Library/Caches/ (Signal, Telegram)"
        echo "    2. Run structural detectors on suspicious files"
        exit 1
    }
fi

# Scan messaging attachments
echo "[+] Running structural analysis..."
elegant-bouncer --scan --messaging "$BACKUP_PATH"

# Alternative: Manual scan of specific directories
echo ""
echo "[+] Scanning specific attachment directories..."

# iMessage attachments
if [ -d "$BACKUP_PATH/Library/SMS/Attachments" ]; then
    echo "[+] Scanning iMessage attachments..."
    find "$BACKUP_PATH/Library/SMS/Attachments" -type f | while read -r file; do
        # Check file type and run appropriate detector
        case "$file" in
            *.pdf) echo "    Checking PDF: $file" ;;
            *.webp|*.jpg|*.png) echo "    Checking image: $file" ;;
            *.ttf|*.otf) echo "    Checking font: $file" ;;
            *.dng|*.tiff) echo "    Checking DNG/TIFF: $file" ;;
        esac
    done
fi

# WhatsApp media
if [ -d "$BACKUP_PATH/AppDomainGroup-group.net.whatsapp.WhatsApp.shared/Message/Media" ]; then
    echo "[+] Scanning WhatsApp media..."
    find "$BACKUP_PATH/AppDomainGroup-group.net.whatsapp.WhatsApp.shared/Message/Media" -type f | head -20 | while read -r file; do
        echo "    Found: $file"
    done
fi

# Telegram cache
if [ -d "$BACKUP_PATH/Library/Caches" ]; then
    echo "[+] Scanning Telegram/Signal cache..."
    find "$BACKUP_PATH/Library/Caches" -type f -size +100k | head -20 | while read -r file; do
        echo "    Found large file: $file"
    done
fi

echo ""
echo "✓ Scan complete"
echo "[+] Review any THREAT detections above"
echo "[+] False positives are possible - validate manually"
