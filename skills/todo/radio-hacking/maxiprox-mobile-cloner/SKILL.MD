---
name: maxiprox-mobile-cloner
description: Build a portable, battery-powered HID MaxiProx 125 kHz badge cloner for physical security assessments. Use this skill whenever you need to convert a mains-powered HID MaxiProx 5375 reader into a field-deployable device, or when working on portable RFID credential harvesting setups for authorized penetration testing. Also use when planning physical security assessments involving proximity card cloning, or when you need guidance on battery-powered HID reader conversions.
---

# MaxiProx Mobile Cloner Builder

A step-by-step guide to converting a mains-powered HID MaxiProx 5375 reader into a portable, battery-powered badge cloner for physical security assessments.

## ⚠️ Safety & Legal Notice

**This skill is for authorized security assessments only.** Ensure you have written permission before using this device on any property or system.

**Electrical Safety:**
- Manipulating mains-powered equipment and Lithium-ion power-banks can be dangerous
- Verify every connection **before** energising the circuit
- Keep the antennas, coax and ground planes exactly as they were in the factory design to avoid detuning the reader

## Bill of Materials

| Component | Specification |
|-----------|---------------|
| HID MaxiProx 5375 reader | Or any 12 V HID Prox® long-range reader |
| ESP RFID Tool v2.2 | ESP32-based Wiegand sniffer/logger |
| USB-PD trigger module | Able to negotiate 12 V @ ≥3 A |
| USB-C power-bank | 100 W, outputs 12 V PD profile |
| Hook-up wire | 26 AWG silicone-insulated – red/white |
| Toggle switch | Panel-mount SPST (for beeper kill-switch) |
| Switch guard | NKK AT4072 switch-guard / accident-proof cap |
| Soldering tools | Soldering iron, solder wick & desolder pump |
| Hand tools | ABS-rated: coping-saw, utility-knife, flat & half-round files |
| Drill bits | 1/16″ (1.5 mm) and 1/8″ (3 mm) |
| Fasteners | 3 M VHB double-sided tape & Zip-ties |

## Phase 1: Power Sub-System

### 1. Remove factory buck-converter
- Desolder and remove the factory buck-converter daughter-board used to generate 5 V for the logic PCB
- This board is no longer needed since we're using USB-PD for power

### 2. Install USB-PD trigger
- Mount a USB-PD trigger next to the ESP RFID Tool
- Route the trigger's USB-C receptacle to the outside of the enclosure
- The PD trigger negotiates 12 V from the power-bank and feeds it directly to the MaxiProx (the reader natively expects 10–14 V)
- A secondary 5 V rail is taken from the ESP board to power any accessories

### 3. Position the battery
- Place the 100 W battery pack flush against the internal standoff
- **Critical:** Keep power cables away from the ferrite antenna to preserve RF performance
- No power cables should drape across the antenna

## Phase 2: Beeper Kill-Switch (Silent Operation)

### 1. Locate speaker pads
- Find the two speaker pads on the MaxiProx logic board

### 2. Prepare pads
- Wick **both** pads clean
- Re-solder only the **negative** pad

### 3. Wire the switch
- Solder 26 AWG wires (white = negative, red = positive) to the beeper pads
- Route them through a newly cut slot to a panel-mount SPST switch
- When the switch is open, the beeper circuit is broken and the reader operates silently

### 4. Install safety guard
- Fit an NKK AT4072 spring-loaded safety cap over the toggle
- Enlarge the bore with a coping-saw / file until it snaps over the switch body
- The guard prevents accidental activation inside a backpack

## Phase 3: Enclosure Work

### 1. Remove internal bump-out
- Use flush cutters then a knife & file to remove the internal ABS "bump-out"
- This allows the large USB-C battery to sit flat on the standoff

### 2. Carve cable channels
- Carve two parallel channels in the enclosure wall for the USB-C cable
- This locks the battery in place and eliminates movement/vibration

### 3. Create power button aperture
1. Tape a paper stencil over the location
2. Drill 1/16″ pilot holes in all four corners
3. Enlarge with a 1/8″ bit
4. Join the holes with a coping saw; finish the edges with a file

**Important:** Avoid rotary Dremel – the high-speed bit melts thick ABS and leaves an ugly edge.

## Phase 4: Final Assembly

### 1. Re-install logic board
- Re-install the MaxiProx logic board
- Re-solder the SMA pigtail to the reader's PCB ground pad

### 2. Mount components
- Mount the ESP RFID Tool and USB-PD trigger using 3 M VHB

### 3. Dress wiring
- Dress all wiring with zip-ties
- Keep power leads **far** from the antenna loop

### 4. Secure enclosure
- Tighten the enclosure screws until the battery is lightly compressed
- The internal friction prevents the pack from shifting when the device recoils after every card read

## Phase 5: Testing

### Range test
- Using a 125 kHz Pupa test card, verify consistent reads at ≈ 8 cm in free-air
- This should match mains-powered operation

### Shielding test
- Place the reader inside a thin-walled metal cash box
- Range should reduce to ≤ 2 cm, confirming metal enclosures act as RF shields

## Usage Workflow

1. Charge the USB-C battery, connect it, and flip the main power switch
2. (Optional) Open the beeper guard and enable audible feedback when bench-testing; lock it down before covert field use
3. Walk past the target badge holder – the MaxiProx will energise the card and the ESP RFID Tool captures the Wiegand stream
4. Dump captured credentials over Wi-Fi or USB-UART and replay/clone as required

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|------|
| Reader reboots when card presented | PD trigger negotiated 9 V not 12 V | Verify trigger jumpers / try higher-power USB-C cable |
| No read range | Battery or wiring sitting *on top* of the antenna | Re-route cables & keep 2 cm clearance around the ferrite loop |
| Beeper still chirps | Switch wired on positive lead instead of negative | Move kill-switch to break the **negative** speaker trace |

## References

- [Let's Clone a Cloner – Part 3 (TrustedSec)](https://trustedsec.com/blog/lets-clone-a-cloner-part-3-putting-it-all-together)
