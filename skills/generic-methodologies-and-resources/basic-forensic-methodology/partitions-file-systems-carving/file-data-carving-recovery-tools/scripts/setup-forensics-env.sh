#!/bin/bash
# Forensic Tools Environment Setup
# Installs common carving and recovery tools
#
# Usage: sudo ./setup-forensics-env.sh

set -e

echo "Installing forensic data carving tools..."
echo ""

# Check for root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Detect package manager
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt"
    echo "Detected Debian/Ubuntu system"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    echo "Detected Fedora/RHEL system"
elif command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
    echo "Detected Arch Linux system"
else
    echo "Unsupported package manager. Please install tools manually."
    exit 1
fi

echo ""
echo "Installing packages..."

case "$PKG_MANAGER" in
    apt)
        apt-get update
        apt-get install -y \
            autopsy \
            binwalk \
            foremost \
            scalpel \
            gddrescue \
            ddrescueview \
            extundelete \
            ext4magic \
            testdisk \
            pdftotext \
            viu \
            git \
            cmake \
            build-essential
        ;;
    dnf)
        dnf install -y \
            autopsy \
            binwalk \
            foremost \
            scalpel \
            gddrescue \
            extundelete \
            testdisk \
            poppler-utils \
            git \
            cmake \
            gcc \
            make
        ;;
    pacman)
        pacman -S --noconfirm \
            autopsy \
            binwalk \
            foremost \
            scalpel \
            gddrescue \
            testdisk \
            poppler \
            viu \
            git \
            cmake \
            base-devel
        ;;
esac

echo ""
echo "Building Bulk Extractor from source..."
git clone https://github.com/simsong/bulk_extractor.git /tmp/bulk_extractor 2>/dev/null || true
cd /tmp/bulk_extractor
mkdir -p build && cd build
cmake .. && make -j$(nproc) && sudo make install

echo ""
echo "Installing YARA-X..."
if command -v cargo &> /dev/null; then
    cargo install yarax
else
    echo "YARA-X requires Rust/Cargo. Install with: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
fi

echo ""
echo "Setup complete!"
echo ""
echo "Available tools:"
echo "  - Autopsy (GUI/CLI forensic platform)"
echo "  - Binwalk (firmware analysis)"
echo "  - Foremost (file carving)"
echo "  - Scalpel (configurable carving)"
echo "  - Bulk Extractor (network artifacts)"
echo "  - PhotoRec (via testdisk)"
echo "  - ddrescue (drive imaging)"
echo "  - extundelete/ext4magic (EXT recovery)"
echo "  - YARA-X (artifact classification)"
echo ""
echo "Run './carve-image.sh --help' for usage."
