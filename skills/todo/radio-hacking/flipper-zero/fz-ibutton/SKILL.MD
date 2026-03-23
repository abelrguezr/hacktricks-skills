---
name: flipper-zero-ibutton
description: Use Flipper Zero to read, add, and emulate iButton access keys (Dallas, Cyfral, Metakom protocols). Use this skill whenever the user mentions iButton, Dallas key, Cyfral, Metakom, Flipper Zero access control, or needs to work with physical iButton keys for door access systems, even if they don't explicitly mention Flipper Zero.
---

# Flipper Zero iButton Skill

A skill for working with iButton access keys using Flipper Zero.

## What is an iButton

iButtons are physical cryptographic keys used for access control systems. They come in three main protocols:
- **Dallas** - Most common, 64-bit ID
- **Cyfral** - European variant
- **Metakom** - Another regional variant

## Physical Setup

### Reading an iButton

To **read** an iButton key:
1. Open the iButton app on Flipper Zero
2. Select **Read** mode
3. Touch the **blue contact area** of the Flipper to the iButton key
4. The Flipper will automatically detect the protocol type and display it above the ID number

### Emulating an iButton

To **emulate** a saved iButton:
1. Open the iButton app on Flipper Zero
2. Select **Emulate** mode
3. Choose the saved key from your list
4. Touch the **green contact area** of the Flipper to the reader

> **Important**: The contact areas are different for reading vs emulating. Use the correct area for each operation.

## Core Actions

### 1. Read an iButton

**When to use**: You have a physical iButton key and want to copy it to your Flipper.

**Steps**:
1. Navigate to the iButton app on Flipper Zero
2. Select "Read" mode
3. Touch the blue contact area to the iButton key
4. Wait for the Flipper to detect and display the key ID and protocol type
5. The key is automatically saved to your device

**What happens**: The Flipper automatically identifies whether the key is Dallas, Cyfral, or Metakom protocol.

### 2. Add iButton Manually

**When to use**: You have the key ID and protocol type but don't have physical access to the key.

**Steps**:
1. Navigate to the iButton app on Flipper Zero
2. Select "Add" or "Add Manually"
3. Choose the protocol type (Dallas, Cyfral, or Metakom)
4. Enter the key ID
5. Save the key

**Supported protocols**: Dallas, Cyfral, Metakom

### 3. Emulate an iButton

**When to use**: You want to use a saved iButton key to access a door or system.

**Steps**:
1. Navigate to the iButton app on Flipper Zero
2. Select "Emulate" mode
3. Choose the saved key from your list
4. Touch the green contact area to the reader
5. Wait for access confirmation

## Troubleshooting

### Contact Issues

If you cannot make proper contact between the Flipper Zero and the reader:

**Use External GPIO**:
- Connect GPIO pins to extend the contact range
- This allows you to reach readers that are difficult to access
- Refer to Flipper Zero GPIO documentation for wiring details

### Key Not Reading

If the Flipper cannot read a key:
1. Ensure you're using the blue contact area for reading
2. Check that the iButton is not damaged
3. Try different angles and pressure
4. Verify the iButton is compatible (Dallas, Cyfral, or Metakom)

### Emulation Not Working

If emulation fails:
1. Ensure you're using the green contact area for emulation
2. Verify the key was saved correctly
3. Check that the reader supports the key protocol
4. Try re-reading the original key

## Best Practices

- **Label your keys**: Give saved keys descriptive names for easy identification
- **Test before relying**: Always test emulation in a non-critical situation first
- **Keep backups**: Export your iButton database regularly
- **Understand the protocols**: Different systems use different protocols - know what you're working with

## References

- [Flipper Zero iButton Blog](https://blog.flipperzero.one/taming-ibutton/)
- [iButton Technical Documentation](../ibutton.md)

## Common Use Cases

- Copying office door access keys
- Testing iButton reader compatibility
- Creating backup access keys
- Auditing access control systems
- Learning about iButton protocols
