#!/bin/bash
# List all environment variables in a formatted table

echo "=== Environment Variables ==="
echo ""
printf "%-20s %s\n" "VARIABLE" "VALUE"
printf "%-20s %s\n" "--------" "-----"

for var in $(printenv | cut -d= -f1 | sort); do
    value=$(printenv "$var" | head -c 50)
    if [ ${#value} -gt 50 ]; then
        value="${value}..."
    fi
    printf "%-20s %s\n" "$var" "$value"
done

echo ""
echo "Total variables: $(printenv | wc -l)"
