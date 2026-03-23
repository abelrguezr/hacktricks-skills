---
name: mythic-c2-framework
description: How to set up and use the Mythic C2 framework for authorized red teaming and security testing. Use this skill whenever the user needs to install Mythic, configure agents (Apollo, Poseidon, etc.), set up C2 profiles, or execute common red team operations like lateral movement, privilege escalation, or credential access. Make sure to use this skill when the user mentions Mythic, C2 frameworks, red teaming, penetration testing, or authorized security assessments involving command and control infrastructure.
---

# Mythic C2 Framework

Mythic is an open-source, modular command and control (C2) framework designed for **authorized red teaming and security testing**. It allows security professionals to manage and deploy various agents (payloads) across different operating systems, including Windows, Linux, and macOS.

> **⚠️ IMPORTANT**: This skill is for **authorized security testing only**. Only use Mythic on systems you own or have explicit written permission to test. Unauthorized use is illegal and unethical.

## Quick Start

### Installation

1. Clone the Mythic repository:
   ```bash
   git clone https://github.com/its-a-feature/Mythic
   cd Mythic
   ```

2. Follow the official installation instructions in the [Mythic repo](https://github.com/its-a-feature/Mythic)

3. Start the Mythic server:
   ```bash
   sudo ./mythic-cli start
   ```

4. Access the web interface at `http://localhost:8080`

## Managing Agents

Agents are the payloads that perform tasks on target systems. Mythic doesn't include agents by default - you install them separately.

### Installing Agents

```bash
# Install from MythicAgents repository
sudo ./mythic-cli install github https://github.com/MythicAgents/<agent-name>

# Example: Install Apollo (Windows agent)
sudo ./mythic-cli install github https://github.com/MythicAgents/Apollo.git

# Example: Install Poseidon (Linux/macOS agent)
sudo ./mythic-cli install github https://github.com/MythicAgents/Poseidon.git
```

You can add agents even while Mythic is running.

### Available Agents

| Agent | Platform | Description |
|-------|----------|-------------|
| **Apollo** | Windows | C# .NET 4.0 agent, similar to Cobalt Strike Beacon |
| **Poseidon** | Linux/macOS | Golang agent for Unix-like systems |
| **Forge** | All | Loads COFF/BOF modules for stealthy execution |

## C2 Profiles

C2 profiles define how agents communicate with the Mythic server (protocol, encryption, etc.).

### Installing C2 Profiles

```bash
# Install from MythicC2Profiles repository
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/<profile-name>

# Example: Install HTTP profile
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/http
```

Manage profiles through the Mythic web interface after installation.

## Apollo Agent Commands (Windows)

### Common Actions

| Command | Description |
|---------|-------------|
| `cat` | Print file contents |
| `cd` | Change directory |
| `cp` | Copy files |
| `ls` | List files and directories |
| `pwd` | Print current directory |
| `ps` | List running processes |
| `download` | Download file from target |
| `upload` | Upload file to target |
| `reg_query` | Query registry keys |
| `reg_write_value` | Write registry values |
| `sleep` | Change agent check-in interval |
| `help` | Show available commands |
| `clear` | Mark tasks as cleared |

### Privilege Escalation

| Command | Description |
|---------|-------------|
| `getprivs` | Enable privileges on current thread token |
| `getsystem` | Escalate to SYSTEM level |
| `make_token` | Create new logon session for impersonation |
| `steal_token` | Steal token from another process |
| `pth` | Pass-the-Hash attack |
| `mimikatz` | Extract credentials from memory/SAM |
| `rev2self` | Revert to original token |
| `ppid` | Change parent process for jobs |
| `printspoofer` | Bypass print spooler security |
| `dcsync` | Sync Kerberos keys for offline cracking |
| `ticket_cache_add` | Add Kerberos ticket to session |

### Process Execution

| Command | Description |
|---------|-------------|
| `assembly_inject` | Inject .NET assembly into remote process |
| `execute_assembly` | Execute .NET assembly in agent context |
| `execute_coff` | Execute COFF file in memory |
| `execute_pe` | Execute unmanaged PE executable |
| `inline_assembly` | Execute .NET assembly in disposable AppDomain |
| `run` | Execute binary using system PATH |
| `shinject` | Inject shellcode into remote process |
| `inject` | Inject agent shellcode into remote process |
| `spawn` | Spawn new agent session in executable |
| `spawnto_x64` | Change default binary for x64 jobs |
| `spawnto_x86` | Change default binary for x86 jobs |

### PowerShell & Scripting

| Command | Description |
|---------|-------------|
| `powershell_import` | Import .ps1 script to agent cache |
| `powershell` | Execute PowerShell command |
| `powerpick` | Inject PowerShell loader (no logging) |
| `psinject` | Execute PowerShell in specified process |
| `shell` | Execute shell command (cmd.exe) |

### Lateral Movement

| Command | Description |
|---------|-------------|
| `jump_psexec` | Lateral movement via PsExec |
| `jump_wmi` | Lateral movement via WMI |
| `wmiexecute` | Execute command via WMI |
| `net_dclist` | List domain controllers |
| `net_localgroup` | List local groups |
| `net_localgroup_member` | List group members |
| `net_shares` | List remote shares |
| `socks` | Enable SOCKS5 proxy |
| `rpfwd` | Reverse port forward |
| `listpipes` | List named pipes |

### Mythic Forge (BOF/COFF Execution)

Install the Forge agent to load pre-compiled payloads:

```bash
./mythic-cli install github https://github.com/MythicAgents/forge.git
```

Load collections:
```bash
forge_collections {"collectionName":"SharpCollection"}
forge_collections {"collectionName":"SliverArmory"}
```

Loaded modules appear as commands like `forge_bof_sa-whoami` or `forge_bof_sa-netuser`.

## Poseidon Agent Commands (Linux/macOS)

### Common Actions

| Command | Description |
|---------|-------------|
| `cat` | Print file contents |
| `cd` | Change directory |
| `chmod` | Change file permissions |
| `config` | View config and host info |
| `cp` | Copy files |
| `curl` | Execute web request |
| `upload` | Upload file to target |
| `download` | Download file from target |
| `shell` | Execute shell command via /bin/sh |
| `run` | Execute command from disk |
| `pty` | Open interactive PTY |

### Sensitive Information Search

| Command | Description |
|---------|-------------|
| `triagedirectory` | Find interesting/sensitive files |
| `getenv` | Get environment variables |

### Lateral Movement

| Command | Description |
|---------|-------------|
| `ssh` | SSH to host with PTY |
| `sshauth` | SSH to host(s) with credentials |
| `link_tcp` | Link to another agent over TCP |
| `link_webshell` | Link via webshell P2P profile |
| `rpfwd` | Reverse port forward |
| `socks` | SOCKS5 proxy |
| `portscan` | Scan for open ports |

## Common Workflows

### 1. Initial Setup

```bash
# Install Mythic
git clone https://github.com/its-a-feature/Mythic
cd Mythic

# Install required agents
sudo ./mythic-cli install github https://github.com/MythicAgents/Apollo.git
sudo ./mythic-cli install github https://github.com/MythicAgents/Poseidon.git
sudo ./mythic-cli install github https://github.com/MythicAgents/forge.git

# Install C2 profiles
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/http

# Start server
sudo ./mythic-cli start
```

### 2. Deploy Agent to Target

1. In Mythic web UI, select your agent type
2. Configure C2 profile
3. Generate payload (executable, script, etc.)
4. Deploy to target system
5. Monitor for check-ins in the web interface

### 3. Execute Commands

1. Select the agent in the web interface
2. Choose a command from the available list
3. Configure parameters
4. Execute and view results

### 4. Lateral Movement

```bash
# Enumerate domain
net_dclist {"domain":"YOURDOMAIN.local"}

# Find targets
net_shares {"computer":"TARGET-PC"}

# Move laterally
jump_psexec {"computer":"TARGET-PC", "username":"admin", "password":"password"}
```

## Best Practices

1. **Always have authorization** - Written permission for all testing
2. **Use appropriate C2 profiles** - Match your testing environment
3. **Document everything** - Keep records of all actions taken
4. **Test in isolated environments** - Use lab environments for practice
5. **Follow responsible disclosure** - Report findings appropriately

## Resources

- [Mythic GitHub](https://github.com/its-a-feature/Mythic)
- [MythicAgents Repository](https://github.com/MythicAgents)
- [MythicC2Profiles Repository](https://github.com/MythicC2Profiles)
- [Apollo Agent](https://github.com/MythicAgents/Apollo)
- [Poseidon Agent](https://github.com/MythicAgents/Poseidon)

## Troubleshooting

### Agent not checking in
- Verify C2 profile is correctly configured
- Check firewall rules allow communication
- Confirm agent was deployed correctly
- Review Mythic server logs

### Commands not executing
- Ensure agent is active and checking in
- Verify command syntax
- Check agent has required permissions
- Review agent logs in web interface

### Installation issues
- Ensure all dependencies are installed
- Check Python version compatibility
- Verify database is running (PostgreSQL)
- Review installation logs
