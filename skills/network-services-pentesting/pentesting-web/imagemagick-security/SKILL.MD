---
name: imagemagick-security-hardening
description: Configure and audit ImageMagick security policies to prevent RCE and DoS vulnerabilities. Use this skill whenever you need to secure ImageMagick installations, review policy.xml files, harden image processing services, or investigate ImageMagick-related security issues. Trigger this skill for any ImageMagick configuration, policy review, or image processing security task.
---

# ImageMagick Security Hardening

This skill helps you configure secure ImageMagick policies, audit existing configurations, and prevent common vulnerabilities like RCE and DoS attacks.

## Quick Start

1. **Find active policy files** on the system
2. **Review current policies** with `identify -list policy`
3. **Apply the allowlist approach** (deny all, allow specific)
4. **Set resource limits** to prevent DoS
5. **Verify the configuration** works correctly

## Finding Policy Files

ImageMagick policies can be fragmented across installations. Locate all policy files:

```bash
find / -iname policy.xml 2>/dev/null
```

Common locations:
- `/etc/ImageMagick-6/policy.xml`
- `/etc/ImageMagick-7/policy.xml`
- `/usr/lib/ImageMagick-*/policy.xml`
- `/usr/local/etc/ImageMagick-*/policy.xml`

## Current Policy Review

Check what policies are currently active:

```bash
identify -list policy
```

Look for:
- Coder policies (which image formats are allowed)
- Resource limits (memory, width, height, area, disk)
- Path restrictions
- Module restrictions

## The Allowlist Approach

**Modern ImageMagick (6.9.7-7+) uses allowlist by default.** This is more secure than denylist.

### Basic Restrictive Policy Template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policymap [
  <!ELEMENT policymap (policy+)>
  <!ATTLIST policymap xmlns CDATA #FIXED "">
  <!ELEMENT policy EMPTY>
  <!ATTLIST policy domain NMTOKEN #REQUIRED
                   rights NMTOKEN #REQUIRED
                   pattern CDATA #REQUIRED
                   value CDATA #IMPLIED>
]>
<policymap>
  <!-- Deny all coders by default -->
  <policy domain="coder" rights="none" pattern="*" />
  
  <!-- Allow only safe, commonly-needed formats -->
  <policy domain="coder" rights="read | write" pattern="{GIF,JPEG,PNG,WEBP}" />
  
  <!-- Deny dangerous coders explicitly (defense in depth) -->
  <policy domain="coder" rights="none" pattern="{PS,PDF,XPS,DPS,SVG,MVG}" />
  
  <!-- Resource limits to prevent DoS -->
  <policy domain="resource" name="memory" value="256MiB" />
  <policy domain="resource" name="map" value="512MiB" />
  <policy domain="resource" name="width" value="16000" />
  <policy domain="resource" name="height" value="16000" />
  <policy domain="resource" name="list-length" value="128" />
  <policy domain="resource" name="area" value="256MB" />
  <policy domain="resource" name="disk" value="1GiB" />
  <policy domain="resource" name="file" value="768" />
  <policy domain="resource" name="thread" value="4" />
  <policy domain="resource" name="throttle" value="0" />
  <policy domain="resource" name="time" value="3600" />
  
  <!-- Restrict dangerous modules -->
  <policy domain="module" rights="none" pattern="*" />
  
  <!-- Restrict file paths if needed -->
  <policy domain="path" rights="none" pattern="@*" />
</policymap>
```

## Key Security Considerations

### 1. Case Sensitivity

Policy patterns are **case sensitive**. Always use uppercase for coder names:
- ✅ `pattern="{GIF,JPEG,PNG}"`
- ❌ `pattern="{gif,jpeg,png}"`

### 2. Dangerous Coders to Block

These coders have historically been associated with vulnerabilities:

| Coder | Risk | Reason |
|-------|------|--------|
| `PS` | High | PostScript can execute arbitrary code |
| `PDF` | High | PDF processing has many CVEs |
| `XPS` | High | Microsoft XPS format vulnerabilities |
| `DPS` | High | Device-independent PostScript |
| `SVG` | Medium | Can contain embedded scripts |
| `MVG` | Medium | Magick Vector Graphics |
| `TXT` | Medium | Text format can be abused |
| `URL` | High | Remote file access |
| `HTTPS` | High | Remote file access |
| `FTP` | High | Remote file access |

### 3. Resource Limits

Prevent DoS attacks by setting reasonable limits:

| Resource | Recommended Max | Purpose |
|----------|-----------------|---------|
| `memory` | 256MiB | Heap memory usage |
| `map` | 512MiB | Memory map size |
| `width` | 16000 | Maximum image width |
| `height` | 16000 | Maximum image height |
| `area` | 256MB | Total pixel area |
| `disk` | 1GiB | Temporary disk usage |
| `file` | 768 | Open file descriptors |
| `thread` | 4 | Thread pool size |
| `time` | 3600 | Maximum processing time (seconds) |

### 4. Policy Fragmentation

Multiple policy files can exist. The last one loaded wins for conflicting rules. Always:
1. Find all policy files
2. Check which one is active
3. Ensure your restrictive policy is loaded last

## Verification Commands

```bash
# Check active policies
identify -list policy

# Test image processing (should work for allowed formats)
convert test.png -resize 100x100 output.png

# Test blocked format (should fail)
convert test.pdf output.png  # Should error if PDF is blocked

# Check ImageMagick version
convert -version
```

## Common Issues

### "Coder not permitted" errors

If you get "Coder not permitted" for a format you need:
1. Check the format name is uppercase in the policy
2. Verify the policy file is being loaded (check with `identify -list policy`)
3. Ensure your policy is loaded after any default policies

### Policy not taking effect

1. Find all policy.xml files: `find / -iname policy.xml`
2. Check which one ImageMagick is using
3. Ensure your restrictive policy is in the correct location
4. Restart any services using ImageMagick

### Case sensitivity bugs

If `pattern="{GIF,JPEG}"` doesn't work but `pattern="{gif,jpeg}"` does, you may have an older ImageMagick version. Upgrade to 6.9.7-7+ for proper allowlist support.

## Testing Your Configuration

1. **Create test images** in allowed formats (PNG, JPEG, GIF, WEBP)
2. **Try to process** each format - should work
3. **Try blocked formats** (PDF, SVG, PS) - should fail with permission error
4. **Test resource limits** - try to process a very large image
5. **Verify with** `identify -list policy`

## Using the Doyensec Evaluator

The [ImageMagick Security Policy Evaluator](https://imagemagick-secevaluator.doyensec.com/) can:
- Analyze your policy for gaps
- Suggest improvements
- Check for common misconfigurations

Upload your policy.xml to get automated feedback.

## References

- [Doyensec ImageMagick Security Policy Evaluator](https://blog.doyensec.com/2023/01/10/imagemagick-security-policy-evaluator.html)
- [ImageMagick Security Policy Documentation](https://imagemagick.org/script/security-policy.php)
- [ImageMagick Policy.xml Reference](https://imagemagick.org/script/command-line-options.php#policy)

## When to Use This Skill

Use this skill when:
- Setting up ImageMagick on a new server
- Reviewing existing ImageMagick configurations
- Investigating ImageMagick-related security incidents
- Hardening image processing services
- Auditing policy.xml files
- Responding to ImageMagick CVEs
- Configuring image upload features securely
