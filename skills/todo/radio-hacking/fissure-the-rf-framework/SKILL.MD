---
name: fissure-rf-framework
description: How to use the FISSURE RF framework for signal detection, protocol discovery, and RF reverse engineering. Use this skill whenever the user mentions RF signals, SDR (Software Defined Radio), signal analysis, protocol reverse engineering, radio hacking, FISSURE, GNU Radio, HackRF, USRP, RTL-SDR, LimeSDR, or any RF security testing. Make sure to use this skill for any radio frequency work, signal capture, wireless protocol analysis, or when working with software-defined radio hardware.
---

# FISSURE RF Framework

**Frequency Independent SDR-based Signal Understanding and Reverse Engineering**

FISSURE is an open-source RF and reverse engineering framework for signal detection, classification, protocol discovery, attack execution, IQ manipulation, and vulnerability analysis.

## Quick Start

### Installation

```bash
git clone https://github.com/ainfosec/FISSURE.git
cd FISSURE
git checkout <branch>
git submodule update --init
./install
```

**Select the correct branch for your OS:**

| Operating System | Branch |
|-----------------|--------|
| Ubuntu 18.04 (x64) | `Python2_maint-3.7` |
| Ubuntu 20.04 (x64) | `Python3_maint-3.8` |
| Ubuntu 22.04 (x64) | `Python3_maint-3.10` (beta) |
| KDE neon 5.25 | `Python3_maint-3.8` |

**Important:** Install on a clean OS to avoid conflicts. Select all recommended checkboxes during installation.

### Launch

```bash
fissure
```

## Core Components

### 1. Dashboard
Main interface for accessing all FISSURE capabilities.

### 2. Central Hub (HIPRFISR)
Central coordination point for RF operations.

### 3. Target Signal Identification (TSI)
Identify and classify unknown RF signals.

### 4. Protocol Discovery (PD)
Analyze and reverse engineer wireless protocols.

### 5. Flow Graph & Script Executor (FGE)
Run GNU Radio flowgraphs and custom scripts.

## Capabilities

| Capability | Use Case |
|------------|----------|
| **Signal Detector** | Detect RF energy presence |
| **IQ Manipulation** | Process and modify IQ samples |
| **Signal Lookup** | Identify known signal types |
| **Pattern Recognition** | Find patterns in signal data |
| **Attacks** | Execute RF attack scenarios |
| **Fuzzing** | Test protocol robustness |
| **Signal Playlists** | Simulate traffic with archived signals |
| **Image Gallery** | Visualize signal characteristics |
| **Packet Crafting** | Build custom RF packets |
| **Scapy Integration** | Network packet manipulation |
| **CRC Calculator** | Calculate checksums for protocols |
| **Logging** | Track operations and results |

## Supported Hardware

- **USRP**: X3xx, B2xx, B20xmini, USRP2, N2xx
- **HackRF**
- **RTL2832U** (RTL-SDR)
- **802.11 Adapters**
- **LimeSDR**
- **bladeRF / bladeRF 2.0 micro**
- **Open Sniffer**
- **PlutoSDR**

## Learning Path

FISSURE includes 11 lessons covering:

1. **OpenBTS** - GSM base station setup
2. **Lua Dissectors** - Wireshark protocol analysis
3. **Sound eXchange** - Audio-based RF transmission
4. **ESP Boards** - ESP8266/ESP32 RF work
5. **Radiosonde Tracking** - Weather balloon signals
6. **RFID** - Radio frequency identification
7. **Data Types** - Signal data formats
8. **Custom GNU Radio Blocks** - Build custom processing blocks
9. **TPMS** - Tire pressure monitoring systems
10. **Ham Radio Exams** - Amateur radio preparation
11. **Wi-Fi Tools** - Wireless network analysis

## Common Workflows

### Signal Detection and Analysis

1. Launch FISSURE: `fissure`
2. Navigate to **Signal Detector**
3. Connect your SDR hardware
4. Set frequency range and sample rate
5. Capture and analyze signals

### Protocol Discovery

1. Use **Target Signal Identification (TSI)** to classify the signal
2. Navigate to **Protocol Discovery (PD)**
3. Capture packets and analyze structure
4. Use **CRC Calculator** for checksum analysis
5. Document protocol characteristics

### Attack Development

1. Use **Signal Lookup** to identify target protocol
2. Navigate to **Attacks** section
3. Select appropriate attack type
4. Use **Packet Crafting** to build payloads
5. Execute via **Flow Graph & Script Executor (FGE)**

### IQ File Processing

1. Use **IQ Manipulation** tools
2. Load captured IQ files
3. Apply filters, decimation, or modulation
4. Export processed data
5. Visualize in **Image Gallery**

## Best Practices

1. **Start with detection**: Always identify what signals are present before attempting analysis
2. **Document everything**: Use the **Logging** feature to track your work
3. **Use playlists**: Build signal archives for repeatable testing
4. **Verify hardware**: Ensure your SDR is properly configured before capture
5. **Follow lessons**: The built-in lessons provide proven workflows
6. **Check conflicts**: Review [Software And Conflicts](https://github.com/ainfosec/FISSURE/blob/Python3_maint-3.8/Help/Markdown/SoftwareAndConflicts.md) for OS-specific issues

## Troubleshooting

### Installation Issues
- Install on a clean OS
- Run with elevated permissions when prompted
- Check verification prompts (green = success, red = error)
- Review logs for specific error messages

### Hardware Not Detected
- Verify USB connections
- Check udev rules for SDR devices
- Ensure proper drivers are installed
- Test with `lsusb` to confirm device recognition

### Signal Capture Problems
- Verify frequency range is within hardware capabilities
- Check sample rate settings
- Ensure sufficient gain is set
- Confirm antenna is properly connected

## Resources

- **GitHub**: https://github.com/ainfosec/FISSURE
- **AIS Page**: https://www.ainfosec.com/technologies/fissure/
- **Discord**: https://discord.gg/JZDs5sgxcG
- **Twitter**: [@FissureRF](https://twitter.com/fissurerf)
- **GRCon22 Presentation**: https://events.gnuradio.org/event/18/contributions/246/

## Contributing

Suggestions are welcome via:
- GitHub Discussions
- Discord Server
- Pull requests for code contributions
- Issues for bug reports

## License

GPL-3.0

---

**Remember**: Always operate within legal boundaries and obtain proper authorization before conducting RF analysis or testing on systems you don't own.
