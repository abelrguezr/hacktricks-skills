---
name: burp-suite-payloads
description: Guide for creating and using Burp Suite payloads for web security testing. Use this skill whenever the user mentions Burp Suite, web security testing, payload generation, fuzzing, brute forcing, or needs help with security assessment tools. This includes requests about payload lists, case modification, number generation, DNS exfiltration, or HTTP scripting.
---

# Burp Suite Payloads Guide

A comprehensive guide for creating and using payloads in Burp Suite for web security testing.

## When to Use This Skill

Use this skill when:
- Setting up Burp Suite for web security testing
- Creating custom payload lists for fuzzing or brute forcing
- Needing to modify payload case (lowercase, uppercase, proper case)
- Generating number sequences for testing
- Setting up DNS exfiltration for command execution
- Creating HTTP scripts for Burp Suite
- Learning about Burp Suite payload types

## Basic Payload Types

### 1. Simple List

A straightforward list with one entry per line. This is the most common payload format.

**Use case:** Testing common vulnerabilities with known payloads

**Example:**
```
admin
administrator
root
user
```

### 2. Runtime File

A list read at runtime rather than loaded into memory. Essential for large payload sets.

**Use case:** When working with large wordlists (100k+ entries) to avoid memory issues

**How to use:**
- In Burp Suite Intruder, select "Use file" option
- Point to your payload file
- Burp will stream the file rather than loading it all at once

### 3. Case Modification

Apply transformations to payload strings:

| Type | Description | Example |
|------|-------------|---------|
| No change | Keep original | `Admin` |
| Lowercase | All lowercase | `admin` |
| Uppercase | All uppercase | `ADMIN` |
| Proper name | First letter capitalized, rest lowercase | `Admin` |
| Proper Name | First letter capitalized, rest unchanged | `AdMiN` |

**Use case:** Testing case-sensitive authentication, parameter names, or file paths

### 4. Numbers

Generate numeric sequences:

- **Range:** From X to Y with step Z
- **Random:** Random numbers within a range

**Use case:** Testing sequential IDs, version numbers, or numeric parameters

**Example configuration:**
- Start: 1
- End: 1000
- Step: 1

### 5. Brute Forcer

Generate combinations from a character set:

**Configuration:**
- Character set: e.g., `a-z0-9` or `a-zA-Z0-9!@#$%`
- Min length: e.g., 6
- Max length: e.g., 12

**Use case:** Password testing, session ID guessing, or parameter discovery

## Advanced Tools

### Collabfiltrator

**Purpose:** Execute commands and exfiltrate output via DNS requests to burpcollab

**Repository:** https://github.com/0xC01DF00D/Collabfiltrator

**Use case:** When you need to confirm command execution on a target and retrieve output through DNS channels (useful when direct connections are blocked)

**How it works:**
1. Payload executes a command on the target
2. Output is encoded and sent via DNS query to burpcollab
3. You receive the DNS request with the exfiltrated data

### HTTP Script Generator

**Purpose:** Generate Burp Suite HTTP scripts for custom request/response manipulation

**Repository:** https://github.com/h3xstream/http-script-generator

**Use case:** Creating custom extensions, request/response modifiers, or automated testing scripts

## Practical Examples

### Example 1: Testing Login Forms

**Goal:** Test for weak credentials

**Setup:**
1. Use Simple List with common usernames
2. Use Brute Forcer for passwords (a-z0-9, length 6-8)
3. Configure Intruder to attack both username and password fields

### Example 2: Parameter Discovery

**Goal:** Find hidden parameters

**Setup:**
1. Use Simple List with common parameter names
2. Apply case modification to test variations
3. Monitor for different response sizes or codes

### Example 3: IDOR Testing

**Goal:** Test for Insecure Direct Object References

**Setup:**
1. Use Numbers payload (1-1000, step 1)
2. Replace ID parameters in requests
3. Look for access to unauthorized resources

## Best Practices

1. **Start small:** Begin with a limited payload set to verify your approach works
2. **Use runtime files:** For large payloads, always use runtime file mode to save memory
3. **Rate limiting:** Configure delays between requests to avoid detection and server overload
4. **Monitor responses:** Set up matchers to identify interesting responses automatically
5. **Document findings:** Keep track of which payloads produced which results

## Common Payload Sources

- **SecLists:** https://github.com/danielmiessler/SecLists
- **Burp Suite Extensions:** Check BApp Store for payload generators
- **Custom wordlists:** Build your own based on target context

## Safety and Ethics

- Only test systems you have explicit authorization to assess
- Follow responsible disclosure practices
- Document all testing activities
- Respect rate limits and avoid causing service disruption
- Comply with applicable laws and regulations

## Next Steps

After setting up your payloads:
1. Configure Burp Suite Intruder with your payload set
2. Set up matchers to identify interesting responses
3. Run a small test batch first
4. Analyze results and refine your approach
5. Scale up testing as appropriate

---

*This skill provides guidance on Burp Suite payload creation. For specific vulnerability testing methodologies, refer to OWASP testing guides and your organization's security policies.*
