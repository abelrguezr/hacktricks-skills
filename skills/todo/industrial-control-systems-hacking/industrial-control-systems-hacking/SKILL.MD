---
name: ics-security-assessment
description: Industrial Control Systems (ICS) security assessment and analysis. Use this skill whenever the user needs to understand ICS architecture, perform security assessments on industrial control systems, identify vulnerabilities in SCADA/PLC environments, or learn about ICS security concepts. Trigger for any request involving industrial automation security, OT security, ICS reconnaissance, PLC security, SCADA analysis, or industrial network security assessments. Also use when users ask about protecting ICS environments or blue teaming for industrial systems.
---

# Industrial Control Systems (ICS) Security Assessment

A comprehensive skill for understanding, assessing, and securing Industrial Control Systems including SCADA, PLCs, and industrial automation environments.

## When to Use This Skill

Use this skill when:
- Analyzing ICS/SCADA/PLC security architecture
- Planning security assessments for industrial environments
- Identifying vulnerabilities in industrial control systems
- Learning about ICS protocols and components
- Developing ICS security hardening strategies
- Understanding OT (Operational Technology) security concepts
- Performing reconnaissance on industrial networks
- Blue teaming or defending ICS environments

## Core Concepts

### What are Industrial Control Systems?

ICS are specialized systems that control industrial processes. They're critical infrastructure found in:
- Manufacturing plants
- Power generation and distribution
- Water treatment facilities
- Oil and gas pipelines
- Transportation systems
- Building automation

### Key Characteristics

- **Legacy protocols**: Many protocols developed in the 1990s with minimal security
- **Hard to update**: Systems often run for decades without patches
- **Safety-critical**: Failures can cause physical damage or loss of life
- **Air-gapped (sometimes)**: Often isolated from corporate networks, but increasingly connected
- **Real-time requirements**: Latency matters more than security in many cases

## ICS Architecture Components

### 1. SCADA (Supervisory Control and Data Acquisition)

**Purpose**: Central monitoring and control system

**Components**:
- Master Terminal Units (MTU) / Master Control Stations (MCS)
- Human-Machine Interfaces (HMI)
- Remote Terminal Units (RTU)
- Communication infrastructure

**Common vendors**: Siemens, Schneider Electric, Rockwell Automation, GE, Honeywell

### 2. PLC (Programmable Logic Controllers)

**Purpose**: Execute control logic for industrial processes

**Characteristics**:
- Ruggedized for industrial environments
- Deterministic execution
- Often run proprietary operating systems
- Communication via industrial protocols

**Common vendors**: Siemens (S7 series), Allen-Bradley, Mitsubishi, Omron

### 3. DCS (Distributed Control Systems)

**Purpose**: Control complex processes across multiple locations

**Use cases**: Chemical plants, refineries, large manufacturing

### 4. RTU (Remote Terminal Units)

**Purpose**: Collect data from remote locations and execute control commands

**Common in**: Pipeline monitoring, water distribution, remote substations

## Common ICS Protocols

### Proprietary Protocols

| Protocol | Vendor | Port | Description |
|----------|--------|------|-------------|
| S7comm | Siemens | 102 | PLC communication |
| Modbus TCP | Multiple | 502 | Industrial automation |
| DNP3 | Multiple | 20000 | Utility automation |
| BACnet | Multiple | 47808 | Building automation |
| CIP/Ethernet/IP | Rockwell | 44818 | Industrial networking |

### Key Security Concerns

- **No authentication**: Most protocols lack built-in authentication
- **No encryption**: Traffic typically sent in cleartext
- **No integrity checking**: Packets can be modified in transit
- **Broadcast vulnerabilities**: Many protocols use broadcast/multicast

## Security Assessment Methodology

### Phase 1: Information Gathering

**Objective**: Understand the target environment before any testing

**Activities**:
1. **Document review**
   - Network diagrams
   - Equipment lists
   - Protocol documentation
   - Maintenance records

2. **Passive reconnaissance**
   - Identify ICS devices from network scans
   - Map protocol usage
   - Document vendor and model information
   - Identify firmware versions

3. **Network segmentation analysis**
   - Identify Purdue Model layers
   - Map network boundaries
   - Document firewall rules
   - Identify DMZ configurations

**Important**: Always obtain explicit written authorization before scanning or testing ICS environments. Unauthorized testing can cause physical damage or safety incidents.

### Phase 2: Vulnerability Identification

**Common ICS Vulnerabilities**:

1. **Default credentials**
   - Many devices ship with default passwords
   - Credentials often documented in manuals
   - Rarely changed in field deployments

2. **Unpatched systems**
   - Legacy operating systems (Windows XP, 7)
   - Outdated firmware
   - Known CVEs in ICS software

3. **Insecure protocols**
   - Cleartext communication
   - No authentication
   - No encryption

4. **Network exposure**
   - ICS devices accessible from corporate network
   - Internet-facing ICS components
   - Inadequate segmentation

5. **Physical security**
   - Unsecured access to control panels
   - USB ports accessible to unauthorized personnel
   - Console ports exposed

### Phase 3: Risk Assessment

**Consider**:
- **Safety impact**: Could exploitation cause physical harm?
- **Operational impact**: Would exploitation stop production?
- **Recovery time**: How long to restore operations?
- **Regulatory requirements**: Industry-specific compliance needs

**Risk Matrix**:

| Impact | Likelihood | Risk Level |
|--------|------------|------------|
| High | High | Critical |
| High | Medium | High |
| High | Low | Medium |
| Medium | High | High |
| Medium | Medium | Medium |
| Low | Any | Low |

### Phase 4: Testing (If Authorized)

**Safe Testing Practices**:

1. **Work with operators**
   - Coordinate timing with maintenance windows
   - Have operators present during testing
   - Establish emergency stop procedures

2. **Start passive**
   - Monitor traffic before sending packets
   - Understand normal behavior patterns
   - Document baseline metrics

3. **Test in isolation**
   - Use lab environments when possible
   - Test on non-production systems first
   - Have rollback procedures ready

4. **Limit scope**
   - Test specific functions, not entire systems
   - Avoid commands that could affect operations
   - Never test during critical operations

**Tools for ICS Security**:

| Tool | Purpose | Notes |
|------|---------|-------|
| Wireshark | Protocol analysis | ICS protocol dissectors |
| Modbus Poll/Slave | Modbus testing | Read/write testing |
| S7Comm tools | Siemens PLC | PLCread, S7Scan |
| Grapl | ICS monitoring | Anomaly detection |
| Cymulate | ICS simulation | Lab environment |
| Dragos | ICS threat intel | Commercial |

## Defense and Hardening

### Network Security

1. **Segmentation**
   - Implement Purdue Model architecture
   - Separate OT from IT networks
   - Use DMZs for cross-domain data transfer
   - Implement unidirectional gateways where possible

2. **Firewall Rules**
   - Default deny between zones
   - Allow only required protocols
   - Implement protocol-aware firewalls
   - Log all cross-zone traffic

3. **Monitoring**
   - Deploy ICS-aware IDS/IPS
   - Monitor for anomalous protocol behavior
   - Alert on unauthorized access attempts
   - Track configuration changes

### Device Security

1. **Access Control**
   - Change default credentials
   - Implement strong password policies
   - Use role-based access control
   - Enable multi-factor authentication where supported

2. **Configuration**
   - Disable unused services and ports
   - Remove default accounts
   - Implement secure boot where available
   - Document all configurations

3. **Physical Security**
   - Secure control rooms
   - Lock cabinets and panels
   - Control USB port access
   - Monitor physical access

### Operational Security

1. **Patch Management**
   - Test patches in lab before deployment
   - Coordinate with vendors for ICS-specific patches
   - Maintain patch records
   - Plan maintenance windows

2. **Incident Response**
   - Develop ICS-specific IR procedures
   - Train operators on security incidents
   - Establish communication protocols
   - Practice tabletop exercises

3. **Vendor Management**
   - Review vendor security practices
   - Require security documentation
   - Establish support SLAs
   - Maintain vendor contact information

## Common Attack Scenarios

### 1. Reconnaissance

**Techniques**:
- Network scanning for ICS devices
- Protocol fingerprinting
- Banner grabbing
- Traffic analysis

**Detection**:
- Monitor for unusual scan patterns
- Alert on protocol enumeration
- Track new device discoveries

### 2. Credential Attacks

**Techniques**:
- Default credential testing
- Password spraying
- Credential harvesting from backups
- Shoulder surfing in control rooms

**Prevention**:
- Change all default credentials
- Implement strong password policies
- Use network authentication
- Monitor for failed login attempts

### 3. Protocol Attacks

**Techniques**:
- Spoofing control commands
- Replay attacks
- Man-in-the-middle
- Denial of service on control channels

**Prevention**:
- Implement protocol authentication
- Use encryption where possible
- Deploy protocol-aware firewalls
- Monitor for anomalous commands

### 4. Supply Chain Attacks

**Techniques**:
- Compromised firmware updates
- Malicious vendor software
- Backdoors in development tools
- Compromised engineering workstations

**Prevention**:
- Verify firmware signatures
- Use trusted update channels
- Scan vendor software
- Isolate engineering workstations

## Compliance and Standards

### Relevant Frameworks

- **NIST SP 800-82**: Guide to ICS Security
- **IEC 62443**: Industrial Automation and Control Systems Security
- **NERC CIP**: North American Electric Reliability Corporation Critical Infrastructure Protection
- **ISA/IEC 62443**: International standards for ICS security

### Key Requirements

- Asset inventory and management
- Risk assessment
- Access control
- Incident response
- Continuous monitoring
- Vendor management

## Best Practices Summary

1. **Understand before you test**: Never test ICS without full understanding of the environment
2. **Get authorization**: Written permission is mandatory
3. **Work with operators**: They know the systems and safety requirements
4. **Start passive**: Monitor before interacting
5. **Test in lab first**: Validate techniques on non-production systems
6. **Document everything**: Record all findings and actions
7. **Prioritize safety**: Never compromise safety for security testing
8. **Plan for incidents**: Have response procedures ready
9. **Continuous improvement**: Regularly reassess and update security
10. **Train your team**: ICS security requires specialized knowledge

## When NOT to Use This Skill

- For general IT security assessments (use standard security skills)
- For non-ICS industrial equipment
- Without proper authorization
- For malicious purposes or unauthorized testing
- When safety could be compromised

## Resources

### Documentation
- NIST SP 800-82 Rev 2
- IEC 62443 series
- MITRE ATT&CK for ICS
- Dragos ICS threat reports

### Tools
- Wireshark with ICS dissectors
- Modbus tools (Modbus Poll, Modbus Slave)
- Siemens S7 tools
- Cymulate (commercial)
- Grapl (open source)

### Training
- SANS ICS410
- GIAC GICSP
- Vendor-specific training
- Industry conferences (ICS Security, S4)

## Important Safety Notice

**ICS security testing carries unique risks**:

- Unauthorized or improper testing can cause:
  - Equipment damage
  - Production stoppages
  - Safety incidents
  - Environmental damage
  - Loss of life

**Always**:
- Obtain written authorization
- Work with facility operators
- Test during maintenance windows
- Have emergency procedures ready
- Understand the physical processes being controlled
- Never test safety-critical systems without proper safeguards

This skill is intended for legitimate security professionals performing authorized assessments, blue teaming, and security research. Use responsibly.
