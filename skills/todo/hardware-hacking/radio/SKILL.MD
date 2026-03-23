---
name: radio-signal-analysis
description: Analyze radio signals using SigDigger to identify modulation types (AM/FM/PM), extract symbol rates, and decode bits from captured IQ data. Use this skill whenever the user mentions radio signals, SDR, signal analysis, modulation detection, IQ data, SigDigger, or wants to decode unknown radio transmissions. Also trigger for any request involving signal capture, demodulation, or extracting information from radio frequencies.
---

# Radio Signal Analysis with SigDigger

This skill guides you through analyzing unknown radio signals using SigDigger, a digital signal analyzer for GNU/Linux and macOS.

## When to Use This Skill

Use this skill when:
- You have captured radio signal data (IQ files) and need to analyze it
- You need to identify the modulation type of an unknown signal
- You want to extract bits or data from a radio transmission
- You're working with SDR (Software Defined Radio) devices
- You need to decode FSK, PSK, ASK, AM, FM, or PM signals
- You have a `.raw` IQ file from a capture and need to understand what's in it

## Quick Start

1. **Open SigDigger** and load your signal file or connect to your SDR device
2. **Configure settings** (see Configuration section below)
3. **Identify the modulation type** using the methods in this guide
4. **Extract the symbol rate** from the signal
5. **Sample and decode the bits**

## Configuration

### Basic Setup

In SigDigger's Settings tab:
- **SDR Device**: Select your hardware or choose "File" to load a capture
- **Frequency**: Set to the frequency you want to analyze
- **Sample Rate**: Use up to 2.56 Msps if your PC supports it

### GUI Behavior Settings

Enable these options if your PC can handle them:
- OpenGL rendering (disable if you experience capture issues)
- Real-time processing options

> **Troubleshooting**: If your PC isn't capturing properly, disable OpenGL and lower the sample rate.

### Tuner Settings

The Tuner can improve or degrade signal quality:
- Start with tuner at 0
- Gradually increase until noise becomes worse than signal improvement
- For voice channels: set tuner to the level just before noise increases significantly

## Signal Analysis Workflow

### Step 1: Capture the Signal

- Hold "Push to capture" to record a time window of the signal
- For bursty signals, capture long enough to get multiple frames
- The first part of bursts is usually a preamble (errors here are normal)

### Step 2: Identify Modulation Type

Use multiple methods to determine if the signal is AM, FM, or PM:

#### Method A: IQ Graph Analysis

The IQ graph shows amplitude (distance from center) and phase (angle):

- **AM Detection**: Look for 2+ distinct circles at different distances from center
  - Distance from 0,0 = amplitude
  - Multiple circles = multiple amplitude levels = AM
  - Example: One circle at 0, another at different amplitude

- **PM Detection**: Look for small, unrelated circles at different angles
  - Angle from 0,0 = phase
  - Multiple distinct angles = phase modulation
  - Note: If phase changes encode data (not absolute phase), circles may not be clearly separated

- **FM Detection**: Look for essentially one circle with speed variations
  - IQ doesn't directly show frequency
  - Frequency changes appear as acceleration/speed changes around the circle
  - Watch for direction changes or speed variations in the circular pattern

#### Method B: Histogram Analysis

Select the signal portion containing information:

- **Amplitude Histogram**: 
  - 2+ clear levels = likely AM
  - 1 level = not AM (or signal degradation)

- **Frequency Histogram**:
  - 2+ clear frequencies = likely FM
  - 1 frequency = not FM (or channel effects)
  - Many frequencies = probably not FM (likely channel modification)

- **Phase Histogram**:
  - Multiple distinct phases = PM
  - Single phase distribution = not PM

#### Method C: Waveform Inspection

- **AM**: Clear amplitude variations visible in waveform
- **FM**: May not show clear frequency differences in waveform (especially if capture frequency is between the two signal frequencies)
- **PM**: Phase changes may not be obvious in waveform

### Step 3: Determine Symbol Rate

#### Method A: Single Symbol

1. Select the smallest complete symbol you can identify
2. Check "Selection freq" in SigDigger
3. This is your symbol rate (e.g., 1.013 kHz ≈ 1 kHz)

#### Method B: Multiple Symbols (More Accurate)

1. Select a group of symbols (e.g., 10 symbols)
2. SigDigger calculates the average symbol frequency
3. More symbols = better accuracy

### Step 4: Extract Bits

Once you know the modulation type and symbol rate:

1. **Select the signal** containing information
2. **Configure sampling**:
   - Mode: Amplitude (for AM) or Frequency (for FM)
   - Symbol rate: Use the rate you discovered
   - Clock recovery: Gardner clock recovery (usually best)

3. **Clock Recovery Options**:
   - **Sync to selection intervals**: Uses symbol rate from your previous selection
   - **Manual**: Uses the symbol rate you specify
   - **Fixed interval selection**: You specify number of intervals, it calculates rate
   - **Gardner clock recovery**: Best option, but still needs approximate symbol rate

4. **Press Sample** to extract the signal levels

5. **Set the decision range**:
   - Click and drag from the lowest level to the highest level
   - For 2-level signals: drag from low to high
   - For 4-level signals: set "Bits per symbol" to 2, drag from smallest to largest

6. **Adjust display**:
   - Increase Zoom to see individual bits
   - Change Row size for better readability
   - Select all and copy to get the bit sequence

### Step 5: Post-Processing

#### Multi-bit Symbols

If the signal has more than 1 bit per symbol:
- SigDigger uses grayscale to represent different symbols
- Copied bits will be numbers (0-3 for 2 bits/symbol)
- You'll need to map these to actual bit patterns

#### Manchester Encoding

Many radio signals use Manchester encoding:
- Up+down (10 or 01) = one value (0 or 1)
- Down+up (01 or 10) = the other value
- Process pairs of bits to decode
- Note: Preamble may have consecutive 1s or 0s even in Manchester-encoded signals

#### Frame Alignment

- Look for well-aligned frames in the bit sequence
- Preamble errors are normal (first part of burst)
- Data frames should show consistent patterns

## Common Scenarios

### Scenario 1: Unknown Signal Analysis

1. Load the IQ file in SigDigger
2. Check IQ graph for modulation hints
3. Run amplitude, frequency, and phase histograms
4. Identify modulation type from the patterns
5. Extract symbol rate
6. Sample and decode bits
7. Apply any necessary post-processing (Manchester, etc.)

### Scenario 2: Voice Channel Analysis

1. Synchronize to the channel frequency
2. Configure "Baseband audio preview"
3. Set bandwidth to capture all transmitted information
4. Adjust tuner to just before noise increases
5. Listen to the demodulated audio

### Scenario 3: Bursty Signal Analysis

1. Capture a longer window to get multiple bursts
2. Expect preamble errors in the first part of each burst
3. Look for aligned frames across multiple bursts
4. Use multiple bursts to verify your decoding

## Tips and Tricks

- **Preamble handling**: Don't worry about errors in the first part of bursts - this is usually preamble
- **Frame alignment**: Good signals show well-aligned frames between bursts
- **Signal degradation**: Multiple amplitudes in an FM signal might indicate channel degradation, not AM
- **Tuner optimization**: Start at 0 and increase gradually - there's an optimal point before noise dominates
- **Sample rate**: Higher sample rates (up to 2.56 Msps) give better resolution if your PC can handle it
- **Clock recovery**: Gardner is usually best, but you still need to provide an approximate symbol rate

## Troubleshooting

| Problem | Solution |
|---------|----------|
| PC not capturing | Disable OpenGL, lower sample rate |
| Can't identify modulation | Use multiple methods (IQ + histograms + waveform) |
| Bits look wrong | Check symbol rate, verify modulation type, try different clock recovery |
| Too much noise | Adjust tuner, check bandwidth settings |
| Can't see clear levels | Increase zoom, adjust decision range |
| Manchester decoding issues | Remember preamble may have consecutive bits |

## File Formats

SigDigger works with:
- `.raw` IQ files (float32 format common)
- Live SDR captures via SoapySDR
- Various SDR devices (RTL-SDR, HackRF, etc.)

## Next Steps

After extracting bits:
- Look for known protocols (LoRa, 433 MHz devices, etc.)
- Check for common encodings (Manchester, NRZ, etc.)
- Search for frame markers or sync bytes
- Consider using specialized decoders for known protocols

## References

- [SigDigger GitHub](https://github.com/BatchDrake/SigDigger)
- SoapySDR documentation for device support
- Radio protocol documentation for specific devices
