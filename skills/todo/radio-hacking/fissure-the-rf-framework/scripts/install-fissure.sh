#!/bin/bash
# FISSURE Installation Helper Script
# Automates the installation process with OS detection

set -e

echo "=== FISSURE RF Framework Installation ==="
echo ""

# Detect operating system
OS_NAME=$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
OS_VERSION=$(lsb_release -rs 2>/dev/null || cat /etc/os-release | grep VERSION_ID | cut -d'"' -f2)

echo "Detected OS: $OS_NAME"
echo "Version: $OS_VERSION"
echo ""

# Determine appropriate branch
BRANCH=""
if [[ "$OS_NAME" == *"Ubuntu 18.04"* ]]; then
    BRANCH="Python2_maint-3.7"
elif [[ "$OS_NAME" == *"Ubuntu 20.04"* ]]; then
    BRANCH="Python3_maint-3.8"
elif [[ "$OS_NAME" == *"Ubuntu 22.04"* ]]; then
    BRANCH="Python3_maint-3.10"
    echo "⚠️  Ubuntu 22.04 is in beta status - some features may be missing"
elif [[ "$OS_NAME" == *"KDE neon"* ]]; then
    BRANCH="Python3_maint-3.8"
else
    echo "⚠️  OS not automatically detected. Please select a branch manually:"
    echo "  - Python2_maint-3.7 (Ubuntu 18.04)"
    echo "  - Python3_maint-3.8 (Ubuntu 20.04, KDE neon)"
    echo "  - Python3_maint-3.10 (Ubuntu 22.04 - beta)"
    read -p "Enter branch name: " BRANCH
fi

echo ""
echo "Selected branch: $BRANCH"
echo ""

# Check if already cloned
if [ -d "FISSURE" ]; then
    echo "FISSURE directory already exists."
    read -p "Do you want to update existing installation? (y/n) " UPDATE
    if [ "$UPDATE" = "y" ]; then
        cd FISSURE
        git pull
        git checkout $BRANCH
    else
        echo "Installation cancelled."
        exit 0
    fi
else
    echo "Cloning FISSURE repository..."
    git clone https://github.com/ainfosec/FISSURE.git
    cd FISSURE
    git checkout $BRANCH
fi

echo ""
echo "Initializing submodules..."
git submodule update --init

echo ""
echo "Starting FISSURE installer..."
echo "Note: You will need sudo access for some installation steps."
echo ""

# Run the installer
./install

echo ""
echo "=== Installation Complete ==="
echo ""
echo "To launch FISSURE, run: fissure"
echo ""
echo "For help, refer to the FISSURE Help menu or visit:"
echo "https://github.com/ainfosec/FISSURE"
