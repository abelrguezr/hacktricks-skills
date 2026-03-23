---
name: macos-serial-number-decoder
description: Decode and analyze Apple device serial numbers to extract manufacturing location, date, and model information. Use this skill whenever you need to parse Apple serial numbers, investigate device origins, analyze hardware for security assessments, or understand when/where a Mac was manufactured. Trigger this for any 12-character alphanumeric Apple serial number analysis, device forensics, or hardware investigation tasks.
---

# macOS Serial Number Decoder

Decode Apple device serial numbers to extract manufacturing information, dates, and model details.

## Quick Start

When given a serial number, follow this process:

1. **Validate** the serial number format (12 alphanumeric characters for post-2010 devices)
2. **Parse** each segment according to the structure below
3. **Decode** the manufacturing location, date, and model
4. **Report** findings in a clear summary

## Serial Number Structure

Apple devices post-2010 use 12-character serial numbers:

```
[1-3] [4-5] [6-8] [9-12]
  │      │      │      │
  │      │      │      └─ Model number
  │      │      └─ Unique identifier
  │      └─ Year & week of manufacture
  └─ Manufacturing location
```

### Example: `C02L13ECF8J2`

| Segment | Characters | Value | Meaning |
|---------|------------|-------|----------|
| Location | 1-3 | `C02` | China (specific city) |
| Year/Week | 4-5 | `L1` | 2014, Week 1 |
| Unique ID | 6-8 | `3EC` | Device identifier |
| Model | 9-12 | `F8J2` | Model number |

## Manufacturing Location Codes

Decode the first 3 characters to identify the factory:

### United States
- `FC`, `F`, `XA`, `XB`, `QP`, `G8`

### International Locations
- `RN` - Mexico
- `CK` - Cork, Ireland
- `VM` - Foxconn, Czech Republic
- `SG`, `E` - Singapore
- `MB` - Malaysia
- `PT`, `CY` - Korea
- `EE`, `QT`, `UV` - Taiwan

### China (Multiple Locations)
- `FK`, `F1`, `F2`, `W8`, `DL`, `DM`, `DN`, `YM`, `7J`, `1C`, `4H`, `WQ`, `F7`
- `C0`, `C3`, `C7` - Specific cities

### Special
- `RM` - Refurbished device

## Manufacturing Date Decoding

### Year (4th Character)

| Character | Period |
|-----------|--------|
| `C` | First half 2010 |
| `D` | Second half 2010 |
| `E` | First half 2011 |
| `F` | Second half 2011 |
| `G` | First half 2012 |
| `H` | Second half 2012 |
| `J` | First half 2013 |
| `K` | Second half 2013 |
| `L` | First half 2014 |
| `M` | Second half 2014 |
| `N` | First half 2015 |
| `P` | Second half 2015 |
| `Q` | First half 2016 |
| `R` | Second half 2016 |
| `S` | First half 2017 |
| `T` | Second half 2017 |
| `V` | First half 2018 |
| `W` | Second half 2018 |
| `X` | First half 2019 |
| `Y` | Second half 2019 |
| `Z` | 2020+ |

### Week (5th Character)

| Character | Week Number |
|-----------|-------------|
| `1-9` | Weeks 1-9 |
| `C` | Week 10 |
| `D` | Week 11 |
| `F` | Week 12 |
| `G` | Week 13 |
| `H` | Week 14 |
| `J` | Week 15 |
| `K` | Week 16 |
| `L` | Week 17 |
| `M` | Week 18 |
| `N` | Week 19 |
| `P` | Week 20 |
| `Q` | Week 21 |
| `R` | Week 22 |
| `T` | Week 23 |
| `U` | Week 24 |
| `V` | Week 25 |
| `W` | Week 26 |
| `X` | Week 27 |
| `Y` | Week 28 |

**Important**: For second half of the year (characters D, F, H, K, M, P, R, T, V, X, Z), add 26 to the week number.

## Output Format

Always present decoded information in this structure:

```
## Serial Number Analysis

**Serial Number**: [FULL SERIAL]

### Manufacturing Details
- **Location**: [CODE] - [COUNTRY/FACTORY]
- **Year**: [YEAR]
- **Week**: [WEEK NUMBER]
- **Estimated Date**: [APPROXIMATE DATE]

### Device Information
- **Unique ID**: [ID]
- **Model Code**: [MODEL]
- **Refurbished**: [YES/NO]

### Notes
[Any relevant observations about the device origin or age]
```

## Examples

### Example 1: Standard Decode

**Input**: `C02L13ECF8J2`

**Output**:
```
## Serial Number Analysis

**Serial Number**: C02L13ECF8J2

### Manufacturing Details
- **Location**: C02 - China (specific city)
- **Year**: 2014 (First half)
- **Week**: 1
- **Estimated Date**: January 2014

### Device Information
- **Unique ID**: 3EC
- **Model Code**: F8J2
- **Refurbished**: No

### Notes
Device manufactured in China during early 2014.
```

### Example 2: Refurbished Device

**Input**: `RM1K25ABC123`

**Output**:
```
## Serial Number Analysis

**Serial Number**: RM1K25ABC123

### Manufacturing Details
- **Location**: RM - Refurbished device
- **Year**: 2013 (Second half)
- **Week**: 27 (25 + 26 = 51, adjusted to week 27 of second half)
- **Estimated Date**: December 2013

### Device Information
- **Unique ID**: ABC
- **Model Code**: 123
- **Refurbished**: Yes

### Notes
This is a refurbished device. Original manufacturing date may differ from refurbishment date.
```

## Common Use Cases

- **Security Assessments**: Determine device age and origin for penetration testing
- **Forensics**: Establish device timeline and manufacturing provenance
- **Asset Management**: Track device lifecycle and warranty periods
- **Red Teaming**: Understand target hardware for macOS exploitation planning

## Validation Checklist

Before reporting results, verify:
- [ ] Serial number is exactly 12 characters
- [ ] All characters are alphanumeric
- [ ] Year character is valid (C-Z range)
- [ ] Week character is valid (1-9 or C-Y excluding vowels and S)
- [ ] Location code matches known patterns
