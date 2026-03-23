---
name: crypto-ctf-esolangs
description: Use this skill whenever a CTF crypto challenge involves code that doesn't look like a standard programming language. This includes Brainfuck, Malbolge, Whitespace, Piet, and other esoteric languages. Trigger this skill when you see unusual syntax, strange characters, or code that appears to be a puzzle rather than normal programming. Also use when a challenge output needs decoding after running an esolang program.
---

# Crypto CTF: Esoteric Languages

This skill helps you solve crypto challenges where the actual task is to run an esoteric programming language (esolang) and decode its output.

## When to use this skill

Use this skill when:
- A challenge provides code with unusual syntax or strange characters
- The code doesn't look like any standard programming language
- You see tokens like `++++`, `[]`, `<>`, or other non-standard constructs
- A challenge mentions or hints at an esoteric language
- After running code, you get output that needs further decoding

## Technique

### Step 1: Identify the esolang

When you encounter unfamiliar code:

1. **Look for distinctive tokens** - Each esolang has characteristic syntax:
   - Brainfuck: `+ - < > . , [ ]`
   - Malbolge: `defghijklmnopqrstuvwxyz0123456789()[]{}*` with unusual operators
   - Whitespace: Only spaces, tabs, newlines
   - Piet: Image-based (you'll see a .png or .jpg)
   - Unary: Only one character repeated
   - Ook: `Ook. Ook? Ook! Ook.`
   - LOLCODE: `HAI`, `VISIBLE`, `KTHXBYE`

2. **Google distinctive tokens** - Copy 2-3 unique characters or patterns and search

3. **Check esolangs.org** - The main reference for esoteric languages

### Step 2: Run the program

Choose an execution method:

**Option A: Online interpreter (fastest)**
- Search "[language name] online interpreter"
- Paste the code and run
- Copy the output

**Option CTF: Docker image (for offline/air-gapped)**
- Many esolangs have Docker images
- Run: `docker run -i [image-name] < program.txt`

**Option C: Local installation**
- Install the interpreter if available
- Run locally for repeated testing

### Step 3: Decode the output

Esolang outputs are often encoded:

1. **Check for common encodings**:
   - Base64: `echo "output" | base64 -d`
   - Hex: `echo "output" | xxd -r -p`
   - ROT13: `echo "output" | tr 'A-Za-z' 'N-ZA-Mn-za-m'`
   - URL encoding: `echo "output" | python3 -c "import urllib.parse; print(urllib.parse.unquote(input()))"`

2. **Check for compression**:
   - gzip: `gunzip -c file.gz`
   - zlib: `python3 -c "import zlib; print(zlib.decompress(open('file','rb').read()))"`
   - bzip2: `bunzip2 -c file.bz2`

3. **Look for layered encoding** - Decode, then check if the result is still encoded

## Common esolangs in CTFs

| Language | Key Tokens | Typical Output |
|----------|-----------|----------------|
| Brainfuck | `+ - < > . , [ ]` | ASCII characters |
| Malbolge | `defghijklmnopqrstuvwxyz0123456789()[]{}*` | Often encoded |
| Whitespace | Spaces/tabs/newlines only | ASCII characters |
| Piet | Image file | ASCII characters |
| Ook | `Ook. Ook? Ook! Ook.` | ASCII characters |
| LOLCODE | `HAI`, `VISIBLE`, `KTHXBYE` | ASCII characters |
| Unary | Single character repeated | Numbers |

## Resources

- **esolangs.org** - https://esolangs.org/wiki/Main_Page
- **Esolang Sandbox** - https://esolangs.org/wiki/Sandbox
- **CTF Esolang Collection** - Various GitHub repos with CTF esolang challenges

## Example workflow

**Challenge**: You receive a file with `++++[>++<-]>.`

1. **Identify**: The `+ - < > [ ]` pattern indicates Brainfuck
2. **Run**: Use an online Brainfuck interpreter or `docker run -i brainfuck < file.bf`
3. **Output**: Gets `BB` (two B characters)
4. **Decode**: Check if `BB` is encoded - might be base64, hex, or the final flag

## Tips

- **Save the code** - Keep the original esolang code for reference
- **Document the language** - Note which esolang you identified
- **Try multiple decodings** - If the first decode doesn't work, try others
- **Check for flags** - Look for `flag{`, `CTF{`, or similar patterns in output
- **Layered encoding is common** - Be prepared to decode multiple times

## When this skill might not apply

- Standard programming languages (Python, C, JavaScript, etc.)
- Simple encoding challenges without esolang execution
- Pure cryptography without code execution

If you're unsure whether something is an esolang, use this skill anyway - the identification step will help clarify.
