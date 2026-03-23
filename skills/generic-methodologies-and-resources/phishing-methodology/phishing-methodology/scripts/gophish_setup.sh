#!/bin/bash
#
# Automated GoPhish setup script for phishing assessments
# Usage: ./gophish_setup.sh <domain>
#

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <domain>"
    echo "Example: $0 phishing-test.example.com"
    exit 1
fi

DOMAIN="$1"
GOPHISH_DIR="/opt/gophish"
SSL_DIR="${GOPHISH_DIR}/ssl_keys"
LOG_DIR="/var/log/gophish"

echo "========================================"
echo "GoPhish Setup Script"
echo "Domain: $DOMAIN"
echo "========================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

echo "[1/7] Installing dependencies..."
apt-get update
apt-get install -y wget snapd certbot postfix mailutils
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
echo ""

echo "[2/7] Downloading GoPhish..."
mkdir -p $GOPHISH_DIR
cd $GOPHISH_DIR
GOPHISH_VERSION="v0.11.0"
wget -q "https://github.com/gophish/gophish/releases/download/${GOPHISH_VERSION}/gophish-${GOPHISH_VERSION}-linux-amd64.tar.gz"
tar -xzf "gophish-${GOPHISH_VERSION}-linux-amd64.tar.gz"
rm "gophish-${GOPHISH_VERSION}-linux-amd64.tar.gz"
echo ""

echo "[3/7] Generating TLS certificate..."
certbot certonly --standalone -d "$DOMAIN"
mkdir -p $SSL_DIR
cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" $SSL_DIR/key.pem
cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" $SSL_DIR/key.crt
echo ""

echo "[4/7] Configuring GoPhish..."
cat > ${GOPHISH_DIR}/config.json << EOF
{
    "admin_server": {
        "listen_url": "127.0.0.1:3333",
        "use_tls": true,
        "cert_path": "gophish_admin.crt",
        "key_path": "gophish_admin.key"
    },
    "phish_server": {
        "listen_url": "0.0.0.0:443",
        "use_tls": true,
        "cert_path": "${SSL_DIR}/key.crt",
        "key_path": "${SSL_DIR}/key.pem"
    },
    "db_name": "sqlite3",
    "db_path": "gophish.db",
    "migrations_prefix": "db/db_",
    "contact_address": "",
    "logging": {
        "filename": "",
        "level": ""
    }
}
EOF
echo ""

echo "[5/7] Creating service file..."
mkdir -p $LOG_DIR
cat > /etc/init.d/gophish << 'EOF'
#!/bin/bash
# /etc/init.d/gophish
process=gophish
appDirectory=/opt/gophish
logfile=/var/log/gophish/gophish.log
errfile=/var/log/gophish/gophish.error

start() {
    echo 'Starting Gophish...'
    cd ${appDirectory}
    nohup ./$process >>$logfile 2>>$errfile &
    sleep 1
}

stop() {
    echo 'Stopping Gophish...'
    pid=$(/bin/pidof ${process})
    if [ -n "$pid" ]; then
        kill ${pid}
        sleep 1
    fi
}

status() {
    pid=$(/bin/pidof ${process})
    if [ -n "$pid" ]; then
        echo "Gophish is running (PID: $pid)"
    else
        echo "Gophish is not running"
    fi
}

case $1 in
    start) start ;;
    stop) stop ;;
    status) status ;;
    restart) stop; sleep 2; start ;;
    *) echo "Usage: $0 {start|stop|status|restart}" ;;
esac
EOF
chmod +x /etc/init.d/gophish
update-rc.d gophish defaults
echo ""

echo "[6/7] Configuring Postfix..."
echo "$DOMAIN" >> /etc/postfix/virtual_domains
echo "$DOMAIN    hash:/etc/postfix/virtual_domains" >> /etc/postfix/transport
echo "/^@.*\$/    OK" >> /etc/postfix/virtual_regexp

postconf -e "myhostname = $DOMAIN"
postconf -e "mydestination = \$myhostname, $DOMAIN, localhost.localdomain, localhost"

echo "$DOMAIN" > /etc/hostname
echo "$DOMAIN" > /etc/mailname
echo ""

echo "[7/7] Starting services..."
service postfix restart
service gophish start
echo ""

echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "GoPhish Admin Panel:"
echo "  URL: https://localhost:3333"
echo "  SSH Tunnel: ssh -L 3333:127.0.0.1:3333 user@server"
echo ""
echo "Next steps:"
echo "1. Configure DNS A record: mail.$DOMAIN -> server IP"
echo "2. Configure DNS MX record: $DOMAIN -> mail.$DOMAIN"
echo "3. Add SPF, DMARC, DKIM records (use generate_spf_dmarc.py)"
echo "4. Test email: echo 'test' | mail -s 'test' test@example.com"
echo "5. Access admin panel and change default password"
echo ""
echo "Service commands:"
echo "  service gophish start|stop|status|restart"
echo ""
