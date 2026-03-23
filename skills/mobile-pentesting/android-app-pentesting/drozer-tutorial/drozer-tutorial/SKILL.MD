---
name: drozer-android-pentest
description: Use Drozer to perform Android application security testing. Use this skill whenever you need to analyze Android APKs for security vulnerabilities, test exported components (activities, services, content providers, broadcast receivers), or perform mobile penetration testing. This skill covers Drozer setup, connection to Android devices, and running security assessment modules. Make sure to use this skill when the user mentions Android security testing, APK analysis, mobile pentesting, exported components, or Drozer commands.
---

# Drozer Android Penetration Testing

A skill for performing Android application security assessments using Drozer.

## Setup

### Install Drozer Client

```bash
pip install drozer-2.4.4-py2-none-any.whl
pip install twisted
pip install service_identity
```

### Install Drozer Agent on Android

1. Download drozer-agent APK from [releases](https://github.com/mwrlabs/drozer/releases)
2. Install via ADB:
   ```bash
   adb install drozer-agent-2.3.4.apk
   ```

### Connect to Device

```bash
# Port forward to establish communication
adb forward tcp:31415 tcp:31415

# Launch the Drozer agent app and press "ON"
# Then connect from your terminal
drozer console connect
```

## Core Commands

| Command | Description |
|---------|-------------|
| `list` | List all available modules |
| `run MODULE` | Execute a module |
| `shell` | Interactive Linux shell on device |
| `help MODULE` | Show module help |
| `clean` | Remove temporary files |
| `load` | Load and execute command file |
| `exploit list` | List available exploits |
| `payload list` | List available payloads |

## Package Analysis

### Find Package Name

```bash
run app.package.list -f <partial-name>
```

### Get Package Information

```bash
run app.package.info -a <package-name>
```

This shows:
- Package name and process name
- Version
- Data directory and APK path
- UID/GID
- Permissions used and defined

### Read Manifest

```bash
run app.package.manifest <package-name>
```

### Check Attack Surface

```bash
run app.package.attacksurface <package-name>
```

This reveals:
- Exported activities (can be started from outside)
- Exported broadcast receivers
- Exported content providers (potential SQL injection/path traversal)
- Exported services
- Whether the app is debuggable

## Testing Activities

### List Exported Activities

```bash
run app.activity.info -a <package-name>
```

### Start Activity (Bypass Authorization)

```bash
run app.activity.start --component <package> <activity>
```

Or via ADB:
```bash
adb shell am start -n <package>/<activity>
```

## Testing Services

### List Services

```bash
run app.service.info -a <package-name>
```

### Send Message to Service

```bash
run app.service.send <package> <service> --msg <what> <arg1> <arg2> --extra string <key> <value> --bundle-as-obj
```

The `--msg` parameters map to:
- `what` → msg.what
- `arg1` → msg.arg1  
- `arg2` → msg.arg2

Use `--extra` to send data interpreted by msg.replyTo.

## Testing Broadcast Receivers

### List Broadcast Receivers

```bash
run app.broadcast.info -a <package-name>
```

### Send Broadcast

```bash
run app.broadcast.send --action <action> --component <package> <receiver> --extra string <key> <value>
```

### Sniff Broadcasts

```bash
run app.broadcast.sniff
```

## Check Debuggable Apps

```bash
run app.package.debuggable
```

Debuggable apps allow:
- Attaching Java debugger
- Runtime inspection
- Setting breakpoints
- Reading/modifying variables

## Test APKs

- [Sieve](https://github.com/mwrlabs/drozer/releases/download/2.3.4/sieve.apk) - From MWR Labs
- [DIVA](https://payatu.com/wp-content/uploads/2016/01/diva-beta.tar.gz) - Deliberately insecure app

## Workflow

1. **Setup**: Install Drozer client and agent, establish connection
2. **Recon**: List packages, get package info, check attack surface
3. **Test Activities**: List and start exported activities to bypass authorization
4. **Test Services**: List and send messages to services
5. **Test Broadcasts**: List and send broadcasts
6. **Check Debuggable**: Identify debuggable applications for deeper analysis

## Example Session

```bash
# Connect
drozer console connect

# Find target package
dz> run app.package.list -f sieve
com.mwr.example.sieve

# Get package info
dz> run app.package.info -a com.mwr.example.sieve

# Check attack surface
dz> run app.package.attacksurface com.mwr.example.sieve

# List activities
dz> run app.activity.info -a com.mwr.example.sieve

# Start an activity
dz> run app.activity.start --component com.mwr.example.sieve com.mwr.example.sieve.PWList

# List services
dz> run app.service.info -a com.mwr.example.sieve

# Send message to service
dz> run app.service.send com.mwr.example.sieve com.mwr.example.sieve.AuthService --msg 2354 9234 1 --extra string com.mwr.example.sieve.PIN 1337 --bundle-as-obj
```

## References

- [Drozer Documentation PDF](https://labs.withsecure.com/content/dam/labs/docs/mwri-drozer-user-guide-2015-03-23.pdf)
- [InfoSec Institute Walkthrough](https://resources.infosecinstitute.com/android-penetration-tools-walkthrough-series-drozer/)
- [Hacking Articles Guide](https://www.hackingarticles.in/android-penetration-testing-drozer/)
