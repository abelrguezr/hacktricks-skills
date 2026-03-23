#!/bin/bash
# Create interposition library to prevent _libsecinit_initializer
# This prevents sandbox initialization

echo "Creating interposition library for _libsecinit_initializer..."

cat > interpose_libsecinit.c << 'EOF'
#include <stdio.h>

// Forward declaration of the original function
void _libsecinit_initializer(void);

// Our replacement function
void overriden__libsecinit_initializer(void) {
    printf("[INTERPOSE] _libsecinit_initializer called - sandbox initialization prevented\n");
    // Do nothing - this prevents the sandbox from being set up
}

// Interposition table
__attribute__((used, section("__DATA,__interpose"))) static struct {
    void (*overriden__libsecinit_initializer)(void);
    void (*_libsecinit_initializer)(void);
} _libsecinit_initializer_interpose = {
    overriden__libsecinit_initializer, 
    _libsecinit_initializer
};
EOF

echo "Compiling interposition library..."
gcc -dynamiclib interpose_libsecinit.c -o interpose_libsecinit.dylib

if [ $? -eq 0 ]; then
    echo ""
    echo "Interposition library created: interpose_libsecinit.dylib"
    echo ""
    echo "Usage:"
    echo "  DYLD_INSERT_LIBRARIES=./interpose_libsecinit.dylib ./your_sandboxed_app"
    echo ""
    echo "This will prevent _libsecinit_initializer from running,"
    echo "which prevents the sandbox from being initialized."
else
    echo "Compilation failed"
    exit 1
fi
