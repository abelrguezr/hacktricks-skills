---
name: text-steganography-detection
description: Detect and decode hidden data in text using Unicode steganography techniques. Use this skill whenever you need to analyze suspicious text files, CTF challenges with hidden messages, or any text that might contain covert data through homoglyphs, zero-width characters, whitespace patterns, or CSS unicode-range encoding. Trigger this skill for any text forensics, CTF steganography challenges, or when text behaves unexpectedly.
---

# Text Steganography Detection

A skill for detecting and decoding hidden data embedded in text through Unicode manipulation and encoding techniques.

## When to use this skill

Use this skill when:
- Analyzing text files that might contain hidden messages
- Working on CTF challenges involving steganography
- Text appears normal but you suspect covert data
- You need to inspect Unicode codepoints for anomalies
- CSS files contain suspicious `unicode-range` declarations
- Text behaves unexpectedly (wrong rendering, invisible characters)

## Detection techniques

### 1. Unicode Homoglyphs

Different Unicode codepoints that render identically:
- Latin `a` (U+0061) vs Cyrillic `а` (U+0430)
- Latin `e` vs Cyrillic `е`
- Latin `o` vs Cyrillic `о`
- And many more character pairs

**Detection**: Inspect codepoints to find non-ASCII characters that look like ASCII.

### 2. Zero-Width Characters

Invisible characters used as covert channels:
- Zero-width space (U+200B)
- Zero-width non-joiner (U+200C)
- Zero-width joiner (U+200D)
- Word joiner (U+2060)

**Detection**: Look for invisible characters between visible text.

### 3. Whitespace Patterns

Encoding through whitespace variations:
- Spaces vs tabs
- Trailing spaces
- Line-length patterns
- Multiple consecutive spaces

**Detection**: Normalize whitespace carefully and compare patterns.

### 4. Bidirectional Control Characters

Characters that can visually reorder text:
- Left-to-right mark (U+200E)
- Right-to-left mark (U+200F)
- Bidirectional override characters

**Detection**: Check for unexpected text reordering or control characters.

### 5. CSS Unicode-Range Channels

`@font-face` rules can encode bytes in `unicode-range: U+..` entries.

**Detection**: Extract codepoints from CSS, concatenate hex values, decode as bytes.

## Workflow

### Step 1: Inspect Codepoints

Use the bundled script to examine all non-ASCII and whitespace characters:

```bash
python3 scripts/inspect_codepoints.py < suspicious_text.txt
```

Or pipe text directly:

```bash
cat file.txt | python3 scripts/inspect_codepoints.py
```

This outputs:
- Position index
- Hex codepoint value
- Character representation

Look for:
- Non-ASCII characters (ord > 127)
- Unexpected whitespace
- Zero-width characters
- Homoglyphs (Cyrillic, Greek, etc. that look like Latin)

### Step 2: Analyze Patterns

Based on codepoint inspection:

**If you find homoglyphs:**
- Map each character to its codepoint
- Look for patterns in the codepoint values
- Try converting to binary or extracting specific bits

**If you find zero-width characters:**
- Count occurrences between visible characters
- Map presence/absence to binary (1 = present, 0 = absent)
- Decode as binary data

**If you find whitespace patterns:**
- Compare space vs tab usage
- Check trailing spaces on each line
- Look for line-length variations

### Step 3: CSS Unicode-Range Extraction

For CSS files with suspicious `@font-face` rules:

```bash
python3 scripts/extract_css_ranges.py < styles.css
```

This extracts `unicode-range` values, concatenates the hex codepoints, and decodes as bytes.

### Step 4: Decode the Hidden Data

Common encoding schemes:

**Binary encoding:**
- Homoglyph presence = 1, absence = 0
- Zero-width character present = 1, absent = 0
- Space = 0, tab = 1

**Direct codepoint extraction:**
- Extract specific bits from codepoint values
- Convert codepoint sequences to ASCII

**Hex concatenation:**
- Concatenate hex values from unicode-range
- Decode as bytes with `xxd -r -p`

## Practical tips

1. **Preserve evidence**: Don't normalize text until you've inspected it. Normalization can destroy steganographic data.

2. **Compare with clean text**: If you have a "normal" version, diff the codepoints to find differences.

3. **Try multiple decodings**: Hidden data might use different bit positions or encoding schemes.

4. **Check for flags**: CTF challenges often hide flags like `flag{...}` or `CTF{...}`.

5. **Use online tools**: For complex homoglyph analysis, try the Unicode steganography playground at https://www.irongeek.com/i.php?page=security/unicode-steganography-homoglyph-encoder

## Example scenarios

### Scenario 1: Suspicious text file

**Input**: A text file that looks normal but you suspect hidden data

**Process**:
1. Run `inspect_codepoints.py` on the file
2. Look for non-ASCII characters or zero-width characters
3. Map patterns to binary or extract codepoint values
4. Decode to find hidden message

### Scenario 2: CSS file with @font-face rules

**Input**: A CSS file with suspicious unicode-range declarations

**Process**:
1. Run `extract_css_ranges.py` on the CSS file
2. The script extracts and decodes the unicode-range values
3. Output should be the hidden bytes

### Scenario 3: Text with invisible characters

**Input**: Text that seems to have extra spacing or rendering issues

**Process**:
1. Run `inspect_codepoints.py` to find zero-width characters
2. Map character positions to binary
3. Decode binary to ASCII

## References

- [Flagvent 2025 CTF Challenges](https://0xdf.gitlab.io/flagvent2025/medium)
- [Unicode Steganography Homoglyph Encoder](https://www.irongeek.com/i.php?page=security/unicode-steganography-homoglyph-encoder)
