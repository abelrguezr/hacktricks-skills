---
name: python-venv
description: How to create, activate, and manage Python virtual environments. Use this skill whenever the user needs to set up an isolated Python environment, install packages in a clean environment, or troubleshoot venv-related issues. Make sure to use this skill when users mention virtual environments, venv, python environments, package isolation, or need to install Python libraries without affecting the system Python.
---

# Python Virtual Environment (venv)

This skill helps you create and manage isolated Python virtual environments.

## Creating a Virtual Environment

### Step 1: Install venv (if needed)

On Debian/Ubuntu systems, install the venv module:

```bash
sudo apt-get install python3-venv
```

### Step 2: Create the environment

Navigate to your project directory, then create the venv:

```bash
python3 -m venv <environment-name>
```

**Example:**
```bash
python3 -m venv pvenv
```

This creates a folder called `pvenv` containing your isolated environment.

### Step 3: Activate the environment

```bash
source <environment-name>/bin/activate
```

**Example:**
```bash
source pvenv/bin/activate
```

Your shell prompt will change to show the environment is active (typically prefixed with the environment name).

### Step 4: Install packages

Now you can install Python packages without affecting your system Python:

```bash
pip install <package-name>
```

### Step 5: Deactivate when done

```bash
deactivate
```

## Common Issues

### Error: `invalid command 'bdist_wheel'`

If you encounter this error when installing packages:

```
error: invalid command 'bdist_wheel'
```

Fix it by running inside your virtual environment:

```bash
pip3 install wheel
```

## Best Practices

- **Create a venv for each project** to keep dependencies isolated
- **Add the venv folder to `.gitignore`** to avoid committing it
- **Use descriptive names** for your environments (e.g., `project-venv`, `data-analysis-env`)
- **Activate before installing** any packages to ensure they go into the right environment

## Quick Reference

| Action | Command |
|--------|--------|
| Create venv | `python3 -m venv <name>` |
| Activate | `source <name>/bin/activate` |
| Deactivate | `deactivate` |
| Install package | `pip install <package>` |
| Fix bdist_wheel error | `pip3 install wheel` |
