---
name: mssql-user-types
description: How to understand and query MSSQL user types from sys.database_principals. Use this skill whenever you need to enumerate SQL Server users, understand principal types (SQL users, Windows users, roles, etc.), interpret authentication types, or analyze database access for security assessments. Trigger this when working with MSSQL pentesting, database security reviews, user enumeration, or when you need to explain what different principal types mean.
---

# MSSQL User Types Reference

This skill helps you understand and query the `sys.database_principals` catalog view in Microsoft SQL Server. This is essential for user enumeration during security assessments, database administration, and understanding access control.

## Quick Reference: Principal Types

| Type Code | Description | Use Case |
|-----------|-------------|----------|
| **A** | Application role | Database-specific application roles |
| **C** | Certificate-mapped user | Users authenticated via certificates |
| **E** | External user (Azure AD) | Azure Active Directory users |
| **G** | Windows group | Windows security groups |
| **K** | Asymmetric key-mapped user | Users authenticated via asymmetric keys |
| **R** | Database role | Custom database roles |
| **S** | SQL user | SQL Server authentication users |
| **U** | Windows user | Windows authentication users |
| **X** | External group (Azure AD) | Azure AD groups |

## Authentication Types (SQL Server 2012+)

| Value | Description |
|-------|-------------|
| 0 | No authentication |
| 1 | Instance authentication |
| 2 | Database authentication |
| 3 | Windows authentication |
| 4 | Azure Active Directory authentication |

## Fixed Database Roles

When `is_fixed_role = 1`, the principal is one of these built-in roles:

- `db_owner` - Full control over the database
- `db_accessadmin` - Add/remove database users
- `db_datareader` - Read all user data
- `db_datawriter` - Insert/update/delete all user data
- `db_ddladmin` - Execute DDL statements
- `db_securityadmin` - Manage permissions
- `db_backupoperator` - Backup database
- `db_denydatareader` - Deny read access
- `db_denydatawriter` - Deny write access

## Common Queries

### List all principals with key details
```sql
SELECT 
    name,
    type,
    type_desc,
    is_fixed_role,
    authentication_type_desc,
    default_schema_name,
    create_date
FROM sys.database_principals
ORDER BY type, name;
```

### Find SQL authentication users (potential weak passwords)
```sql
SELECT name, create_date, default_schema_name
FROM sys.database_principals
WHERE type = 'S';
```

### Find Windows users and groups
```sql
SELECT name, type_desc, create_date
FROM sys.database_principals
WHERE type IN ('U', 'G');
```

### Find members of fixed roles (privilege escalation targets)
```sql
SELECT 
    dp.name AS principal_name,
    dp.type_desc,
    r.name AS role_name
FROM sys.database_principals dp
JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
WHERE r.is_fixed_role = 1
ORDER BY r.name, dp.name;
```

### Find users with dbo access
```sql
SELECT dp.name, dp.type_desc
FROM sys.database_principals dp
JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
WHERE r.name = 'db_owner';
```

### Find Azure AD users/groups
```sql
SELECT name, type_desc, authentication_type_desc
FROM sys.database_principals
WHERE type IN ('E', 'X');
```

## Security Assessment Tips

1. **Start with enumeration** - Query `sys.database_principals` early in any MSSQL assessment
2. **Look for SQL auth users** - Type 'S' users may have weak passwords
3. **Check fixed role membership** - Users in `db_owner` or `db_securityadmin` are high-value targets
4. **Identify orphaned users** - Users without corresponding logins may indicate misconfiguration
5. **Note certificate/key users** - Types 'C' and 'K' may have alternative authentication paths
6. **Check for Azure AD integration** - Types 'E' and 'X' indicate cloud integration

## Key Columns Explained

- **principal_id** - Unique ID within the database, used for joins
- **sid** - Security Identifier, NULL for SYS and INFORMATION_SCHEMA
- **owning_principal_id** - Who owns this principal (fixed roles owned by dbo)
- **default_schema_name** - Default schema for the user (NULL for roles)
- **allow_encrypted_value_modifications** - SQL 2016+ bulk copy encryption setting

## When to Use This Skill

- Enumerating users during MSSQL pentesting
- Understanding database access control
- Investigating privilege escalation paths
- Auditing database security
- Troubleshooting permission issues
- Documenting database user structure

## Related Views

- `sys.server_principals` - Server-level principals
- `sys.database_role_members` - Role membership
- `sys.database_permissions` - Permission details
- `sys.schemas` - Schema information
