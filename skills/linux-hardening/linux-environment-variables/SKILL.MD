---
name: linux-environment-variables
description: How to manage, configure, and secure Linux environment variables. Use this skill whenever the user needs to set, modify, or understand environment variables on Linux systems, configure proxies, hide command history, manage SSL certificates, customize prompts, or troubleshoot variable inheritance issues. Trigger for any task involving export, unset, PATH, proxy settings, HISTCONTROL, or environment variable security.
---

# Linux Environment Variables

A skill for managing Linux environment variables, including security hardening, proxy configuration, and system customization.

## When to Use This Skill

Use this skill when you need to:
- Set or modify environment variables (global or local)
- Configure proxy settings for network tools
- Hide or control command history for security
- Manage SSL certificate paths
- Customize bash prompts (PS1)
- Debug variable inheritance issues
- Understand what common environment variables do

## Core Concepts

### Global vs Local Variables

**Global variables** are inherited by child processes:
```bash
export MYVAR="value"
echo $MYVAR  # Accessible in current session and children
unset MYVAR  # Remove the variable
```

**Local variables** only exist in the current shell:
```bash
LOCAL="value"
echo $LOCAL  # Only accessible here, not in child processes
```

### Listing Variables

```bash
set           # All variables (including local)
env           # Exported variables only
printenv      # Same as env
cat /proc/$$/environ              # Current process env
cat /proc/$(python -c "import os; print(os.getppid())")/environ  # Parent process env
```

## Common Environment Variables

| Variable | Purpose |
|----------|----------|
| `DISPLAY` | X display (usually `:0.0`) |
| `EDITOR` | Preferred text editor |
| `HOME` | User's home directory |
| `HOSTNAME` | Computer hostname |
| `LANG` | Current language |
| `PATH` | Directories containing executables |
| `PWD` | Current working directory |
| `SHELL` | Current shell path (e.g., `/bin/bash`) |
| `TERM` | Terminal type (e.g., `xterm`) |
| `USER` | Current username |
| `TZ` | Time zone |

## Security & Hardening

### Hiding Command History

Prevent commands from being saved to `~/.bash_history`:

```bash
# Disable history file writing on session end
export HISTFILESIZE=0

# Disable in-memory history
export HISTSIZE=0

# Hide commands that start with a space
export HISTCONTROL=ignorespace
```

**Usage:** Commands prefixed with a space won't be saved:
```bash
$ echo "this saves"
$  echo "this does not save"  # Note the leading space
```

### Proxy Configuration

Set HTTP/HTTPS proxies:
```bash
export http_proxy="http://10.10.10.10:8080"
export https_proxy="http://10.10.10.10:8080"
```

Set SOCKS proxy for all protocols:
```bash
export all_proxy="socks5h://10.10.10.10:1080"
```

Bypass proxy for specific hosts:
```bash
export no_proxy="localhost,127.0.0.1,.corp.local,10.0.0.0/8"
```

**Note:** Both lowercase and uppercase variants work (`http_proxy`/`HTTP_PROXY`).

### SSL Certificate Configuration

Point tools to custom CA certificates:
```bash
export SSL_CERT_FILE=/path/to/ca-bundle.pem
export SSL_CERT_DIR=/path/to/ca-certificates
```

## Customizing Your Prompt (PS1)

The `PS1` variable controls your bash prompt appearance. Common elements:

- `\u` - username
- `\h` - hostname
- `\w` - current directory
- `\$` - `#` for root, `$` for users
- `\!` - command number
- `\d` - date
- `\t` - time

**Example prompt:**
```bash
export PS1="\u@\h:\w\$ "
```

## Scripts

Use the bundled scripts for common tasks:

- `scripts/list-variables.sh` - Display all environment variables in a formatted table
- `scripts/hide-history.sh` - Configure history hiding for security
- `scripts/set-proxy.sh` - Configure proxy settings with validation

## Troubleshooting

### Variable not persisting

If a variable disappears after closing the terminal, add it to your shell config:
```bash
echo 'export MYVAR="value"' >> ~/.bashrc
source ~/.bashrc
```

### Child process not seeing variable

Make sure you used `export`:
```bash
# Wrong - child won't see this
MYVAR="value"

# Right - child will inherit
export MYVAR="value"
```

### PATH issues

Check if a command is in your PATH:
```bash
which command_name
hash -r  # Clear command hash cache
```

## Best Practices

1. **Use `export` for variables child processes need**
2. **Set `HISTCONTROL=ignorespace` for sensitive work**
3. **Validate proxy URLs before setting them**
4. **Document custom variables in your shell config**
5. **Use `printenv` to verify variables are set correctly**
6. **Be careful with `PATH` modifications - they affect all commands**
