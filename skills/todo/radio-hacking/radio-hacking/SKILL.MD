---
name: radio-hacking
description: Radio hacking and SDR (Software Defined Radio) analysis. Use this skill whenever the user mentions radio signals, SDR, HackRF, RTL-SDR, LoRa, Zigbee, RFID, NFC, wireless protocol analysis, signal capture, frequency scanning, or any radio frequency security testing. This skill helps with setting up SDR equipment, analyzing radio signals, understanding wireless protocols, and conducting security assessments of radio communications.
---

# Radio Hacking Skill

A comprehensive guide for radio frequency analysis, SDR operations, and wireless security testing.

## What This Skill Does

This skill helps you:
- Set up and configure SDR hardware (RTL-SDR, HackRF, BladeRF, etc.)
- Analyze and capture radio signals across various frequency bands
- Understand and reverse engineer wireless protocols
- Conduct security assessments of radio communications
- Use common radio hacking tools effectively

## Quick Start

### 1. Hardware Setup

**RTL-SDR (Budget Option)**
```bash
# Install drivers
sudo apt install rtl-sdr
# Verify device
lsusb | grep -i rtl
# Test reception
rtl_test -d 0
```

**HackRF (Full Duplex)**
```bash
# Install
sudo apt install hackrf
# Verify
hackrf_info
# Test
hackrf_transfer -r test.bin -f 100M -a 1000000
```

### 2. Essential Tools

| Tool | Purpose | Install |
|------|---------|--------|
| `rtl_sdr` | Basic RTL-SDR capture | `sudo apt install rtl-sdr` |
| `gqrx` | SDR receiver GUI | `sudo apt install gqrx-sdr` |
| `gr-osmosdr` | GNU Radio SDR source | `sudo apt install gr-osmosdr` |
| `rtl_433` | Decode IoT sensors | `sudo apt install rtl_433` |
| `rtl_fm` | FM demodulation | `sudo apt install rtl-sdr` |
| `dump1090` | ADS-B aircraft tracking | `sudo apt install dump1090-mut` |
| `yatebts` | GSM analysis | See yatebts.org |

### 3. Common Frequency Bands

| Band | Range | Common Uses |
|------|-------|-------------|
| LF | 30-300 kHz | Navigation, time signals |
| MF | 300-3000 kHz | AM radio, maritime |
| HF | 3-30 MHz | Shortwave, ham radio |
| VHF | 30-300 MHz | FM radio, TV, aviation |
| UHF | 300-3000 MHz | TV, cellular, WiFi, Bluetooth |
| SHF | 3-30 GHz | WiFi 5GHz, radar, satellite |

## Signal Analysis Workflow

### Step 1: Spectrum Scan

```bash
# Quick spectrum scan with rtl_power
rtl_power -f 88M:108M:100k -l 10 -g 48 -i 1 -o spectrum.csv

# View with gnuplot
gnuplot -e "set terminal png size 1200,600; set output 'spectrum.png'; plot 'spectrum.csv' with lines"
```

### Step 2: Signal Identification

Use the scripts in `scripts/` to help identify signals:

```bash
# Analyze captured signal
python scripts/analyze_signal.py -i capture.bin -f 433M

# Identify modulation type
python scripts/identify_modulation.py -i capture.bin
```

### Step 3: Protocol Analysis

```bash
# Decode common protocols
rtl_433 -g -f 433920000 -s 2500000 -r capture.bin

# For LoRa
rtl_lora -f 868M -s 125k -r capture.bin
```

## Common Protocols

### LoRa (Long Range)

```bash
# Capture LoRa signals
rtl_lora -f 868300000 -s 125000 -r lora_capture.bin

# Decode with lora_gateway
lora_gateway -f lora_capture.bin
```

### Zigbee

```bash
# Use Ubertooth or CC2531 dongle
sudo ubertooth-rf sniffer -f zigbee_capture.bin

# Analyze with Wireshark
wireshark -r zigbee_capture.bin
```

### RFID/NFC

```bash
# Proxmark3 for RFID
pm3 > hw vendor
pm3 > hf 14a detect

# NFC with libnfc
nfc-list
nfc-read
```

### GSM/Cellular

```bash
# OsmocomBB for GSM
bb-gsm -f gsm_capture.bin

# YateBTS for analysis
yatebts -c yatebts.conf
```

## Security Testing

### 1. Signal Jamming Detection

```bash
# Monitor for jamming patterns
python scripts/detect_jamming.py -f 2400M:2500M -d 60
```

### 2. Replay Attack Testing

```bash
# Capture and replay (for authorized testing only)
rtl_fm -f 433M -s 250k -r replay.bin
rtl_tx -f 433M -s 250k replay.bin
```

### 3. Protocol Fuzzing

```bash
# Generate fuzzing payloads
python scripts/fuzz_protocol.py --protocol lora --output fuzz.bin
```

## Best Practices

### Legal Considerations

⚠️ **Always ensure you have authorization before testing radio systems.**

- Only test equipment you own or have explicit permission to test
- Respect local radio regulations (FCC, Ofcom, etc.)
- Never transmit on frequencies without proper licensing
- Document all testing activities

### Signal Chain Optimization

1. **Antenna Selection**: Match antenna to frequency band
2. **Gain Settings**: Start low, increase gradually to avoid overload
3. **Filtering**: Use bandpass filters to reduce interference
4. **Sampling Rate**: Match to signal bandwidth (2x minimum)

### Documentation

Always document:
- Frequency and bandwidth
- Modulation type
- Protocol details
- Security findings
- Mitigation recommendations

## Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| No signal detected | Check antenna connection, increase gain |
| Overload/distortion | Reduce gain, add attenuator |
| Frequency offset | Use `--ppm` correction parameter |
| Driver issues | Reinstall drivers, check permissions |
| USB bandwidth | Use USB 3.0, reduce sample rate |

### Debug Commands

```bash
# Check device permissions
ls -la /dev/usb/

# Monitor USB traffic
sudo usbmon

# Check signal strength
rtl_test -d 0 -v
```

## Resources

### Hardware

- RTL-SDR Blog: https://www.rtl-sdr.com
- Great Scott Gadgets: https://greatscottgadgets.com
- NerdKits: https://nerdkits.com

### Software

- GNU Radio: https://gnuradio.org
- SDR# (SDR Sharp): https://airspy.com
- HackRF: https://greatscottgadgets.com/hackrf

### Learning

- Hackaday Radio Hacking: https://hackaday.io/tag/radio
- SDR tutorials: https://www.rtl-sdr.com/tag/tutorial/
- Protocol documentation: https://github.com/rtl-sdr/rtl_433

## Next Steps

1. Start with RTL-SDR for basic signal exploration
2. Learn GNU Radio for custom signal processing
3. Study specific protocols of interest
4. Practice on your own equipment first
5. Join radio hacking communities for support

---

**Remember**: Radio hacking is a powerful skill for security testing, but always use it responsibly and legally.
