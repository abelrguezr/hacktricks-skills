#!/bin/bash
# Convert certificates between formats
# Usage: ./convert_certificate.sh <input_file> <output_format> [output_file]

INPUT_FILE="$1"
OUTPUT_FORMAT="$2"
OUTPUT_FILE="$3"

if [ -z "$INPUT_FILE" ] || [ -z "$OUTPUT_FORMAT" ]; then
    echo "Certificate Format Converter"
    echo "Usage: $0 <input_file> <output_format> [output_file]"
    echo ""
    echo "Supported output formats:"
    echo "  pem    - PEM format (Base64 with headers)"
    echo "  der    - DER format (binary)"
    echo "  p12    - PKCS#12 (requires password)"
    echo ""
    echo "Examples:"
    echo "  $0 cert.pem der cert.der"
    echo "  $0 cert.der pem cert.pem"
    echo "  $0 cert.pem p12 output.p12"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# Set default output filename
if [ -z "$OUTPUT_FILE" ]; then
    BASENAME=$(basename "$INPUT_FILE" | sed 's/\.[^.]*$//')
    OUTPUT_FILE="${BASENAME}.${OUTPUT_FORMAT}"
fi

echo "Converting $INPUT_FILE to $OUTPUT_FORMAT..."

# Detect input format
if head -1 "$INPUT_FILE" 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
    INPUT_FORMAT="PEM"
    INFORM=""
else
    INPUT_FORMAT="DER"
    INFORM="-inform DER"
fi

echo "Detected input format: $INPUT_FORMAT"

case "$OUTPUT_FORMAT" in
    pem)
        openssl x509 $INFORM -in "$INPUT_FILE" -outform PEM -out "$OUTPUT_FILE" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "✓ Created: $OUTPUT_FILE"
        else
            echo "✗ Failed to convert to PEM"
            exit 1
        fi
        ;;
    der)
        openssl x509 $INFORM -in "$INPUT_FILE" -outform DER -out "$OUTPUT_FILE" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "✓ Created: $OUTPUT_FILE"
        else
            echo "✗ Failed to convert to DER"
            exit 1
        fi
        ;;
    p12)
        echo "PKCS#12 conversion requires a private key and password."
        echo "For certificate-only PKCS#12, use:"
        echo "  openssl pkcs12 -export -in $INPUT_FILE -out $OUTPUT_FILE"
        echo ""
        echo "For cert+key PKCS#12, use:"
        echo "  openssl pkcs12 -export -in cert.pem -inkey key.pem -out $OUTPUT_FILE"
        exit 1
        ;;
    *)
        echo "Error: Unknown output format: $OUTPUT_FORMAT"
        echo "Supported formats: pem, der, p12"
        exit 1
        ;;
esac

echo ""
echo "Conversion complete!"
