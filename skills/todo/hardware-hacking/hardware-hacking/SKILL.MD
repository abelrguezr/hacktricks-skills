---
name: hardware-hacking
description: Hardware hacking and embedded device debugging using JTAG and SWD protocols. Use this skill whenever the user mentions hardware debugging, JTAG, SWD, boundary scan, embedded device access, PCB analysis, chip identification, or reverse engineering hardware. Trigger for any task involving hardware interface identification, debugging port discovery, or embedded system access—even if the user doesn't explicitly name JTAG or SWD.
---

# Hardware Hacking

A skill for hardware debugging and embedded device access using JTAG and SWD protocols.

## When to Use This Skill

Use this skill when:
- Identifying or locating JTAG/SWD pins on a PCB
- Debugging embedded devices through hardware interfaces
- Performing boundary scans on chips
- Reverse engineering hardware with unknown interfaces
- Setting up hardware debugging tools (JTAGulator, JTAGenum, etc.)
- Analyzing PCBs for debug access points

## JTAG Protocol

JTAG (Joint Test Action Group) enables boundary scanning of embedded circuitry. It uses a four-wire Test Access Port (TAP) to access test functions built into components.

### JTAG Commands

| Command | Purpose |
|---------|---------|
| **BYPASS** | Test a specific chip without passing through other chips |
| **SAMPLE/PRELOAD** | Sample data entering/leaving the device in normal mode |
| **EXTEST** | Set and read pin states |
| **IDCODE** | Identify a device |
| **INTEST** | Internal testing of the device |

### Test Access Port (TAP) Signals

The TAP uses five signals:

| Signal | Name | Function |
|--------|------|----------|
| **TCK** | Test clock input | Clock defining how often the TAP controller takes action (jumps to next state) |
| **TMS** | Test mode select | Controls the finite state machine. Voltage below threshold = 0, above = 1 |
| **TDI** | Test data input | Sends data into the chip through scan cells (vendor-defined protocol) |
| **TDO** | Test data output | Sends data out of the chip |
| **TRST** | Test reset (optional) | Resets the finite state machine to a known good state |

**Note:** TRST is optional. Holding TMS at 1 for five consecutive clock cycles also invokes a reset.

### Identifying JTAG Pins

#### Method 1: JTAGulator (Fastest, Most Expensive)

The JTAGulator is a dedicated device for detecting JTAG ports (also detects UART pinouts).

**Process:**
1. Connect 24 channels to board pins
2. Device performs brute-force attack of all possible combinations
3. Sends IDCODE and BYPASS boundary scan commands
4. Displays channel corresponding to each JTAG signal when response received

#### Method 2: JTAGenum (Cheaper, Slower)

JTAGenum runs on an Arduino-compatible microcontroller.

**Process:**
1. Define pins of the probing device using its pinout diagram
2. Connect these pins to test points on the target device
3. Run enumeration to identify JTAG signals

**Repository:** https://github.com/cyphunk/JTAGenum/

#### Method 3: PCB Inspection (Free, Manual)

Inspect the PCB for JTAG indicators:

1. **Tag-Connect interface** - Clear indication of JTAG connector presence
   - Reference: https://www.tag-connect.com/info/

2. **Chipset datasheets** - May reveal pinout diagrams pointing to JTAG interfaces

3. **PCB markings** - Sometimes pins are marked directly on the PCB

## SWD Protocol

SWD (Serial Wire Debug) is an ARM-specific debugging protocol.

### SWD Interface

SWD requires only **two pins**:

| Signal | Function | JTAG Equivalent |
|--------|----------|-----------------|
| **SWDIO** | Bidirectional data signal | TDI + TDO combined |
| **SWCLK** | Clock signal | TCK |

### SWJ-DP (Serial Wire or JTAG Debug Port)

Many devices support SWJ-DP, a combined JTAG and SWD interface that enables connecting either a SWD or JTAG probe to the target.

## Common Workflows

### Workflow 1: Unknown PCB Debug Access

**Goal:** Find debug access on an unknown board

**Steps:**
1. Inspect PCB for Tag-Connect interface or marked pins
2. Identify chipsets and check datasheets for JTAG/SWD pinouts
3. If no markings found, use JTAGulator for fast detection
4. If JTAGulator unavailable, use JTAGenum on Arduino
5. Verify detected pins by sending IDCODE command

### Workflow 2: JTAG Setup

**Goal:** Configure JTAG debugging

**Steps:**
1. Identify TAP signals (TCK, TMS, TDI, TDO, optionally TRST)
2. Connect probe to identified pins
3. Send IDCODE to verify device identification
4. Use BYPASS to isolate specific chips if needed
5. Use SAMPLE/PRELOAD to monitor data flow
6. Use EXTEST to set/read pin states

### Workflow 3: SWD Setup

**Goal:** Configure SWD debugging on ARM device

**Steps:**
1. Identify SWDIO and SWCLK pins
2. Check if device supports SWJ-DP (combined interface)
3. Connect SWD probe to identified pins
4. Verify connection with device identification

## Tools Reference

| Tool | Purpose | Cost | Speed |
|------|---------|------|-------|
| JTAGulator | JTAG/UART pin detection | High | Fast |
| JTAGenum | JTAG pin enumeration | Low | Slow |
| PCB inspection | Manual pin identification | Free | Variable |

## Tips

- **TRST is optional** - If missing, reset by holding TMS high for 5 clock cycles
- **SWD is more compact** - Only 2 pins vs JTAG's 4-5 pins
- **SWJ-DP is common** - Many ARM devices support both protocols on same pins
- **Datasheets are valuable** - Often contain pinout diagrams for JTAG/SWD
- **Tag-Connect is a telltale sign** - If you see it, JTAG is likely present

## Example Scenarios

**Scenario 1: Embedded Device Debugging**

*User has:* Unknown embedded device, needs to debug firmware
*Approach:* Inspect PCB → Check datasheets → Use JTAGulator → Send IDCODE → Debug

**Scenario 2: ARM Device Access**

*User has:* ARM-based device, wants to flash firmware
*Approach:* Identify SWDIO/SWCLK → Connect SWD probe → Flash firmware

**Scenario 3: PCB Reverse Engineering**

*User has:* PCB with no documentation
*Approach:* Visual inspection → Tag-Connect check → Chipset identification → Datasheet lookup → JTAGenum if needed
