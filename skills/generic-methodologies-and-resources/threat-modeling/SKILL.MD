---
name: threat-modeling
description: Create comprehensive threat models for applications and systems using established methodologies like STRIDE, DREAD, and PASTA. Use this skill whenever the user needs to identify security vulnerabilities, assess system risks, create data flow diagrams, or document potential threats and mitigations. Trigger for any request involving security architecture review, vulnerability assessment, attack surface analysis, or security planning for software projects.
---

# Threat Modeling Skill

This skill helps you systematically identify, analyze, and document security threats in applications and systems using industry-standard methodologies.

## When to Use This Skill

Use this skill when:
- A user asks to create or review a threat model for an application or system
- You need to identify potential security vulnerabilities in a design or architecture
- The user wants to assess attack surface or security risks
- You're asked to document threats and mitigations for a project
- Security architecture review is requested
- The user mentions STRIDE, DREAD, PASTA, or other threat modeling methodologies

## Core Concepts

### The CIA Triad

All threat modeling should consider these three security pillars:

1. **Confidentiality**: Is data protected from unauthorized access? Consider encryption, access controls, authentication.
2. **Integrity**: Is data protected from unauthorized modification? Consider checksums, hashing, validation.
3. **Availability**: Are systems accessible when needed? Consider redundancy, fault tolerance, DDoS protection.

### Threat Modeling Methodologies

#### STRIDE (Primary Methodology)

Use STRIDE to categorize threats during the design phase:

| Category | Description | Example |
|----------|-------------|----------|
| **S**poofing | Impersonating another user or system | Fake login credentials, API key theft |
| **T**ampering | Unauthorized modification of data | SQL injection, file modification |
| **R**epudiation | Denying actions were performed | Missing audit logs, no transaction records |
| **I**nformation Disclosure | Exposing sensitive data | Data leaks, improper error messages |
| **D**enial of Service | Making services unavailable | Resource exhaustion, DDoS attacks |
| **E**levation of Privilege | Gaining unauthorized access levels | Privilege escalation, admin access abuse |

#### DREAD (Risk Scoring)

Use DREAD to prioritize identified threats:

| Factor | Description | Score (1-10) |
|--------|-------------|---------------|
| **D**amage Potential | Impact if threat is realized | |
| **R**eproducibility | How easily can it be reproduced | |
| **E**xploitability | How easy is it to exploit | |
| **A**ffected Users | How many users are impacted | |
| **D**iscoverability | How easy is it to find the vulnerability | |

Calculate: `(D + R + E + A + D) / 5` for overall risk score.

#### PASTA (Process for Attack Simulation and Threat Analysis)

Seven-step risk-centric methodology:
1. Define security objectives
2. Define technical scope
3. Application decomposition
4. Threat analysis
5. Vulnerability analysis
6. Risk assessment
7. Risk triage and mitigation

## Threat Modeling Process

### Step 1: Define Scope and Objectives

Ask the user:
- What system/application are we modeling?
- What are the security objectives (confidentiality, integrity, availability priorities)?
- Who are the users and what data is involved?
- What are the trust boundaries (internal/external networks, third-party services)?

### Step 2: Create Data Flow Diagram

Document the system architecture with these elements:

| Element | Description | Example |
|---------|-------------|----------|
| **Process** | System component or functionality | Web server, API endpoint, database |
| **Actor** | User or external system | Website visitor, admin, payment gateway |
| **Data Flow** | Information movement between components | User credentials, API requests |
| **Store** | Data storage locations | Database, file system, cache |
| **Trust Boundary** | Security perimeter | Network segments, firewall boundaries |

### Step 3: Identify Threats Using STRIDE

For each component in your diagram, ask:

**For Processes:**
- Can this be spoofed? (Authentication/Authorization)
- Can data be tampered with? (Input validation, encryption)
- Can actions be repudiated? (Logging, audit trails)
- Can information be disclosed? (Data protection, access controls)
- Can this be denied? (Rate limiting, resource management)
- Can privileges be elevated? (Access control, privilege separation)

**For Data Flows:**
- Is data encrypted in transit?
- Is data integrity verified?
- Are there replay attack protections?

**For Stores:**
- Is data encrypted at rest?
- Are access controls properly configured?
- Is backup/recovery in place?

**For Actors:**
- Is authentication strong enough?
- Are permissions properly scoped?
- Can actions be attributed?

### Step 4: Assess and Prioritize Risks

For each identified threat:
1. Apply DREAD scoring (1-10 for each factor)
2. Calculate overall risk score
3. Categorize as High (>7), Medium (4-7), or Low (<4)
4. Document mitigation strategies

### Step 5: Document Mitigations

For each threat, specify:
- **Mitigation**: How to prevent or reduce the threat
- **Residual Risk**: Risk remaining after mitigation
- **Owner**: Who is responsible for implementation
- **Timeline**: When should it be addressed

## Output Format

When creating a threat model, use this structure:

```
# Threat Model: [System Name]

## Overview
- **System**: [Description]
- **Date**: [Current Date]
- **Methodology**: [STRIDE/DREAD/PASTA]
- **Scope**: [What's included/excluded]

## Data Flow Diagram
[Describe or reference diagram with components, actors, data flows, stores, trust boundaries]

## Identified Threats

### [Component Name]

| Threat ID | STRIDE Category | Description | DREAD Score | Risk Level | Mitigation |
|-----------|-----------------|-------------|-------------|------------|------------|
| T-001 | Spoofing | [Description] | X.X | High/Med/Low | [Mitigation] |

## Risk Summary
- **High Risk**: [Count] threats
- **Medium Risk**: [Count] threats  
- **Low Risk**: [Count] threats

## Recommendations
1. [Priority action]
2. [Priority action]
3. [Priority action]
```

## Tools to Recommend

### OWASP Threat Dragon
- **Best for**: Visual threat modeling, collaborative work
- **Features**: System diagramming, auto-generated threats/mitigations
- **Use when**: User needs visual diagrams or team collaboration
- **Link**: https://github.com/OWASP/threat-dragon

### Microsoft Threat Modeling Tool
- **Best for**: Microsoft stack, STRIDE methodology
- **Features**: Built-in STRIDE analysis, mitigation suggestions
- **Use when**: User is developing on Microsoft technologies
- **Link**: https://aka.ms/threatmodelingtool

### SpiderSuite
- **Best for**: Attack surface mapping, web application analysis
- **Features**: Web crawling, graph visualization
- **Use when**: User needs to map external attack surface
- **Link**: https://github.com/3nock/SpiderSuite

## Common Threat Patterns

### Authentication & Authorization
- Weak password policies
- Missing MFA
- Session fixation
- Broken access control
- Privilege escalation

### Data Protection
- Unencrypted sensitive data
- Insecure data transmission
- Improper error handling exposing data
- Insufficient logging

### Input Validation
- SQL injection
- XSS (Cross-Site Scripting)
- Command injection
- Path traversal
- Buffer overflow

### Infrastructure
- Misconfigured cloud services
- Unpatched vulnerabilities
- Insecure APIs
- Third-party dependencies

## Example Threat Model

**Input**: "Create a threat model for our e-commerce API that handles user accounts and payments"

**Output Structure**:

```
# Threat Model: E-Commerce API

## Overview
- **System**: REST API for e-commerce platform
- **Methodology**: STRIDE + DREAD
- **Scope**: User authentication, product catalog, shopping cart, payment processing

## Data Flow Diagram
- **Actors**: Customer, Admin, Payment Gateway, Inventory System
- **Processes**: Auth Service, Product API, Cart Service, Payment Processor
- **Stores**: User DB, Product DB, Order DB, Session Store
- **Trust Boundaries**: Public Internet, Internal Network, PCI-DSS Zone

## Identified Threats

### Authentication Service

| Threat ID | STRIDE | Description | DREAD | Risk | Mitigation |
|-----------|--------|-------------|-------|------|------------|
| T-001 | Spoofing | Brute force login attacks | 7.2 | High | Rate limiting, MFA, account lockout |
| T-002 | Info Disclosure | Password hash exposure | 6.8 | High | bcrypt/scrypt hashing, salt |
| T-003 | Repudiation | No login audit trail | 5.5 | Medium | Comprehensive logging |

### Payment Processor

| Threat ID | STRIDE | Description | DREAD | Risk | Mitigation |
|-----------|--------|-------------|-------|------|------------|
| T-004 | Tampering | Payment amount modification | 8.5 | High | Server-side validation, HMAC |
| T-005 | Info Disclosure | PCI data exposure | 9.0 | High | Tokenization, PCI compliance |

## Risk Summary
- **High Risk**: 3 threats
- **Medium Risk**: 2 threats
- **Low Risk**: 1 threat

## Recommendations
1. Implement MFA for all user accounts (High priority)
2. Ensure PCI-DSS compliance for payment handling (High priority)
3. Add comprehensive audit logging (Medium priority)
4. Deploy WAF for injection protection (Medium priority)
5. Regular security assessments (Ongoing)
```

## Best Practices

1. **Start Early**: Threat model during design, not after implementation
2. **Iterate**: Update threat models as the system evolves
3. **Involve Stakeholders**: Get input from developers, security, and operations
4. **Focus on High Risk**: Prioritize threats with highest DREAD scores
5. **Document Everything**: Maintain threat model as living documentation
6. **Test Mitigations**: Verify controls work through penetration testing
7. **Review Regularly**: Re-assess threats quarterly or after major changes

## Questions to Ask Users

Before creating a threat model, gather:
1. What system/application are we modeling?
2. What data does it handle (PII, financial, health, etc.)?
3. Who are the users and what are their roles?
4. What integrations or third-party services exist?
5. What compliance requirements apply (GDPR, HIPAA, PCI-DSS)?
6. What's the deployment environment (cloud, on-prem, hybrid)?
7. Are there existing security controls in place?
8. What's the risk tolerance for this system?
