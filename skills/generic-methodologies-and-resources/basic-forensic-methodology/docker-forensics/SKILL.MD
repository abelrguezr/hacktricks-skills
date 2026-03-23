---
name: docker-forensics
description: Perform forensic analysis on Docker containers and images. Use this skill whenever investigating compromised containers, analyzing suspicious Docker images, extracting credentials from container memory, or comparing container states. Trigger when users mention Docker forensics, container investigation, image analysis, docker diff, container-diff, dive tool, or need to find modifications in Docker environments.
---

# Docker Forensics Skill

A comprehensive guide for performing forensic analysis on Docker containers and images.

## When to Use This Skill

Use this skill when:
- Investigating potentially compromised Docker containers
- Analyzing suspicious Docker images (especially `.tar` exports)
- Comparing container states to detect modifications
- Extracting credentials from container process memory
- Auditing Docker image layers for malicious content
- Documenting container changes for incident response

## Container Forensics

### Detect Container Modifications

Find what files have been changed or added in a running container compared to its base image:

```bash
docker diff <container_name_or_id>
```

**Output interpretation:**
- `A` = Added file
- `C` = Changed file
- `D` = Deleted file

**Example:**
```
docker diff wordpress
C /var
C /var/lib
A /var/lib/mysql/ib_logfile0
A /etc/shadow
```

### Extract Files from Container

Copy suspicious files from a container to your local system for analysis:

```bash
docker cp <container_name_or_id>:<path_to_file> <local_destination>
```

**Example:**
```bash
docker cp wordpress:/etc/shadow ./shadow_from_container
```

### Compare Files Against Original

To verify if a file was modified, compare it against the original from a fresh container:

```bash
# Start a fresh container from the same image
docker run -d <image_name> temp_container

# Extract the original file
docker cp temp_container:<path_to_file> ./original_file

# Compare with the suspicious file
diff ./original_file ./shadow_from_container

# Clean up
docker rm -f temp_container
```

### Access Container for Investigation

Enter a running container to investigate suspicious files:

```bash
docker exec -it <container_name_or_id> bash
```

If bash isn't available, try:
```bash
docker exec -it <container_name_or_id> sh
```

## Image Forensics

### Basic Image Analysis

Get detailed information about an image:

```bash
docker inspect <image_name_or_id>
```

View the complete history of changes made to the image:

```bash
docker history --no-trunc <image_name_or_id>
```

### Export and Analyze Images

Export an image to a tar file for offline analysis:

```bash
docker save <image_name> > image.tar
```

### Use container-diff Tool

[container-diff](https://github.com/GoogleContainerTools/container-diff) provides automated image analysis:

```bash
# Analyze layer sizes
container-diff analyze -t sizelayer image.tar

# View image history
container-diff analyze -t history image.tar

# Get metadata
container-diff analyze -t metadata image.tar
```

### Use dive Tool

[dive](https://github.com/wagoodman/dive) provides an interactive interface to explore image layers:

```bash
# Load the image into Docker
sudo docker load < image.tar

# Open with dive
sudo dive <image_name:tag>
```

**dive navigation:**
- **Red** = Added files
- **Yellow** = Modified files
- **Tab** = Switch between views
- **Space** = Collapse/expand folders

### Decompress Image Layers

To access individual layer contents:

```bash
# Extract the tar archive
tar -xf image.tar

# Decompress all layers
for d in $(find * -maxdepth 0 -type d); do 
  cd $d
  tar -xf ./layer.tar
  cd ..
done
```

### Generate Dockerfile from Image

Reconstruct a Dockerfile from an existing image:

```bash
# Using dfimage
docker run -v /var/run/docker.sock:/var/run/docker.sock --rm alpine/dfimage -sV=1.36 <image_name>
```

## Credential Extraction from Memory

### Process Memory Analysis

Docker container processes are visible on the host system. You can dump their memory to search for credentials:

```bash
# List processes from the container on the host
ps -ef | grep <container_process>

# Dump process memory (requires root)
sudo gdb -p <pid> -batch -ex "dump memory /tmp/memdump.bin 0x0 $(cat /proc/<pid>/maps | grep 'heap' | awk '{print $2}')"

# Search for credentials in memory dump
grep -a -i "password\|api_key\|secret\|token" /tmp/memdump.bin
```

**Note:** This technique works because container processes run on the host and their memory can be accessed from the host system.

## Investigation Workflow

### Step-by-Step Container Investigation

1. **Identify the container**
   ```bash
   docker ps -a
   ```

2. **Check for modifications**
   ```bash
   docker diff <container_id>
   ```

3. **Extract suspicious files**
   ```bash
   docker cp <container_id>:<suspicious_path> ./
   ```

4. **Compare with original**
   ```bash
   docker run -d <image> temp
   docker cp temp:<path> ./original
   diff ./original ./suspicious
   docker rm -f temp
   ```

5. **Access container if needed**
   ```bash
   docker exec -it <container_id> bash
   ```

### Step-by-Step Image Investigation

1. **Load the image**
   ```bash
   docker load < image.tar
   ```

2. **Get basic info**
   ```bash
   docker inspect <image>
   docker history --no-trunc <image>
   ```

3. **Analyze with tools**
   ```bash
   container-diff analyze -t history image.tar
   dive <image>
   ```

4. **Decompress layers for deep inspection**
   ```bash
   tar -xf image.tar
   for d in $(find * -maxdepth 0 -type d); do cd $d; tar -xf ./layer.tar; cd ..; done
   ```

## Common Indicators of Compromise

Look for these suspicious patterns:

- **Modified system files:** `/etc/shadow`, `/etc/passwd`, `/etc/hosts`
- **Unexpected binaries:** Files in `/tmp`, `/var/tmp`, or unusual locations
- **Hidden files:** Files starting with `.` in unexpected directories
- **Network tools:** `nc`, `netcat`, `curl`, `wget` in containers that shouldn't have them
- **Shell access:** `/bin/bash` or `/bin/sh` in containers that should be single-purpose
- **Credential files:** `.env`, `.aws/credentials`, config files with secrets
- **Persistence mechanisms:** Modified `/etc/crontab`, systemd services, or startup scripts

## Best Practices

1. **Document everything:** Save outputs of all forensic commands
2. **Preserve evidence:** Work on copies, not originals
3. **Use read-only mounts:** When possible, mount containers read-only to prevent further changes
4. **Check timestamps:** Compare file modification times against expected deployment times
5. **Verify checksums:** Compare file hashes against known-good baselines
6. **Search for artifacts:** Look for shell history, temporary files, and logs

## Tools Reference

| Tool | Purpose | Installation |
|------|---------|-------------|
| `docker diff` | Compare container to image | Built-in |
| `container-diff` | Image analysis | [GitHub releases](https://github.com/GoogleContainerTools/container-diff/releases) |
| `dive` | Interactive layer explorer | [GitHub releases](https://github.com/wagoodman/dive/releases) |
| `dfimage` | Generate Dockerfile from image | `docker pull alpine/dfimage` |
| `gdb` | Memory dumping | `apt install gdb` or `yum install gdb` |
