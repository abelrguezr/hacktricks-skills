---
name: posix-cpu-timer-vuln-research
description: Research and analyze CVE-2025-38352 (POSIX CPU Timers TOCTOU race). Use this skill whenever investigating Linux kernel timer vulnerabilities, analyzing TOCTOU race conditions, setting up kernel exploitation test environments, or researching privilege escalation primitives involving CPU timers. Make sure to use this skill when the user mentions kernel races, POSIX timers, TOCTOU vulnerabilities, CVE-2025-38352, or wants to set up a safe kernel exploitation lab.
---

# POSIX CPU Timer TOCTOU Research (CVE-2025-38352)

This skill helps you research, understand, and safely test the POSIX CPU Timers TOCTOU race vulnerability (CVE-2025-38352) in Linux kernels.

## What this vulnerability does

A race condition between timer expiry and deletion during task exit can corrupt kernel timer state, causing crashes or enabling privilege escalation. The vulnerability requires:
- `CONFIG_POSIX_CPU_TIMERS_TASK_WORK=n` (IRQ-context expiry path)
- A target task exiting while another thread deletes its CPU timer
- The race window opens when `handle_posix_cpu_timers()` drops the sighand lock

## Quick start

1. Check if your kernel is vulnerable:
   ```bash
   ./scripts/check_kernel_config.sh
   ```

2. Set up a safe test environment:
   ```bash
   ./scripts/setup_qemu_test.sh
   ```

3. Run the reproduction PoC (in VM only):
   ```bash
   ./scripts/run_poc.sh
   ```

## Understanding the vulnerability

### The race window

The vulnerability exploits a timing gap between two operations:
1. Timer expiry processing in IRQ context
2. Timer deletion during task exit

When `handle_posix_cpu_timers()` releases the sighand lock, a concurrent `posix_cpu_timer_del()` call can miss the `it.cpu.firing` flag, leading to use-after-free or double-free conditions.

### Key kernel functions

- `collect_timerqueue()`: Marks timers as firing and moves them to a temporary list
- `handle_posix_cpu_timers()`: Processes firing timers after dropping the sighand lock
- `posix_cpu_timer_del()`: Deletes timers but may skip the firing check if task lookup fails

### Why TASK_WORK mode is safe

With `CONFIG_POSIX_CPU_TIMERS_TASK_WORK=y`, expiry is deferred to task_work, which runs before `exit_notify()`. This eliminates the race window.

## Safe testing guidelines

⚠️ **NEVER run this on production systems**

- Always use QEMU or a disposable VM
- Isolate the test environment
- Monitor for kernel panics
- Have a recovery plan

## Exploitation considerations

The base vulnerability causes kernel crashes (DoS). Privilege escalation requires:
- Additional kernel primitives (UAF, write-what-where)
- Careful timing to control the race
- Memory allocator manipulation

See the Chronomaly exploit for a full priv-esc chain.

## References

- [StreyPaws analysis](https://streypaws.github.io/posts/Race-Against-Time-in-the-Kernel-Clockwork/)
- [Android security bulletin](https://source.android.com/docs/security/bulletin/2025-09-01)
- [Chronomaly PoC](https://github.com/farazsth98/chronomaly)
- [CVE-2025-38352 analysis series](https://faith2dxy.xyz/2025-12-22/cve_2025_38352_analysis/)
