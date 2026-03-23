---
name: side-channel-analysis
description: Guide for performing side-channel analysis (SCA) attacks to recover cryptographic secrets through physical leakage. Use this skill whenever the user mentions power analysis, electromagnetic attacks, timing attacks, fault injection, hardware hacking, smart card attacks, or any scenario involving extracting secrets from physical device behavior. Also trigger for questions about ChipWhisperer, DPA/CPA, Hertzbleed, or any micro-architectural attack on CPUs.
---

# Side Channel Analysis Attacks

Side-channel attacks recover secrets by observing physical or micro-architectural "leakage" that is correlated with internal state but is not part of the logical interface of the device.

## When to Use This Skill

Use this skill when:
- Analyzing smart cards, IoT devices, or embedded systems for vulnerabilities
- Investigating power consumption, electromagnetic emissions, or timing variations
- Performing fault injection attacks or differential fault analysis
- Setting up hardware hacking tools (ChipWhisperer, oscilloscopes, probes)
- Understanding or defending against micro-architectural attacks (Hertzbleed, Spectre variants)
- Working with cryptographic implementations that may leak through side channels

## Main Leakage Channels

| Channel | Typical Target | Instrumentation |
|---------|---------------|------------------|
| Power consumption | Smart-cards, IoT MCUs, FPGAs | Oscilloscope + shunt resistor/HS probe (e.g. CW503) |
| Electromagnetic field (EM) | CPUs, RFID, AES accelerators | H-field probe + LNA, ChipWhisperer/RTL-SDR |
| Execution time / caches | Desktop & cloud CPUs | High-precision timers (rdtsc/rdtscp), remote time-of-flight |
| Acoustic / mechanical | Keyboards, 3-D printers, relays | MEMS microphone, laser vibrometer |
| Optical & thermal | LEDs, laser printers, DRAM | Photodiode / high-speed camera, IR camera |
| Fault-induced | ASIC/MCU cryptos | Clock/voltage glitch, EMFI, laser injection |

## Power Analysis Attacks

### Simple Power Analysis (SPA)

Observe a single trace and directly associate peaks/valleys with operations (e.g. DES S-boxes, AES round operations).

**Setup:**
1. Connect oscilloscope or ChipWhisperer to VCC pin with shunt resistor
2. Trigger on known pattern (GPIO toggle, specific plaintext)
3. Capture trace at appropriate sampling rate (≥10 MS/s for MCUs)

**Example with ChipWhisperer:**
```python
from chipwhisperer.capture.api.programmers import STMLink
from chipwhisperer.capture import CWSession

cw = CWSession(project='aes')
cw.connect(cw.capture.scopes[0])
cw.capture.init()
trace = cw.capture.capture_trace()
print(trace.wave)  # numpy array of power samples
```

### Differential/Correlation Power Analysis (DPA/CPA)

Acquire N > 1000 traces, hypothesize key byte k, compute Hamming Weight/Distance model and correlate with leakage.

**Workflow:**
1. Collect 1000-10000 traces with varying plaintexts
2. For each key byte hypothesis (0-255):
   - Compute intermediate value (e.g., S-box output)
   - Calculate Hamming Weight of intermediate
   - Correlate with actual power trace at target sample
3. Highest correlation indicates correct key byte

**Use the `scripts/cpa_correlation.py` script for automated CPA analysis.**

## Electromagnetic Analysis (EMA)

Near-field EM probes (500 MHz–3 GHz) leak identical information to power analysis without inserting shunts.

**Key points:**
- Works at distances >10 cm with RTL-SDR front-ends (2024 research)
- No physical contact required
- Use H-field probe + low-noise amplifier
- Spectrum correlation can recover keys from STM32 at range

## Timing & Micro-architectural Attacks

Modern CPUs leak secrets through shared resources:

| Attack | Year | Mechanism |
|--------|------|----------|
| Hertzbleed | 2022 | DVFS frequency scaling correlates with Hamming weight, remote EdDSA key extraction |
| Downfall / Gather Data Sampling | 2023 | Intel transient-execution reads AVX-gather data across SMT threads |
| Zenbleed | 2023 | AMD speculative vector mis-prediction leaks registers cross-domain |
| Inception | 2023 | AMD speculative execution variant |

**Defense:** Disable DVFS/turbo in crypto kernels, isolate SMT, prohibit co-location in multi-tenant clouds.

## Acoustic & Optical Attacks

- **iLeakKeys (2024):** 95% accuracy recovering laptop keystrokes from smartphone microphone over Zoom using CNN classifier
- **LED side-channel:** High-speed photodiodes capture DDR4 activity LED and reconstruct AES round keys within <1 minute (BlackHat 2023)

## Fault Injection & Differential Fault Analysis (DFA)

Combining faults with side-channel leakage shortcuts key search (e.g. 1-trace AES DFA).

**Hobbyist tools:**
- **ChipSHOUTER & PicoEMP** – sub-1 ns electromagnetic pulse glitching
- **GlitchKit-R5 (2025)** – open-source clock/voltage glitch platform for RISC-V SoCs

## Typical Attack Workflow

Follow this sequence for systematic side-channel attacks:

1. **Identify leakage channel & mount point**
   - VCC pin, decoupling capacitor, near-field spot
   - Consider access constraints (physical vs remote)

2. **Insert trigger**
   - GPIO toggle or pattern-based synchronization
   - Ensure consistent alignment across traces

3. **Collect traces**
   - Acquire >1000 traces with proper sampling/filters
   - Use varying inputs (plaintexts, keys) for statistical attacks

4. **Pre-process**
   - Alignment (cross-correlation or trigger-based)
   - Mean removal
   - Low-pass/high-pass filtering
   - Wavelet transform or PCA for dimensionality reduction

5. **Statistical or ML key recovery**
   - CPA for classical attacks
   - Machine Learning (MLA, deep-learning SCA) for complex scenarios
   - Use `scripts/cpa_correlation.py` or `scaaml` library

6. **Validate and iterate**
   - Test recovered key on known plaintext/ciphertext
   - Analyze outliers and refine attack parameters

## Defences & Hardening

When evaluating or implementing defenses:

| Category | Techniques |
|----------|------------|
| **Constant-time** | Implementations & memory-hard algorithms |
| **Masking/shuffling** | Split secrets into random shares; first-order resistance certified by TVLA |
| **Hiding** | On-chip voltage regulators, randomised clock, dual-rail logic, EM shields |
| **Fault detection** | Redundant computation, threshold signatures |
| **Operational** | Disable DVFS/turbo in crypto kernels, isolate SMT, prohibit co-location in multi-tenant clouds |

## Tools & Frameworks

| Tool | Purpose | Notes |
|------|---------|-------|
| **ChipWhisperer-Husky** | 500 MS/s scope + Cortex-M trigger | Python API, 2024 version |
| **Riscure Inspector & FI** | Commercial automated leakage assessment | TVLA-2.0 support |
| **scaaml** | TensorFlow-based deep-learning SCA | v1.2 (2025) |
| **pyecsca** | ANSSI open-source ECC SCA framework | Python-based |

## Quick Start Scripts

Use the bundled scripts for common tasks:

- `scripts/cpa_correlation.py` - Automated CPA key recovery
- `scripts/trace_analysis.py` - Basic trace visualization and preprocessing

## References

- [ChipWhisperer Documentation](https://chipwhisperer.readthedocs.io/en/latest/)
- [Hertzbleed Attack Paper](https://www.hertzbleed.com/)
- ASCAD-v2 Competition (2023) - State-of-the-art SCA benchmarks

## Common Pitfalls

- **Insufficient traces:** DPA/CPA typically needs 1000+ traces for reliable results
- **Poor alignment:** Traces must be synchronized to the same operation
- **Wrong sampling rate:** Too slow misses leakage, too fast adds noise
- **Ignoring noise:** Always apply appropriate filtering before analysis
- **Single-point attacks:** Test multiple key bytes and validate results
