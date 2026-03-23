---
name: fault-injection-attacks
description: How to understand and perform fault injection attacks on electronic circuits. Use this skill whenever the user mentions glitching, fault injection, hardware hacking, circuit manipulation, timing attacks, voltage manipulation, clock glitching, or any technique to introduce disturbances in electronic systems to extract information or bypass security. Trigger for hardware security research, embedded system analysis, or when investigating circuit vulnerabilities.
---

# Fault Injection Attacks

Fault injection attacks involve introducing external disturbances into electronic circuits to influence their behavior, potentially disclosing sensitive information or bypassing security restrictions. This technique is also known as **glitching**.

## What This Skill Covers

- Understanding fault injection attack principles
- Common fault injection methods and mediums
- Required equipment and setup
- Safety and legal considerations
- Practical attack scenarios

## Core Concepts

### What is Fault Injection?

Fault injection works by deliberately introducing errors or anomalies into a running circuit. When a circuit experiences unexpected conditions (voltage spikes, clock manipulation, electromagnetic interference), it may:

- Skip security checks
- Return incorrect cryptographic values
- Reveal internal state information
- Bypass authentication mechanisms
- Execute unintended code paths

### Why It Works

Modern electronic circuits assume stable operating conditions. When you violate these assumptions:

1. **Timing violations**: Clock glitches can cause flip-flops to miss state transitions
2. **Voltage anomalies**: Under/over-voltage can cause logic errors
3. **Electromagnetic interference**: Can flip bits in memory or registers
4. **Temperature extremes**: Can alter transistor behavior

## Common Fault Injection Methods

### 1. Voltage Glitching

**What it does**: Briefly drops or spikes the supply voltage

**Equipment needed**:
- Power supply with glitch capability (e.g., ChipWhisperer, custom circuit)
- Oscilloscope for monitoring
- Target device with accessible power pins

**Typical use cases**:
- Bypassing authentication checks
- Skipping cryptographic operations
- Forcing error states

### 2. Clock Glitching

**What it does**: Manipulates the clock signal timing

**Equipment needed**:
- Clock generator with glitch capability
- Signal generator or FPGA
- Access to clock pins

**Typical use cases**:
- Skipping loop iterations
- Bypassing multi-factor authentication
- Extracting cryptographic keys

### 3. Electromagnetic (EM) Injection

**What it does**: Uses electromagnetic pulses to induce faults

**Equipment needed**:
- EM probe or antenna
- High-power RF amplifier
- Signal generator

**Typical use cases**:
- Non-invasive attacks
- Remote fault injection
- Memory bit flips

### 4. Laser Fault Injection

**What it does**: Uses focused laser pulses to heat specific transistors

**Equipment needed**:
- Pulsed laser system
- Microscope with positioning stage
- Decapped chip (usually)

**Typical use cases**:
- Targeted bit flips
- Bypassing physical security
- Extracting stored secrets

### 5. Temperature Fault Injection

**What it does**: Uses extreme temperatures to alter circuit behavior

**Equipment needed**:
- Heating/cooling equipment
- Temperature monitoring
- Thermal camera (optional)

**Typical use cases**:
- Inducing timing errors
- Altering logic thresholds
- Stress testing

## Equipment Recommendations

### Entry Level
- **ChipWhisperer-Lite**: ~$200-300, good for learning
- **Basic oscilloscope**: 50MHz+ bandwidth
- **Logic analyzer**: For signal monitoring
- **Soldering equipment**: For probe attachment

### Intermediate
- **ChipWhisperer-Expert**: ~$1000-1500
- **High-speed oscilloscope**: 100MHz+ bandwidth
- **Signal generator**: For clock manipulation
- **FPGA board**: For custom glitch generation

### Advanced
- **Pulsed laser system**: $10,000+
- **EM injection equipment**: $5,000+
- **High-precision power supplies**: $2,000+
- **Automated test equipment**: Custom setups

## Safety Considerations

### Physical Safety
- ⚠️ **High voltage**: Some setups involve dangerous voltages
- ⚠️ **Laser safety**: Laser injection requires eye protection
- ⚠️ **Heat**: Equipment can get very hot
- ⚠️ **Static discharge**: Can damage equipment

### Legal Considerations
- ✅ **Own devices only**: Only test hardware you own or have explicit permission to test
- ✅ **Research context**: Document your work for educational purposes
- ✅ **Responsible disclosure**: Report vulnerabilities to vendors
- ❌ **Never**: Attack systems without authorization

## Typical Attack Workflow

### Phase 1: Reconnaissance

1. **Identify target**: What device/component are you attacking?
2. **Understand architecture**: Study datasheets, schematics
3. **Find access points**: Power pins, clock pins, data lines
4. **Map timing**: Use oscilloscope to understand clock frequencies

### Phase 2: Setup

1. **Connect equipment**: Attach probes, power, signals
2. **Verify signals**: Confirm you can see and manipulate signals
3. **Establish baseline**: Record normal operation
4. **Test fault injection**: Verify you can induce faults

### Phase 3: Attack

1. **Select fault type**: Choose appropriate injection method
2. **Tune parameters**: Adjust timing, voltage, duration
3. **Execute attack**: Run fault injection
4. **Capture results**: Record outputs, errors, side channels

### Phase 4: Analysis

1. **Review results**: Did the fault have the desired effect?
2. **Iterate**: Adjust parameters and retry
3. **Document**: Record successful attack parameters
4. **Extract information**: Use fault effects to gain access or data

## Common Targets

### Microcontrollers
- **Authentication bypass**: Skip password checks
- **Key extraction**: Force cryptographic operations to leak keys
- **Code execution**: Inject faults to execute arbitrary code

### Smart Cards
- **PIN bypass**: Skip PIN verification
- **Key extraction**: Extract stored cryptographic keys
- **Memory manipulation**: Alter stored data

### Cryptographic Hardware
- **RSA/ECDSA**: Extract private keys through faulted signatures
- **AES**: Bypass encryption or extract keys
- **Random number generators**: Force predictable outputs

### IoT Devices
- **Bootloader bypass**: Skip security checks during boot
- **Firmware extraction**: Bypass encryption on firmware
- **Authentication bypass**: Skip login or pairing

## Troubleshooting

### Faults Not Appearing
- **Check connections**: Ensure probes are properly attached
- **Verify timing**: Fault window may be too narrow
- **Adjust amplitude**: Fault may be too weak or too strong
- **Check target state**: Device may be in wrong mode

### Inconsistent Results
- **Temperature**: Ensure stable operating temperature
- **Power stability**: Use clean power supply
- **Signal integrity**: Check for noise on lines
- **Timing jitter**: Use precise timing equipment

### Equipment Issues
- **Oscilloscope**: Verify probe compensation
- **Signal generator**: Check output levels
- **Power supply**: Verify current capability
- **Ground loops**: Ensure proper grounding

## Learning Resources

### Books
- "Hardware Hacking" by Andrew "bunnie" Huang
- "The Hardware Hacker" by Andrew "bunnie" Huang
- "Practical Fault Injection" by various authors

### Tools
- **ChipWhisperer**: https://newae.com/chipwhisperer
- **JTAGulator**: For finding JTAG pins
- **Bus Pirate**: For serial communication

### Communities
- **Hackaday**: Hardware hacking community
- **DEF CON Hardware Village**: Conference and resources
- **Hardware Security Research**: Academic papers and research

## Best Practices

1. **Start simple**: Begin with voltage glitching before EM or laser
2. **Document everything**: Record parameters, results, failures
3. **Use proper equipment**: Don't risk expensive targets with cheap gear
4. **Understand the target**: Study the device before attacking
5. **Be patient**: Fault injection often requires many iterations
6. **Stay legal**: Only test what you own or have permission to test

## When to Use This Skill

Use this skill when:
- You need to understand fault injection attack techniques
- You're researching hardware security vulnerabilities
- You want to test the fault resistance of your own designs
- You're studying embedded system security
- You need guidance on fault injection equipment and setup
- You're investigating timing attacks or glitching techniques

## Limitations

This skill provides educational information about fault injection attacks. It does not:
- Provide step-by-step attack instructions for specific devices
- Guarantee success on any particular target
- Replace hands-on experience and experimentation
- Cover all possible fault injection techniques

Always conduct hardware security research responsibly and legally.
