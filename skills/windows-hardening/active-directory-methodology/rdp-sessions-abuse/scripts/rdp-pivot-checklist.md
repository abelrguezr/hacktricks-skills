# RDP Pivot Checklist

## Pre-Engagement
- [ ] Written authorization obtained
- [ ] RDP testing in scope
- [ ] Target environment documented
- [ ] Legal review completed

## Reconnaissance
- [ ] Identify external user groups with RDP access
- [ ] Map RDP-accessible machines
- [ ] Document RDP policies (GPO)
- [ ] Check for RDP gateway configurations

## Execution
- [ ] Compromise RDP-accessible machine
- [ ] Monitor for external user connections (`net logons`)
- [ ] Identify RDP process (rdpclip.exe, mstsc.exe)
- [ ] Inject beacon into RDP process
- [ ] Verify external domain access
- [ ] Check for mounted drives (`\\tsclient\\`)
- [ ] Document pivot path and permissions

## Post-Exploitation
- [ ] Test lateral movement capabilities
- [ ] Assess credential access opportunities
- [ ] Document persistence options
- [ ] Clean up (if required by engagement)

## Reporting
- [ ] Risk level: HIGH
- [ ] Include remediation recommendations
- [ ] Document detection signatures
- [ ] Provide timeline of activities

## Remediation Recommendations
- [ ] Restrict RDP access to minimum users
- [ ] Disable drive redirection in RDP policies
- [ ] Implement network segmentation
- [ ] Enable RDP gateway with MFA
- [ ] Monitor RDP session creation
- [ ] Audit process injection attempts
