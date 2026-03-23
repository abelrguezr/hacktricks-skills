---
name: windows-msi-creation
description: How to create legitimate MSI installers using WiX Toolset for software deployment. Use this skill when you need to package Windows applications, create installer packages for software distribution, or learn about MSI structure and WiX XML configuration.
---

# Creating MSI Installers with WiX Toolset

This skill covers creating legitimate Windows MSI installers using the WiX Toolset, a framework for building Windows Installer packages.

## Overview

The WiX Toolset is an open-source framework for creating Windows Installer packages. It uses XML-based source files that are compiled into MSI files.

## Prerequisites

- WiX Toolset installed (download from https://wixtoolset.org)
- Basic understanding of Windows Installer concepts
- XML editing capability

## Basic MSI Structure

A WiX source file contains the following key elements:

### Product Element
Defines the product being installed:
- `Id`: Unique identifier (use `*` for auto-generation)
- `UpgradeCode`: GUID for upgrade tracking
- `Name`: Product display name
- `Version`: Version string
- `Manufacturer`: Company/organization name
- `Language`: Locale identifier

### Package Element
Configures the installer package:
- `InstallerVersion`: Required version (e.g., "200" for Windows Installer 2.0+)
- `Compressed`: Whether to compress the package
- `Comments`: Optional description

### Directory Structure
Defines where files will be installed:
- `TARGETDIR`: Root installation directory
- `ProgramFilesFolder`: Standard program files location
- `INSTALLLOCATION`: Custom installation folder

### Components
Group files and resources that should be installed together. Each component needs a unique GUID.

### Features
Define installable feature groups that users can select during installation.

## Building an MSI

### Step 1: Create WiX Source File

Create an XML file (e.g., `product.wxs`) with your product definition.

### Step 2: Compile with candle.exe

```bash
candle.exe -out output.wixobj source.wxs
```

This generates a Windows Installer XML object file.

### Step 3: Link with light.exe

```bash
light.exe -out output.msi output.wixobj
```

This produces the final MSI installer.

## Common Use Cases

- Packaging applications for enterprise deployment
- Creating installers for software distribution
- Managing software updates and upgrades
- Configuring installation options and features

## Best Practices

1. **Use meaningful IDs**: Generate stable GUIDs for components and products
2. **Test thoroughly**: Validate MSI behavior before distribution
3. **Document dependencies**: List required runtime components
4. **Follow naming conventions**: Use clear, descriptive names
5. **Version appropriately**: Increment version numbers for updates

## References

- [WiX Toolset Documentation](https://wixtoolset.org/documentation/)
- [Windows Installer SDK](https://learn.microsoft.com/windows/win32/msi/)
- [CodeProject WiX Examples](https://www.codeproject.com/)

## Security Considerations

- Only create MSI installers for legitimate software you own or have authorization to package
- Ensure all included files are from trusted sources
- Follow organizational security policies for software deployment
- Test installers in isolated environments before production use
