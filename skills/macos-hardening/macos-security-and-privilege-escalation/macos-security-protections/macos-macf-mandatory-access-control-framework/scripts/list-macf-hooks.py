#!/usr/bin/env python3
"""
List common MACF hook types and their purposes.
Useful for understanding what operations can be intercepted.
"""

import json

MACF_HOOKS = {
    "vnode": {
        "description": "File system operations",
        "hooks": [
            "check_access", "check_chdir", "check_chroot", "check_close",
            "check_create", "check_delete", "check_exec", "check_fcntl",
            "check_fork", "check_getattr", "check_kqfilter", "check_link",
            "check_listextattr", "check_mkdir", "check_mknod", "check_mmap",
            "check_open", "check_readdir", "check_readlink", "check_rename",
            "check_revoke", "check_searchfs", "check_select", "check_setattr",
            "check_setextattr", "check_setflags", "check_setutimes",
            "check_stat", "check_symlink", "check_unlink", "check_write",
            "notify_access", "notify_chdir", "notify_chroot", "notify_close",
            "notify_create", "notify_delete", "notify_exec", "notify_fcntl",
            "notify_link", "notify_mkdir", "notify_mknod", "notify_open",
            "notify_readdir", "notify_readlink", "notify_rename", "notify_revoke",
            "notify_searchfs", "notify_select", "notify_setattr", "notify_setextattr",
            "notify_setflags", "notify_setutimes", "notify_stat", "notify_symlink",
            "notify_unlink", "notify_write"
        ]
    },
    "proc": {
        "description": "Process operations",
        "hooks": [
            "check_create", "check_fork", "check_get_task_special_port",
            "check_getaudit", "check_getauid", "check_getgroups", "check_getlogin",
            "check_getpgrp", "check_getppid", "check_getuid", "check_mod_audit",
            "check_set_task_special_port", "check_setaudit", "check_setauid",
            "check_setgroups", "check_setlogin", "check_setpgrp", "check_setuid",
            "check_suspend", "check_wakeup", "check_syscall_unix",
            "label_associate", "label_destroy", "label_externalize",
            "label_internalize", "label_init", "label_update_execve"
        ]
    },
    "cred": {
        "description": "Credential operations",
        "hooks": [
            "check_label_update", "check_label_update_execve",
            "label_associate", "label_destroy", "label_externalize",
            "label_internalize", "label_init", "label_update_execve"
        ]
    },
    "file": {
        "description": "File descriptor operations",
        "hooks": [
            "check_fcntl", "check_lock", "check_mmap", "check_set",
            "label_associate", "label_destroy", "label_externalize",
            "label_internalize", "label_init"
        ]
    },
    "socket": {
        "description": "Socket operations",
        "hooks": [
            "check_accept", "check_bind", "check_connect", "check_create",
            "check_delete", "check_listen", "check_poll", "check_recv",
            "check_send", "check_setsockopt", "check_socketpair",
            "label_associate", "label_destroy", "label_externalize",
            "label_internalize", "label_init"
        ]
    },
    "kext": {
        "description": "Kernel extension operations",
        "hooks": [
            "check_load", "check_start", "check_unload",
            "check_get_property", "check_set_property"
        ]
    },
    "policy": {
        "description": "Policy lifecycle hooks",
        "hooks": [
            "policy_init", "policy_initbsd", "policy_syscall"
        ]
    }
}

def main():
    print("MACF Hook Types")
    print("=" * 60)
    print()
    
    for obj_type, info in MACF_HOOKS.items():
        print(f"{obj_type.upper()} ({info['description']})")
        print("-" * 40)
        for hook in info['hooks']:
            print(f"  - {hook}")
        print()
    
    print("=" * 60)
    print(f"Total hook types: {len(MACF_HOOKS)}")
    
    # Also output as JSON for programmatic use
    print("\nJSON output:")
    print(json.dumps(MACF_HOOKS, indent=2))

if __name__ == "__main__":
    main()
