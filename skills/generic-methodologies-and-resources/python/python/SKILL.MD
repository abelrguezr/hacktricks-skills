---
name: python-security-research
description: How to research and understand Python security vulnerabilities including sandbox escapes, deserialization attacks, and Pyscript exploitation. Use this skill whenever the user mentions Python security, sandbox bypass, deserialization vulnerabilities, Pyscript hacking, Keras model attacks, or needs to understand Python-based attack vectors for security research, penetration testing, or defensive analysis.
---

# Python Security Research & Analysis

A skill for understanding and researching Python-based security vulnerabilities, sandbox escape techniques, and deserialization attacks.

## When to Use This Skill

Use this skill when:
- Researching Python sandbox escape techniques for security assessments
- Analyzing deserialization vulnerabilities in Python applications
- Investigating Pyscript security issues in web applications
- Understanding Keras model deserialization RCE risks
- Learning Python web request patterns for security testing
- Conducting defensive security analysis of Python codebases
- Preparing for security certifications or training

## Core Concepts

### Python Sandbox Escapes

Python sandboxes are often used to restrict code execution, but they can be bypassed through various techniques:

**Common bypass vectors:**
- Import restrictions can be circumvented via `__import__` or `importlib`
- Built-in function restrictions may be bypassed through `__builtins__` manipulation
- File system access can sometimes be gained through `open()` or `exec()`
- Network access restrictions may be bypassed via `socket` or `urllib`

**Research approach:**
1. Identify the sandbox implementation (restricted python, custom sandbox, etc.)
2. Enumerate available builtins and modules
3. Test for common bypass techniques
4. Document findings for remediation

### Deserialization Vulnerabilities

Python's pickle module and similar serialization mechanisms are inherently unsafe:

**Key risks:**
- Arbitrary code execution through crafted pickle payloads
- Gadget chains in standard library and third-party packages
- Keras model files can contain malicious deserialization code
- YAML, JSON, and other formats may have similar issues

**Research methodology:**
1. Identify serialization points in the application
2. Determine the serialization format (pickle, YAML, etc.)
3. Research known gadget chains for the Python version
4. Test with controlled payloads in isolated environments
5. Document remediation strategies

### Pyscript Security

Pyscript allows Python execution in browsers, introducing unique attack vectors:

**Security considerations:**
- Client-side code execution risks
- Cross-origin resource sharing implications
- Data exfiltration through browser APIs
- Integration with web application security

**Analysis approach:**
1. Review Pyscript configuration and restrictions
2. Identify data flow between Python and JavaScript
3. Test for privilege escalation vectors
4. Assess impact of compromised Pyscript execution

### Keras Model Deserialization

Keras model files (.h5, .keras) can contain malicious code:

**Attack surface:**
- Custom objects in model definitions
- Lambda functions with arbitrary code
- Callbacks that execute on load
- Layer configurations with code execution

**Defensive measures:**
- Validate model sources before loading
- Use `custom_objects` parameter to restrict imports
- Implement model signing and verification
- Run model loading in isolated environments

## Research Workflow

### Phase 1: Reconnaissance

1. **Identify the target**: What Python application or system are you analyzing?
2. **Determine the context**: Is this a sandbox, web application, data pipeline, or ML system?
3. **Gather information**: Python version, installed packages, configuration files
4. **Map the attack surface**: Entry points, data flows, trust boundaries

### Phase 2: Analysis

1. **Review code**: Look for deserialization, exec/eval, import statements
2. **Test restrictions**: If sandboxed, enumerate what's available
3. **Research vulnerabilities**: Check CVE databases, security advisories
4. **Document findings**: Create a structured report of potential issues

### Phase 3: Validation

1. **Create test cases**: Develop controlled test scenarios
2. **Execute safely**: Use isolated environments (containers, VMs)
3. **Verify impact**: Confirm the vulnerability exists and understand scope
4. **Document remediation**: Provide actionable fixes

### Phase 4: Reporting

1. **Summarize findings**: Clear description of each vulnerability
2. **Assess severity**: Use CVSS or similar framework
3. **Provide remediation**: Specific code changes and configurations
4. **Include references**: Link to relevant security resources

## Safety Guidelines

**Always follow these principles:**

1. **Authorization**: Only test systems you have explicit permission to assess
2. **Isolation**: Run all testing in isolated environments (containers, VMs)
3. **Documentation**: Keep detailed records of all testing activities
4. **Disclosure**: Report vulnerabilities responsibly to affected parties
5. **Legal compliance**: Understand and follow applicable laws and regulations

## Common Tools & Resources

**For research and testing:**
- `pickle` module analysis tools
- Python sandbox testing frameworks
- Static analysis tools (Bandit, Pylint)
- Dynamic analysis (strace, ltrace)
- Network analysis (Wireshark, tcpdump)

**For learning:**
- OWASP Python Security Cheat Sheet
- Python Security Best Practices
- CVE databases for Python-related vulnerabilities
- Security research blogs and conferences

## Output Format

When providing security research results, use this structure:

```
## Vulnerability Analysis

### Finding: [Brief description]

**Severity**: [Critical/High/Medium/Low]

**Location**: [File/Function/Component]

**Description**: [Detailed explanation]

**Proof of Concept**: [Safe, controlled example if applicable]

**Impact**: [What an attacker could achieve]

**Remediation**: [Specific fixes]

**References**: [Links to relevant resources]
```

## Example Scenarios

### Scenario 1: Analyzing a Python Sandbox

**Input**: "I need to understand how to test this Python sandbox for escape vectors"

**Approach**:
1. Identify the sandbox implementation
2. Enumerate available builtins and modules
3. Test common bypass techniques
4. Document findings and remediation

### Scenario 2: Deserialization Risk Assessment

**Input**: "This application loads pickle files from user uploads"

**Approach**:
1. Identify all deserialization points
2. Assess input validation and sanitization
3. Research known gadget chains
4. Recommend safer alternatives (JSON, msgpack)

### Scenario 3: Pyscript Security Review

**Input**: "We're using Pyscript in our web app, what should I check?"

**Approach**:
1. Review Pyscript configuration
2. Analyze data flow between Python and JavaScript
3. Test for privilege escalation
4. Recommend security hardening

## Next Steps

After initial research:
1. **Deep dive**: Focus on specific vulnerabilities found
2. **Tool development**: Create custom testing tools if needed
3. **Team training**: Share findings with development teams
4. **Continuous monitoring**: Set up alerts for new vulnerabilities

## Important Notes

- This skill is for **educational and defensive purposes**
- Always obtain proper authorization before testing
- Document all findings for remediation
- Stay updated on new Python security research
- Consider the broader security context, not just Python-specific issues
