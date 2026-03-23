#!/bin/bash
# Forensic Report Template Generator
# Creates a structured markdown report for forensic investigations

set -e

REPORT_NAME="${1:-forensic_report}"
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

cat << EOF
# Forensic Investigation Report

**Report ID:** ${REPORT_NAME}_$(date +%Y%m%d_%H%M%S)
**Generated:** ${TIMESTAMP}
**Analyst:** [Your Name]
**Case Reference:** [Case Number]

---

## Executive Summary

[Brief overview of the investigation, key findings, and recommendations]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Risk Assessment
- **Severity:** [Low/Medium/High/Critical]
- **Confidence:** [Low/Medium/High]

---

## Investigation Details

### Scope
- **Evidence Type:** [Disk Image/Memory Dump/PCAP/Other]
- **Platform:** [Windows/Linux/macOS/Other]
- **Time Period:** [Start Date] to [End Date]

### Tools Used
| Tool | Version | Purpose |
|------|---------|----------|
| [Tool Name] | [Version] | [Purpose] |

### Methodology
[Description of forensic procedures followed]

---

## Evidence Analysis

### Evidence Inventory
| Evidence ID | Type | Hash (SHA256) | Size | Acquisition Date |
|-------------|------|---------------|------|------------------|
| [ID] | [Type] | [Hash] | [Size] | [Date] |

### Findings by Category

#### 1. File System Analysis
[Findings from file system examination]

#### 2. Timeline Analysis
[Key events and their timestamps]

#### 3. Network Activity
[Network-related findings]

#### 4. Malware Indicators
[Malware-related findings if applicable]

#### 5. User Activity
[User behavior and activity findings]

---

## Technical Details

### Commands Executed
\`\`\`bash
[Key commands used during analysis]
\`\`\`

### Artifacts Extracted
[List of important artifacts found]

### Hash Values
\`\`\`
MD5:    [Value]
SHA1:   [Value]
SHA256: [Value]
\`\`\`

---

## Conclusions

### Summary of Findings
[Detailed summary of what was discovered]

### Indicators of Compromise (IOCs)
| Type | Value | Context |
|------|-------|----------|
| [IP/Domain/File Hash] | [Value] | [Context] |

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## Appendices

### A. Chain of Custody
[Chain of custody documentation]

### B. Raw Data Extracts
[Important raw data for reference]

### C. Tool Outputs
[Relevant tool output excerpts]

---

**Report End**

*This report contains sensitive forensic information. Handle according to organizational policies.*
EOF

echo ""
echo "Report template created. Save output to: ${REPORT_NAME}.md"
