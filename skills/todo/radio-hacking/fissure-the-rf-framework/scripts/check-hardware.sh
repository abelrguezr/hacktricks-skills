#!/bin/bash
# FISSURE Hardware Detection Script
# Checks for connected SDR devices

echo "=== FISSURE Hardware Detection ==="
echo ""

# Check for USB devices
echo "Connected USB devices:"
lsusb 2>/dev/null | grep -iE "hackrf|rtl|lime|blade|usrp|pluto|adalm" || echo "No SDR devices detected via lsusb"
echo ""

# Check for specific hardware types
echo "Checking for specific SDR hardware:"
echo ""

# HackRF
if lsusb 2>/dev/null | grep -qi "hackrf"; then
    echo "✓ HackRF detected"
    hackrf_info 2>/dev/null && echo "  - hackrf_info: OK" || echo "  - hackrf_info: Not installed"
else
    echo "✗ HackRF not detected"
fi
echo ""

# RTL-SDR
if lsusb 2>/dev/null | grep -qi "rtl2838\|rtl2832\|rtl-sdr"; then
    echo "✓ RTL-SDR detected"
    rtl_test -d 0 2>&1 | head -5 || echo "  - rtl_test: Not installed or device in use"
else
    echo "✗ RTL-SDR not detected"
fi
echo ""

# USRP
if lsusb 2>/dev/null | grep -qi "ettus\|usrp"; then
    echo "✓ USRP device detected"
    uhd_usrp_probe 2>/dev/null && echo "  - uhd_usrp_probe: OK" || echo "  - uhd_usrp_probe: Not installed"
else
    echo "✗ USRP not detected"
fi
echo ""

# LimeSDR
if lsusb 2>/dev/null | grep -qi "lime"; then
    echo "✓ LimeSDR detected"
    limesd 2>/dev/null --help > /dev/null && echo "  - limesd: OK" || echo "  - limesd: Not installed"
else
    echo "✗ LimeSDR not detected"
fi
echo ""

# bladeRF
if lsusb 2>/dev/null | grep -qi "nuand\|bladerf"; then
    echo "✓ bladeRF detected"
    bladerf-cli 2>/dev/null --help > /dev/null && echo "  - bladerf-cli: OK" || echo "  - bladerf-cli: Not installed"
else
    echo "✗ bladeRF not detected"
fi
echo ""

# PlutoSDR
if lsusb 2>/dev/null | grep -qi "pluto\|adalm"; then
    echo "✓ PlutoSDR detected"
    iio_info 2>/dev/null | grep -i pluto > /dev/null && echo "  - iio_info: OK" || echo "  - iio_info: Not installed"
else
    echo "✗ PlutoSDR not detected"
fi
echo ""

# Check udev rules
echo "Checking udev rules:"
if [ -f "/etc/udev/rules.d/50-hackrf.rules" ]; then
    echo "✓ HackRF udev rules installed"
else
    echo "✗ HackRF udev rules not found"
fi

if [ -f "/etc/udev/rules.d/50-rtl-sdr.rules" ]; then
    echo "✓ RTL-SDR udev rules installed"
else
    echo "✗ RTL-SDR udev rules not found"
fi
echo ""

echo "=== Detection Complete ==="
echo ""
echo "If your device is not detected:"
echo "1. Check USB connections"
echo "2. Verify device drivers are installed"
echo "3. Check udev rules are in place"
echo "4. Try a different USB port"
echo "5. Run with sudo if permission issues occur"
