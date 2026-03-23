#!/bin/bash
# Create interposition library to intercept __mac_syscall
# This allows bypassing sandbox activation

echo "Creating interposition library for __mac_syscall..."

cat > interpose_mac_syscall.c << 'EOF'
#include <stdio.h>
#include <string.h>

// Forward declaration
int __mac_syscall(const char *_policyname, int _call, void *_arg);

// Our replacement function
int my_mac_syscall(const char *_policyname, int _call, void *_arg) {
    printf("[INTERPOSE] __mac_syscall invoked. Policy: %s, Call: %d\n", _policyname, _call);
    
    // Intercept sandbox initialization (call == 0 means init)
    if (strcmp(_policyname, "Sandbox") == 0 && _call == 0) {
        printf("[INTERPOSE] Bypassing Sandbox initiation\n");
        return 0; // Pretend we did the job without actually calling __mac_syscall
    }
    
    // Call the original function for other cases
    return __mac_syscall(_policyname, _call, _arg);
}

// Interposition structure
struct interpose_sym {
    const void *replacement;
    const void *original;
};

// Interpose __mac_syscall with my_mac_syscall
__attribute__((used)) static const struct interpose_sym interposers[] 
    __attribute__((section("__DATA, __interpose"))) = {
    { (const void *)my_mac_syscall, (const void *)__mac_syscall },
};
EOF

echo "Compiling interposition library..."
gcc -dynamiclib interpose_mac_syscall.c -o interpose_mac_syscall.dylib

if [ $? -eq 0 ]; then
    echo ""
    echo "Interposition library created: interpose_mac_syscall.dylib"
    echo ""
    echo "Usage:"
    echo "  DYLD_INSERT_LIBRARIES=./interpose_mac_syscall.dylib ./your_sandboxed_app"
    echo ""
    echo "This will intercept __mac_syscall and prevent sandbox activation"
    echo "when the policy is 'Sandbox' and call is 0 (initialization)."
else
    echo "Compilation failed"
    exit 1
fi
