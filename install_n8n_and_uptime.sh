#!/bin/bash

# Kiểm tra xem script có được chạy với quyền root hay không
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please run with 'sudo'."
   exit 1
fi

# Hàm kiểm tra domain
check_domain() {
    local domain=$1
    local server_ip=$(curl -s https://api.ipify.org)
    local domain_ip=$(dig +short $domain)

    if [ "$domain_ip" = "$server_ip" ]; then
        return 0  # Domain đã trỏ đúng
    else
        return 1  # Domain chưa trỏ đúng
    fi
}

# Nhận input domain từ người dùng
read -p "Enter your domain for n8n (e.g., n8n.webdep24h.com): " N8N_DOMAIN
read -p "Enter your domain for Uptime Kuma (e.g., uptime.webdep24h.com): " UPTIME_DOMAIN

# Kiểm tra domain n8n
if check_domain $N8N_DOMAIN; then
    echo "Domain $N8N_DOMAIN has been correctly pointed to this server."
else
    echo "Domain $N8N_DOMAIN has not been pointed to this server."
    echo "Please update your DNS record to point $N8N_DOMAIN to IP $(curl -s https://api.ipify.org)"
    exit 1
fi

# Kiểm tra domain Uptime Kuma
if check_domain $UPTIME_DOMAIN; then
    echo "Domain $UPTIME_DOMAIN has been correctly pointed to this server."
else
    echo "Domain $UPTIME_DOMAIN has not been pointed to this server."
    echo "Please update your DNS record to point $UPTIME_DOMAIN to IP $(curl -s https://api.ipify.org)"
    exit 1
fi

# Sử dụng thư mục /home/deploy
BASE_DIR="/home/deploy"
N8N_DIR="$BASE_DIR/n8n"
UPTIME_DIR="$BASE_DIR/uptime-kuma"

# Cài đặt các gói cần thiết
echo "Cài đặt các gói cần thiết..."
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common dbus gnupg pass
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose

# Kiểm tra Docker đã được cài đặt chưa
if ! command -v docker &> /dev/null; then
    echo "Docker installation failed. Exiting..."
    exit 1
fi

# Tạo các thư mục cài đặt
echo "Tạo thư mục cài đặt..."
mkdir -p $N8N_DIR $UPTIME_DIR

# Tạo file docker-compose.yml
echo "Tạo file docker-compose.yml..."
cat << EOF > $BASE_DIR/docker-compose.yml
version: "3.9"
services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=${N8N_DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://${N8N_DOMAIN}
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
    volumes:
      - $N8N_DIR:/home/node/.n8n

  uptime-kuma:
    image: louislam/uptime-kuma
    restart: always
    ports:
      - "3001:3001"
    volumes:
      - $UPTIME_DIR:/app/data

  caddy:
    image: caddy:2
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - $BASE_DIR/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - n8n
      - uptime-kuma

volumes:
  caddy_data:
  caddy_config:
EOF

# Tạo file Caddyfile
echo "Tạo file Caddyfile..."
cat << EOF > $BASE_DIR/Caddyfile
${N8N_DOMAIN} {
    reverse_proxy n8n:5678
}

${UPTIME_DOMAIN} {
    reverse_proxy uptime-kuma:3001
}
EOF

# Đặt quyền cho thư mục
echo "Đặt quyền cho thư mục..."
chown -R 1000:1000 $BASE_DIR
chmod -R 755 $BASE_DIR

# Kéo image Docker và khởi động container
echo "Kéo các image Docker và khởi động container..."
cd $BASE_DIR
docker-compose pull
docker-compose up -d

# Kiểm tra trạng thái container
echo "Kiểm tra trạng thái container..."
docker ps

# Hoàn tất
echo "==============================="
echo "Cài đặt hoàn tất!"
echo "n8n: https://${N8N_DOMAIN}"
echo "Uptime Kuma: https://${UPTIME_DOMAIN}"
echo "==============================="

