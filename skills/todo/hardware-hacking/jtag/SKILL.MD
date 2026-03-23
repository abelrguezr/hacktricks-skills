---
name: jtag-debug
description: How to perform JTAG debugging, pinout enumeration, and memory dumping on embedded devices. Use this skill whenever the user mentions JTAG, hardware debugging, embedded device analysis, TAP controllers, OpenOCD, boundary scan, or wants to extract firmware/memory from microcontrollers. Also trigger for SWD debugging, ESP32 debugging, STM32 debugging, RISC-V debugging, or any embedded hardware reverse engineering task. Make sure to use this skill for any hardware hacking involving debug interfaces, even if the user doesn't explicitly say "JTAG".
---

# JTAG Debugging and Hardware Analysis

This skill guides you through JTAG debugging, pinout enumeration, and memory extraction from embedded devices.

## Quick Start

1. **Identify your adapter** (J-Link, ST-LINK, FT2232H, ESP32-S3 USB-JTAG, etc.)
2. **Connect safely** (GND, Vtref, TCK, TMS, TDI, TDO minimum)
3. **Scan the chain** with OpenOCD to verify connection
4. **Halt and dump** memory/flash as needed

---

## JTAGenum: Brute-Force Pinout Discovery

Use JTAGenum when you have unknown JTAG pads and need to find the correct pinout.

### Hardware Setup

**Arduino-compatible MCU:**
- Connect digital pins D2–D11 to up to 10 suspected JTAG pads
- Connect Arduino GND to target GND (always share ground)
- Power the target separately unless you know the rail is safe
- Prefer 3.3V logic (Arduino Due) or use level shifter/series resistors for 1.8–3.3V targets

**Raspberry Pi:**
- Fewer usable GPIOs available (slower scans)
- Check the JTAGenum repo for current pin map and constraints

### Operation

Once flashed, open serial monitor at 115200 baud:

| Command | Action |
|---------|--------|
| `h` | Show help |
| `l` | Find loopbacks (avoid false positives) |
| `r` | Toggle internal pull-ups if needed |
| `s` | Scan for TCK/TMS/TDI/TDO (and TRST/SRST) |
| `y` | Brute-force IR to discover undocumented opcodes |
| `x` | Boundary-scan snapshot of pin states |

When a valid TAP is found, you'll see lines starting with `FOUND!` indicating discovered pins.

### Safety Tips

- **Always share ground** between probe and target
- **Never drive unknown pins above target Vtref**
- If in doubt, add 100–470Ω series resistors on candidate pins
- If the device uses SWD/SWJ instead of 4-wire JTAG, JTAGenum may not detect it; try SWD tools or an adapter that supports SWJ-DP

---

## Hardware Setup Best Practices

### Identify Power First

1. Use a multimeter to identify Vtref and GND before connecting anything
2. Many adapters need Vtref to set I/O voltage correctly
3. Never assume pin voltages—measure first

### Level Shifting

- Prefer bidirectional level shifters designed for push-pull signals
- JTAG lines are **not** open-drain—avoid auto-direction I2C shifters
- Common adapters: FT2232H/FT232H boards (Tigard), CMSIS-DAP, J-Link, ST-LINK, ESP-USB-JTAG

### Minimum Connections

Connect at minimum: TCK, TMS, TDI, TDO, GND, and Vtref

Optional: TRST (test reset) and SRST (system reset)

---

## OpenOCD: Scan and Identify

OpenOCD is the de-facto open-source tool for JTAG/SWD debugging.

### Generic Scan (J-Link example)

```bash
openocd -f interface/jlink.cfg \
  -c "transport select jtag; adapter speed 1000" \
  -c "init; scan_chain; shutdown"
```

### ESP32-S3 Built-in USB-JTAG

No external probe required:

```bash
openocd -f board/esp32s3-builtin.cfg \
  -c "init; scan_chain; shutdown"
```

### Troubleshooting

If you get "all ones/zeros" IDCODE:
- Check wiring and connections
- Verify power and Vtref are correct
- Ensure the port isn't locked by fuses/option bytes
- Try lower adapter speeds (100kHz or less)

For manual TAP interaction on unknown chains, use OpenOCD's low-level `irscan`/`drscan` commands.

---

## Halting CPU and Dumping Memory

Once the TAP is recognized and a target script is chosen, you can halt the core and dump memory regions.

### Generic Target (STM32 example)

```bash
openocd -f interface/jlink.cfg -f target/stm32f1x.cfg \
  -c "init; reset halt; mdw 0x08000000 4; dump_image flash.bin 0x08000000 0x00100000; shutdown"
```

### RISC-V SoC (prefer SBA when available)

```bash
openocd -f interface/ftdi/ft232h.cfg -f target/riscv.cfg \
  -c "init; riscv set_prefer_sba on; halt; dump_image sram.bin 0x80000000 0x20000; shutdown"
```

### ESP32-S3 Program/Read

```bash
openocd -f board/esp32s3-builtin.cfg \
  -c "program_esp app.bin 0x10000 verify exit"
```

### Tips

- Use `mdw`/`mdh`/`mdb` (memory dump word/half/byte) to sanity-check memory before long dumps
- For multi-device chains, set BYPASS on non-targets or use a board file that defines all TAPs
- Adjust base addresses and sizes for your specific target

---

## Boundary-Scan Tricks

Even when CPU debug access is locked, boundary-scan may still be exposed.

### What You Can Do

- **SAMPLE**: Snapshot pin states while the system runs (find bus activity, confirm pin mapping)
- **EXTEST**: Drive pins (e.g., bit-bang external SPI flash lines via the MCU to read it offline if board wiring allows)

### Minimal UrJTAG Flow (FT2232x adapter)

```bash
jtag> cable ft2232 vid=0x0403 pid=0x6010 interface=1
jtag> frequency 100000
jtag> detect
jtag> bsdl path /path/to/bsdl/files
jtag> instruction EXTEST
jtag> shift ir
jtag> dr  <bit pattern for boundary register>
```

You need the device BSDL file to know boundary register bit ordering. Beware that some vendors lock boundary-scan cells in production.

---

## Modern Target Notes

### ESP32-S3/C3

Include a native USB-JTAG bridge; OpenOCD can speak directly over USB without an external probe. Very convenient for triage and dumps.

### RISC-V Debug (v0.13+)

Widely supported by OpenOCD; prefer SBA (System Bus Access) for memory access when the core cannot be halted safely.

### Debug Authentication

Many MCUs implement debug authentication and lifecycle states. If JTAG appears dead but power is correct, the device may be:
- Fused to a closed state
- Require an authenticated probe
- In a restricted lifecycle state

---

## Defenses and Hardening

What to expect on production devices:

- **Permanently disable or lock JTAG/SWD** (e.g., STM32 RDP level 2, ESP eFuses that disable PAD JTAG, NXP/Nordic APPROTECT/DPAP)
- **Require authenticated debug** (ARMv8.2-A ADIv6 Debug Authentication, OEM-managed challenge-response) while keeping manufacturing access
- **Don't route easy test pads**: bury test vias, remove/populate resistors to isolate TAP, use connectors with keying or pogo-pin fixtures
- **Power-on debug lock**: gate the TAP behind early ROM enforcing secure boot

---

## References

- [OpenOCD User's Guide – JTAG Commands](https://openocd.org/doc-release/html/JTAG-Commands.html)
- [Espressif ESP32-S3 JTAG debugging](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-guides/jtag-debugging/)
- [JTAGenum GitHub](https://github.com/cyphunk/JTAGenum)
