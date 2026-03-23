---
name: flipper-zero-infrared
description: How to use Flipper Zero for infrared signal interception, capture, and transmission. Use this skill whenever the user mentions Flipper Zero IR, infrared remotes, capturing remote signals, universal remote mode, TV control, AC control, or any IR-related hardware hacking. Trigger even if they don't explicitly say "Flipper Zero" but describe IR signal capture or remote control hacking scenarios.
---

# Flipper Zero Infrared

A guide to using Flipper Zero's infrared capabilities for signal interception, learning, and transmission.

## What Flipper Zero IR Can Do

Flipper Zero's infrared module can:

1. **Capture IR signals** from any remote control (TV, AC, media center, etc.)
2. **Act as a universal remote** by bruteforcing known codes from its dictionary
3. **Replay captured signals** even if the protocol is unknown
4. **Intercept signals** between a remote and device (you don't need to point directly at the device)

## How It Works

### The Hardware

Flipper uses a **TSOP digital IR receiver** that's quite sensitive. Key points:

- You can **catch signals while standing between the remote and the target device**
- Direct line-of-sight to the Flipper's IR port is **not required**
- This is useful when someone is operating a remote near a TV while you're at a distance

### The Software

Decoding happens in software, which means:

- Flipper can potentially **receive and transmit any IR protocol**
- For **unknown protocols**, it records and replays the **raw signal exactly**
- No protocol recognition needed for basic capture/replay

## Actions

### 1. Learn a New Remote

**When to use:** You have physical access to a remote and want to capture its signals.

**How it works:**

1. Point the remote at Flipper Zero's IR port
2. Press the button you want to capture
3. Flipper attempts to **match the signal against its database**
4. If found: Flipper identifies the device and lets you interact with it
5. If not found: Flipper **stores the raw signal** for later replay

**Why this matters:** You don't need to know the protocol. Even if Flipper can't decode it, you can still replay the exact signal later.

### 2. Universal Remote Mode

**When to use:** You need to control a device but don't have its remote or haven't captured its signals.

**How it works:**

1. Enter Universal Remote mode
2. Press the desired button (e.g., Power)
3. Flipper **sequentially sends commands** from all known manufacturers in its SD card dictionary
4. When the target device recognizes a signal, it responds

**Important limitations:**

- **No feedback from the device** - you won't know which signal worked
- **Takes time** - larger dictionaries mean longer brute-force attempts
- **Blind operation** - you're sending signals until something responds

**Use case example:** Turning off a restaurant TV without knowing the brand. Press power in Universal Remote mode and wait for it to respond.

## Practical Tips

### Signal Capture Best Practices

- **Positioning:** You can stand between the remote and device - direct pointing isn't necessary
- **Distance:** The receiver is sensitive, but closer is more reliable
- **Timing:** Capture multiple button presses to build a complete remote profile

### Universal Remote Strategy

- **Start with common brands:** Sony, Samsung, Panasonic are usually tried first
- **Be patient:** Large dictionaries take time to cycle through
- **Watch for response:** Look for the device reacting (screen off, light blink, etc.)

### When to Use Each Mode

| Scenario | Recommended Mode |
|----------|------------------|
| You have the physical remote | Learn New Remote |
| Remote is lost/unavailable | Universal Remote |
| Unknown device/protocol | Learn New Remote (captures raw signal) |
| Quick one-off control | Universal Remote |

## Limitations to Know

1. **Smartphone IR ports:** Many phones (like Xiaomi) have IR transmitters but **cannot receive** signals. Flipper can do both.

2. **No feedback in Universal mode:** You won't know which signal worked, only that something did.

3. **Dictionary size matters:** Universal Remote speed depends on how many codes are in the SD card dictionary.

4. **Protocol support:** While Flipper can replay unknown protocols, some advanced features may require protocol-specific knowledge.

## References

- [Flipper Zero Infrared Blog](https://blog.flipperzero.one/infrared/)
- [Infrared Protocol Overview](../infrared.md)

## Common Use Cases

**TV Control:**
- Capture TV remote signals for later use
- Use Universal Remote to turn off TVs in public spaces
- Replay captured power/volume/channel signals

**Air Conditioner Control:**
- Learn AC remote codes (often complex protocols)
- Store multiple temperature/fan speed settings
- Replay without needing the original remote

**Media Center:**
- Capture streaming device remotes (Roku, Fire TV, etc.)
- Build a universal control solution
- Backup remote functionality

**Signal Analysis:**
- Intercept IR signals in the environment
- Study protocol behavior
- Document signal patterns for research
