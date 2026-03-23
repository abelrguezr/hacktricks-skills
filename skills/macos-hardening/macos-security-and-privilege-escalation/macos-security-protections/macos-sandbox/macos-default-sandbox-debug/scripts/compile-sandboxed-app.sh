#!/bin/bash
# Compile the sandboxed shell application
# Usage: ./compile-sandboxed-app.sh [output-name]

set -e

OUTPUT_NAME="${1:-SandboxedShellApp}"

echo "Compiling sandboxed shell application..."

# Check if main.m exists
if [[ ! -f "main.m" ]]; then
    echo "Error: main.m not found. Please create the source file first."
    echo ""
    echo "Create main.m with the following content:"
    cat << 'EOF'
#include <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        while (true) {
            char input[512];

            printf("Enter command to run (or 'exit' to quit): ");
            if (fgets(input, sizeof(input), stdin) == NULL) {
                break;
            }

            size_t len = strlen(input);
            if (len > 0 && input[len - 1] == '\n') {
                input[len - 1] = '\0';
            }

            if (strcmp(input, "exit") == 0) {
                break;
            }

            system(input);
        }
    }
    return 0;
}
EOF
    exit 1
fi

# Compile
clang -framework Foundation -o "$OUTPUT_NAME" main.m

echo "Compiled successfully: $OUTPUT_NAME"
