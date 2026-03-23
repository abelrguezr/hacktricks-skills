---
name: android-apk-ca-trust
description: How to modify Android APKs to accept user-installed CA certificates for traffic interception. Use this skill whenever the user mentions APK modification, certificate pinning bypass, SSL pinning, Android app security testing, intercepting mobile app traffic, decompiling Android apps, or needs to inspect HTTPS traffic from Android applications. This is essential for mobile pentesting when apps reject user certificates.
---

# Android APK CA Certificate Trust

This skill helps you modify Android APKs to accept user-installed CA certificates, enabling traffic interception for security testing.

## When to Use This

Use this approach when:
- An Android app rejects your proxy's CA certificate
- You need to inspect HTTPS traffic from a mobile app
- Certificate pinning is blocking your proxy
- You're doing mobile application security testing

## Prerequisites

Before starting, ensure you have:
- `apktool` installed (`apktool --version`)
- `keytool` (comes with Java JDK)
- The target APK file
- A proxy tool (Burp Suite, mitmproxy, etc.) with a CA certificate

## Approach Selection

### Automatic Method (Recommended First)

The [apk-mitm](https://github.com/shroudedcode/apk-mitm) tool automates the entire process:

```bash
apk-mitm -i input.apk -o output.apk
```

This will:
- Automatically modify the APK to trust user certificates
- Disable certificate pinning if present
- Rebuild and sign the APK

**Use this first** - it's faster and handles edge cases automatically.

### Manual Method

Use the manual method when:
- apk-mitm fails or isn't available
- You need fine-grained control over modifications
- You're learning the underlying mechanics

## Manual Modification Process

### Step 1: Decompile the APK

```bash
apktool d app-name.apk -o app-decompiled
```

This creates a folder with the app's resources and Smali code.

### Step 2: Modify AndroidManifest.xml

Navigate to `app-decompiled/AndroidManifest.xml` and find the `<application>` tag.

Add the `android:networkSecurityConfig` attribute:

```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    android:name="..."
    ...>
```

**Important**: If the attribute already exists, don't add it again - just note the value.

### Step 3: Create Network Security Config

Create the file `app-decompiled/res/xml/network_security_config.xml` with this content:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <!-- Trust preinstalled CAs -->
            <certificates src="system" />
            <!-- Additionally trust user added CAs -->
            <certificates src="user" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

**Key points**:
- `src="system"` - Trusts pre-installed system CAs
- `src="user"` - Trusts user-installed CAs (this is what we need)
- Keep `cleartextTrafficPermitted="false"` for security

### Step 4: Rebuild the APK

```bash
apktool b app-decompiled -o app-modified.apk
```

### Step 5: Sign the APK

Android requires all APKs to be signed. Use this command:

```bash
keytool -genkey -v -keystore my-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias my-alias
```

Then sign:

```bash
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore my-release-key.jks app-modified.apk my-alias
```

Or use apksigner (Android SDK):

```bash
apksigner sign --ks my-release-key.jks app-modified.apk
```

## Verification

After installation, verify the modification worked:

1. Install the modified APK on your test device
2. Configure the device to use your proxy
3. Install your CA certificate in the device's user certificates
4. Launch the app and check if traffic appears in your proxy

## Troubleshooting

### App Still Rejects Certificate

- **Check certificate pinning**: Some apps have pinning in code, not just config. You may need to use [Frida](https://frida.re/) to bypass it.
- **Verify the manifest**: Ensure `android:networkSecurityConfig` is correctly set
- **Check the XML file**: Ensure `network_security_config.xml` exists in `res/xml/`

### APK Won't Install

- **Signature mismatch**: If replacing an existing app, you need the original signing key
- **Architecture mismatch**: Ensure the APK matches your device's CPU architecture
- **Target SDK**: Some modifications may require adjusting the target SDK version

### apktool Errors

- **Update apktool**: `apktool update`
- **Clear cache**: `apktool d --force app.apk`
- **Check Java version**: apktool requires Java 8+

## Security Notes

- Only use this on apps you own or have permission to test
- Modified APKs should not be distributed
- This technique is for authorized security testing only
- User certificates are less trusted than system certificates on Android 7+

## Related Techniques

- **Frida certificate pinning bypass**: For apps with code-level pinning
- **Objection**: Runtime mobile exploration tool
- **MobSF**: Mobile Security Framework for static analysis

## Quick Reference

| Task | Command |
|------|---------|
| Decompile | `apktool d app.apk` |
| Rebuild | `apktool b folder/ -o output.apk` |
| Sign (jarsigner) | `jarsigner -keystore key.jks app.apk alias` |
| Sign (apksigner) | `apksigner sign --ks key.jks app.apk` |
| Auto-modify | `apk-mitm -i input.apk -o output.apk` |
