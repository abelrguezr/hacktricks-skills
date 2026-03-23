---
name: ai-risk-assessment
description: How to assess and document AI security risks using industry frameworks. Use this skill whenever the user mentions AI security, ML vulnerabilities, model risks, LLM security, adversarial attacks, data poisoning, prompt injection, or needs to evaluate AI system safety. Trigger for any request about AI threat modeling, security audits, risk documentation, or compliance with AI security standards.
---

# AI Risk Assessment Framework

This skill helps you assess and document security risks in AI/ML systems using industry-standard frameworks: OWASP Top 10 ML, Google SAIF, MITRE ATLAS, and LLMJacking patterns.

## When to Use This Skill

Use this skill when:
- You need to identify security vulnerabilities in an AI/ML system
- You're conducting a security audit or threat modeling session
- You need to document AI risks for compliance or stakeholder review
- You're designing security controls for an AI system
- You want to understand specific attack vectors (prompt injection, data poisoning, model theft, etc.)
- You need mitigation strategies for identified AI risks

## Quick Reference: Risk Frameworks

### OWASP Top 10 ML Vulnerabilities

| # | Vulnerability | What It Is | Example |
|---|---------------|------------|--------|
| 1 | Input Manipulation | Tiny changes to input data fool the model | Paint specks on stop sign → speed limit sign |
| 2 | Data Poisoning | Training data polluted with bad samples | Malware labeled as benign in antivirus training |
| 3 | Model Inversion | Reconstruct sensitive inputs from outputs | Rebuild patient MRI from cancer model predictions |
| 4 | Membership Inference | Detect if specific record was in training | Confirm bank transaction in fraud model training data |
| 5 | Model Theft | Clone model behavior via repeated queries | Harvest Q&A pairs to build equivalent local model |
| 6 | AI Supply-Chain | Compromise ML pipeline components | Poisoned dependency installs backdoored model |
| 7 | Transfer Learning Attack | Malicious logic survives fine-tuning | Vision backbone with hidden trigger persists after adaptation |
| 8 | Model Skewing | Biased data shifts outputs to attacker's agenda | Spam emails labeled as ham to bypass filter |
| 9 | Output Integrity | Alter predictions in transit | Flip "malicious" verdict to "benign" before quarantine |
| 10 | Model Poisoning | Direct changes to model parameters | Tweak fraud detection weights to approve certain cards |

### Google SAIF Risks

| Risk | Description |
|------|-------------|
| Data Poisoning | Malicious actors alter training/tuning data to degrade accuracy or implant backdoors |
| Unauthorized Training Data | Ingesting copyrighted, sensitive, or unpermitted datasets creates legal/ethical liabilities |
| Model Source Tampering | Supply-chain manipulation embeds hidden logic that persists after retraining |
| Excessive Data Handling | Weak retention controls store more personal data than necessary |
| Model Exfiltration | Attackers steal model files/weights, causing IP loss |
| Model Deployment Tampering | Adversaries modify model artifacts so running model differs from vetted version |
| Denial of ML Service | Flooding APIs or "sponge" inputs exhaust compute and knock model offline |
| Model Reverse Engineering | Harvesting input-output pairs to clone or distil the model |
| Insecure Integrated Component | Vulnerable plugins/agents let attackers inject code or escalate privileges |
| Prompt Injection | Crafting prompts to override system intent and perform unintended commands |
| Model Evasion | Designed inputs trigger mis-classification, hallucination, or disallowed content |
| Sensitive Data Disclosure | Model reveals private/confidential information from training or user context |
| Inferred Sensitive Data | Model deduces personal attributes never provided, creating privacy harms |
| Insecure Model Output | Unsanitized responses pass harmful code, misinformation, or inappropriate content |
| Rogue Actions | Autonomous agents execute unintended real-world operations without oversight |

### MITRE AI ATLAS Matrix

The MITRE ATLAS Matrix provides a comprehensive framework for understanding AI attack techniques and tactics. It covers:
- How adversaries attack AI models
- How adversaries use AI systems to perform attacks

Reference: https://atlas.mitre.org/matrices/ATLAS

### LLMJacking (Token Theft & Resale)

**What it is:** Attackers steal active session tokens or cloud API credentials and invoke paid, cloud-hosted LLMs without authorization. Access is resold via reverse proxies.

**Consequences:**
- Financial loss from unauthorized usage
- Model misuse outside policy
- Attribution to victim tenant

**TTPs (Tactics, Techniques, Procedures):**
- Harvest tokens from infected developer machines or browsers
- Steal CI/CD secrets; buy leaked cookies
- Stand up reverse proxy that forwards requests to genuine provider
- Abuse direct base-model endpoints to bypass enterprise guardrails

**Mitigations:**
- Bind tokens to device fingerprint, IP ranges, and client attestation
- Enforce short expirations and refresh with MFA
- Scope keys minimally (no tool access, read-only where applicable)
- Rotate keys on anomaly detection
- Terminate all traffic server-side behind a policy gateway
- Monitor for unusual usage patterns (spend spikes, atypical regions, UA strings)
- Prefer mTLS or signed JWTs over long-lived static API keys

## Assessment Workflow

### Step 1: Identify the System Type

Determine what kind of AI system you're assessing:
- **ML Model** (classification, regression, clustering)
- **LLM/GenAI** (chatbot, code assistant, content generator)
- **AI Pipeline** (data ingestion → training → deployment)
- **AI Agent** (autonomous system with tool access)

### Step 2: Map to Frameworks

Use the appropriate framework(s) based on system type:

| System Type | Primary Framework | Secondary Frameworks |
|-------------|-------------------|---------------------|
| ML Model | OWASP Top 10 ML | Google SAIF |
| LLM/GenAI | Google SAIF | OWASP Top 10 ML |
| AI Pipeline | MITRE ATLAS | OWASP Top 10 ML, Google SAIF |
| AI Agent | Google SAIF | MITRE ATLAS |
| Cloud LLM Access | LLMJacking patterns | Google SAIF |

### Step 3: Conduct Risk Assessment

For each relevant risk category:

1. **Identify** - Does this risk apply to your system?
2. **Assess** - What's the likelihood and impact?
3. **Document** - Record findings with evidence
4. **Mitigate** - Apply appropriate controls

### Step 4: Document Findings

Use this structure for risk documentation:

```
## Risk: [Risk Name]

**Framework:** [OWASP/SAIF/ATLAS/LLMJacking]

**Description:** [What the risk is]

**Applicability:** [Why it applies to this system]

**Likelihood:** [Low/Medium/High]

**Impact:** [Low/Medium/High]

**Evidence:** [Specific observations, test results, or analysis]

**Mitigation:** [Recommended controls]

**Status:** [Open/Mitigated/Accepted]
```

## Common Mitigation Patterns

### Data Security
- Implement data validation and sanitization at ingestion
- Use differential privacy for training data
- Encrypt data at rest and in transit
- Implement access controls and audit logging
- Regular data quality audits

### Model Security
- Model signing and integrity verification
- Secure model storage with access controls
- Model versioning and rollback capabilities
- Adversarial training and robustness testing
- Model output validation and filtering

### API Security
- Rate limiting and quota enforcement
- Input validation and prompt filtering
- Output sanitization
- Authentication and authorization
- Request/response logging

### Infrastructure Security
- Network segmentation for AI components
- Secure CI/CD pipelines
- Dependency scanning and verification
- Container security for model serving
- Monitoring and alerting

## Quick Assessment Checklist

Use this checklist for rapid risk identification:

- [ ] Are training data sources verified and authorized?
- [ ] Is there input validation on all model inputs?
- [ ] Are model outputs sanitized before use?
- [ ] Are API keys and credentials properly secured?
- [ ] Is there rate limiting on model endpoints?
- [ ] Are there monitoring and alerting for anomalous behavior?
- [ ] Is there a process for model versioning and rollback?
- [ ] Are dependencies scanned for vulnerabilities?
- [ ] Is there access control on model artifacts?
- [ ] Are there safeguards against prompt injection (for LLMs)?
- [ ] Is there protection against model theft/exfiltration?
- [ ] Are there controls to prevent rogue agent actions?

## Next Steps

After completing your assessment:

1. **Prioritize** risks by likelihood and impact
2. **Create** a remediation plan with timelines
3. **Implement** mitigations in order of priority
4. **Test** that mitigations are effective
5. **Document** the security posture for stakeholders
6. **Schedule** regular reassessments (quarterly recommended)

## References

- [OWASP Top 10 Machine Learning Security](https://owasp.org/www-project-machine-learning-security-top-10/)
- [Google SAIF - Secure AI Framework](https://saif.google/secure-ai-framework/risks)
- [MITRE ATLAS Matrix](https://atlas.mitre.org/matrices/ATLAS)
- [Unit 42 – The Risks of Code Assistant LLMs](https://unit42.paloaltonetworks.com/code-assistant-llms/)
- [LLMJacking scheme overview](https://thehackernews.com/2024/05/researchers-uncover-llmjacking-scheme.html)
