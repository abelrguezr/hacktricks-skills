---
name: linux-privilege-escalation
description: How to analyze and exploit Linux privilege escalation through user ID manipulation (ruid, euid, suid). Use this skill whenever the user mentions privilege escalation, SUID binaries, setuid/setreuid/setresuid functions, execve/system calls, or needs to understand how Linux user IDs work in security contexts. Make sure to use this skill for any Linux security analysis involving user identity, privilege boundaries, or binary execution mechanisms.
---

# Linux Privilege Escalation: User ID Manipulation

This skill helps you understand and analyze Linux privilege escalation vectors through user ID manipulation. It covers the core concepts of ruid, euid, suid, and how they interact with system calls and program execution.

## Core Concepts

### User Identification Variables

- **`ruid` (Real User ID)**: The user who initiated the process. This is the original user identity.
- **`euid` (Effective User ID)**: The identity the system uses to determine process privileges. Normally equals ruid, but can differ with SetUID binaries.
- **`suid` (Saved User ID)**: Preserves elevated privileges so a process can temporarily drop privileges and later restore them.

**Critical Rule**: A non-root process can only modify its `euid` to match its current `ruid`, `euid`, or `suid`.

### Understanding set*uid Functions

| Function | Behavior | Privilege Requirements |
|----------|----------|------------------------|
| `setuid(uid)` | Sets euid to uid. For privileged processes, also sets ruid and suid. | Root or CAP_SETUID for arbitrary values |
| `setreuid(ruid, euid)` | Sets both ruid and euid. | Root or CAP_SETUID for arbitrary values |
| `setresuid(ruid, euid, suid)` | Sets all three IDs. | Root or CAP_SETUID for arbitrary values |

**Key Insight**: `setuid` primarily modifies `euid`, not `ruid`. For privileged processes, it aligns all three IDs to the specified value.

### Program Execution Mechanisms

#### `execve` System Call

- Replaces the current process with a new program
- Preserves ruid, euid, and supplementary group IDs
- Updates suid from euid post-execution
- If the new program has SetUID bit set, euid may change

#### `system` Function

- Creates a child process via `fork`
- Executes command via `/bin/sh -c <command>`
- Behaves like `execve` but in a child process context

#### Bash and Sh Behavior with SUID

- **`bash` without `-p`**: Sets euid to ruid if they differ (drops privileges)
- **`bash -p`**: Preserves the initial euid (maintains privileges)
- **`sh`**: No `-p` equivalent; behavior varies by implementation

## Practical Analysis Framework

### Step 1: Identify the Execution Context

```bash
# Check current user IDs
id
# Output: uid=1000(user) gid=1000(user) euid=1000(user)

# Check SUID binaries
find / -perm -4000 -type f 2>/dev/null

# Check capabilities
getcap -r / 2>/dev/null
```

### Step 2: Analyze the Binary

When examining a SUID binary:

1. **Check ownership**: `ls -la /path/to/binary`
2. **Check permissions**: `stat /path/to/binary`
3. **Determine execution method**: Does it use `system()`, `execve()`, or direct calls?
4. **Check for privilege drops**: Look for `setuid()`, `setreuid()`, `setresuid()` calls

### Step 3: Understand the Privilege Flow

Use this decision tree:

```
Process starts with SUID bit set
    ↓
euid = file owner (often root)
    ↓
Does the binary call setuid/setreuid/setresuid?
    ├─ Yes → What values are set?
    │   ├─ setuid(1000) → euid becomes 1000, ruid/suid may follow
    │   └─ setreuid(1000, 1000) → both ruid and euid become 1000
    │
    └─ No → euid remains elevated
        ↓
Does it call system() or execve()?
    ├─ system() → spawns /bin/sh -c <cmd>
    │   └─ If sh→bash symlink: bash without -p drops euid to ruid
    │
    └─ execve() → preserves euid unless target has SUID
```

## Common Exploitation Patterns

### Pattern 1: setuid + system + bash

**Vulnerability**: When `setuid` is called but `system()` spawns bash without `-p`, privileges may be dropped.

**Example**:
```c
setuid(1000);  // Sets euid to 1000
system("id"); // Spawns bash, which drops euid to ruid
```

**Result**: If ruid was 99 (nobody), final euid becomes 99, not 1000.

### Pattern 2: setreuid + system

**Vulnerability**: `setreuid` sets both ruid and euid, so bash preserves them.

**Example**:
```c
setreuid(1000, 1000);  // Sets both ruid and euid to 1000
system("id");          // Bash sees ruid==euid, preserves both
```

**Result**: Process runs as uid=1000.

### Pattern 3: setuid + execve + bash -p

**Vulnerability**: Using `execve` with `bash -p` preserves the elevated euid.

**Example**:
```c
setuid(1000);
execve("/bin/bash", "/bin/bash -p", NULL);
```

**Result**: Bash preserves euid=1000.

## Testing and Verification

### Quick Test Script

Use the `check_user_ids.sh` script to verify current user ID state:

```bash
./scripts/check_user_ids.sh
```

### Analyzing SUID Binaries

Use the `analyze_suid.sh` script to find and analyze SUID binaries:

```bash
./scripts/analyze_suid.sh
```

## References

- [setuid man page](https://man7.org/linux/man-pages/man2/setuid.2.html)
- [setresuid man page](https://man7.org/linux/man-pages/man2/setresuid.2.html)
- [execve man page](https://man7.org/linux/man-pages/man2/execve.2.html)
- [system man page](https://man7.org/linux/man-pages/man3/system.3.html)
- [bash man page](https://linux.die.net/man/1/bash)
- [0xdf's setuid rabbit hole](https://0xdf.gitlab.io/2022/05/31/setuid-rabbithole.html)

## When to Use This Skill

Use this skill when:
- Analyzing SUID binaries for privilege escalation
- Understanding why a process has unexpected privileges
- Debugging setuid/setreuid/setresuid behavior
- Writing or auditing code that manipulates user IDs
- Investigating Linux security incidents involving privilege boundaries
- Preparing for security certifications or CTF challenges
