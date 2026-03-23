---
name: s3-bucket-enumeration
description: How to enumerate and abuse AWS S3 buckets during cloud pentesting. Use this skill whenever the user mentions S3 buckets, AWS storage, cloud storage enumeration, bucket access testing, or wants to check for unauthenticated S3 access. Make sure to use this skill for any AWS cloud security assessment involving storage services, even if the user doesn't explicitly mention 'S3' or 'buckets'.
---

# S3 Bucket Enumeration and Abuse

This skill helps you enumerate AWS S3 buckets, test for unauthenticated access, and identify misconfigurations during cloud penetration testing.

## When to Use This Skill

Use this skill when:
- You're performing cloud security assessments on AWS infrastructure
- You need to enumerate S3 buckets from a target organization
- You want to test for public/unauthenticated bucket access
- You're checking for S3 misconfigurations (public read/write, CORS issues, etc.)
- You need to extract data from accessible S3 buckets
- The user mentions AWS storage, cloud buckets, or S3-related tasks

## Prerequisites

- AWS CLI installed and configured (optional, for authenticated operations)
- `curl` or `wget` for HTTP-based enumeration
- Wordlist of potential bucket names (optional but recommended)

## Enumeration Techniques

### 1. Bucket Name Guessing

S3 bucket names are globally unique but often follow predictable patterns. Common patterns include:
- Company name + service (e.g., `acme-corp-backups`)
- Project names (e.g., `acme-website-assets`)
- Environment names (e.g., `acme-dev-data`, `acme-prod-logs`)
- Date-based names (e.g., `acme-2024-backup`)

**Use the enumeration script:**
```bash
./scripts/enumerate_buckets.sh <wordlist> <target-domain>
```

### 2. Check for Public Access

Test if a bucket allows unauthenticated access:

```bash
# Check if bucket exists and is publicly readable
aws s3api head-bucket --bucket <bucket-name> 2>/dev/null && echo "Bucket exists"

# Try to list objects without credentials
aws s3 ls s3://<bucket-name>/ --no-sign-request 2>/dev/null
```

**Use the access check script:**
```bash
./scripts/check_bucket_access.sh <bucket-name>
```

### 3. List Bucket Contents

If a bucket is publicly readable, enumerate its contents:

```bash
# List all objects recursively
aws s3 ls s3://<bucket-name>/ --recursive --no-sign-request

# Or use curl for direct HTTP access
curl -s "https://<bucket-name>.s3.amazonaws.com/"
```

**Use the listing script:**
```bash
./scripts/list_bucket_contents.sh <bucket-name> [output-dir]
```

### 4. Test Write Access

Some buckets allow unauthenticated writes (critical finding):

```bash
# Try to upload a test file
echo "test" > test-file.txt
aws s3 cp test-file.txt s3://<bucket-name>/test-file.txt --no-sign-request

# Verify it was uploaded
aws s3 cp s3://<bucket-name>/test-file.txt . --no-sign-request

# Clean up if successful
aws s3 rm s3://<bucket-name>/test-file.txt --no-sign-request
```

### 5. Check for CORS Misconfigurations

CORS (Cross-Origin Resource Sharing) misconfigurations can enable attacks:

```bash
# Check CORS configuration
curl -s -X OPTIONS -H "Origin: https://attacker.com" \
  -H "Access-Control-Request-Method: GET" \
  "https://<bucket-name>.s3.amazonaws.com/"
```

### 6. Look for Sensitive Files

Common sensitive file patterns to search for:
- `*.log`, `*.txt`, `*.csv`, `*.json`, `*.xml`
- `*.env`, `*.config`, `*.conf`, `*.cfg`
- `*.key`, `*.pem`, `*.p12`, `*.pfx`
- `backup*`, `dump*`, `database*`, `credentials*`
- `aws*`, `secrets*`, `password*`

## Common Misconfigurations to Check

| Misconfiguration | Risk | Detection |
|-----------------|------|----------|
| Public Read Access | Data exposure | `aws s3 ls --no-sign-request` |
| Public Write Access | Data injection | Upload test file |
| No Encryption | Data interception | Check bucket policy |
| CORS Issues | XSS, CSRF | Test OPTIONS requests |
| ACL Misconfiguration | Unauthorized access | Check object ACLs |

## Example Workflow

```bash
# 1. Enumerate potential bucket names
./scripts/enumerate_buckets.sh wordlists/bucket-names.txt example.com

# 2. For each discovered bucket, check access
for bucket in $(cat discovered-buckets.txt); do
    ./scripts/check_bucket_access.sh $bucket
done

# 3. For accessible buckets, list contents
./scripts/list_bucket_contents.sh accessible-bucket-name ./output/

# 4. Test write access on writable buckets
echo "test" | aws s3 cp - writable-bucket/test.txt --no-sign-request
```

## Wordlist Resources

Use these wordlists for bucket enumeration:
- `secLists/Discovery/Web-Content/raft-small-words.txt`
- `custom wordlists based on target company name`
- `common S3 bucket naming patterns`

## Reporting Findings

When documenting findings, include:
1. Bucket name and URL
2. Access level discovered (read/write/none)
3. Sample of accessible data (if any)
4. Risk assessment (critical/high/medium/low)
5. Remediation recommendations

## Remediation Recommendations

- Enable bucket versioning
- Remove public access policies
- Use IAM policies instead of ACLs
- Enable S3 Block Public Access
- Implement S3 Bucket Policies with least privilege
- Enable S3 Server Access Logging
- Use S3 Encryption (SSE-S3, SSE-KMS, or SSE-C)

## Scripts Reference

- `scripts/enumerate_buckets.sh` - Enumerate buckets from wordlist
- `scripts/check_bucket_access.sh` - Test bucket access permissions
- `scripts/list_bucket_contents.sh` - List and download bucket contents

## Safety and Ethics

- Only test buckets you have authorization to assess
- Document all findings properly
- Clean up any test files you upload
- Report critical findings immediately
- Follow responsible disclosure practices
