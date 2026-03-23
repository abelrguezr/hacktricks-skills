---
name: drupal-pentest
description: How to perform security assessments and penetration testing on Drupal websites. Use this skill whenever the user mentions Drupal, wants to enumerate a Drupal site, check for Drupal vulnerabilities, test Drupal security, or perform any kind of Drupal penetration testing. This includes version detection, user enumeration, module discovery, RCE exploitation, and post-exploitation activities on Drupal installations.
---

# Drupal Penetration Testing

A comprehensive guide for security testing Drupal websites, from discovery through post-exploitation.

## Discovery

### Check Drupal Meta Tags

Verify if a site is running Drupal by checking meta tags:

```bash
curl https://www.drupal.org/ | grep 'content="Drupal'
```

### Node Enumeration

Drupal indexes content using nodes. Pages are typically at `/node/<nodeid>`:

```bash
curl drupal-site.com/node/1
```

## Enumeration

### Version Detection

Check for exposed changelog files:

```bash
curl -s http://drupal-site.local/CHANGELOG.txt | grep -m2 ""
```

**Note:** Newer Drupal installations block access to `CHANGELOG.txt` and `README.txt` by default.

### Username Enumeration

Drupal has three default user types:
1. **Administrator** - Complete control
2. **Authenticated User** - Can log in and perform operations based on permissions
3. **Anonymous** - Read-only access

**Enumeration techniques:**

1. **Sequential user IDs:** Access `/user/1`, `/user/2`, `/user/3` until errors indicate non-existent users
2. **Registration check:** Visit `/user/register` and attempt to create a username - errors indicate taken names
3. **Password reset:** Try resetting passwords - errors reveal whether users exist

### Hidden Page Discovery

Enumerate nodes by fuzzing numeric IDs:

```bash
# Check nodes 1-1000 for hidden content
for i in $(seq 1 1000); do curl -s drupal-site.com/node/$i | grep -q "content" && echo "Found: /node/$i"; done
```

### Module Information Discovery

Check for exposed configuration files:

```bash
# Get installed modules info
curl https://example.com/config/sync/core.extension.yml
curl https://example.com/core/core.services.yml

# Download exposed configuration files
curl https://example.com/config/sync/swiftmailer.transport.yml
```

## Automated Scanning

### Droopescan

Use droopescan for automated Drupal vulnerability scanning:

```bash
droopescan scan drupal -u http://drupal-site.local
```

## Remote Code Execution (RCE)

If you have access to the Drupal web console, check for RCE vectors. Common Drupal RCE techniques include:

- Drupalgeddon2 (Drupal 7.x < 7.32)
- Drupalgeddon3 (Drupal 7.x < 7.32)
- Drupal 8/9/10 form builder vulnerabilities
- Template injection attacks

## XSS to RCE Escalation

### Drupalwned Tool

[Drupalwned](https://github.com/nowak0x01/Drupalwned) is an exploitation script that elevates XSS to RCE:

**Supported versions:** Drupal 7.X.X, 8.X.X, 9.X.X, 10.X.X

**Capabilities:**
- **Privilege Escalation:** Creates administrative users
- **RCE via Template Upload:** Uploads backdoored templates

## Post-Exploitation

### Extract Database Credentials

Find and parse `settings.php` for database credentials:

```bash
find / -name settings.php -exec grep "drupal_hash_salt\|'database'\|'username'\|'password'\|'host'\|'port'\|'driver'\|'prefix'" {} \; 2>/dev/null
```

### Dump User Database

Extract user data from the Drupal database:

```bash
mysql -u drupaluser --password='PASSWORD' -e 'use drupal; select * from users'
```

## Best Practices

1. **Always verify Drupal version** before attempting exploits - vulnerabilities are version-specific
2. **Check for exposed configuration files** - misconfigured Drupal sites often leak sensitive data
3. **Use automated scanners** like droopescan for initial reconnaissance
4. **Document findings** - track which nodes, users, and modules you discover
5. **Test responsibly** - only test systems you have authorization to assess

## Common Vulnerabilities to Check

- **Drupalgeddon2** (CVE-2018-7600) - Drupal 7.x < 7.32
- **Drupalgeddon3** (CVE-2018-7598) - Drupal 7.x < 7.32
- **Drupal 8/9/10** - Form builder and template injection vulnerabilities
- **Exposed configuration files** - `/config/sync/` directory access
- **User enumeration** - Weak user ID sequences
- **XSS vulnerabilities** - Can lead to RCE via Drupalwned
