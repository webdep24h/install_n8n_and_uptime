#!/bin/bash

# Kiểm tra xem script có được chạy với quyền root hay không
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please run with 'sudo'."
   exit 1
fi

echo "============================="
echo "Bắt đầu gỡ cài đặt n8n, Uptime Kuma, Caddy, Docker và xóa các thư mục liên quan."
echo "============================="

# Định nghĩa các thư mục và files cần xóa
BASE_DIR="/home/deploy"
N8N_DIR="$BASE_DIR/n8n"
UPTIME_DIR="$BASE_DIR/uptime-kuma"
DOCKER_COMPOSE_FILE="$BASE_DIR/docker-compose.yml"
CADDYFILE="$BASE_DIR/Caddyfile"

# Dừng và xóa các container Docker
echo "Dừng tất cả container Docker..."
docker ps -q | xargs -r docker stop
echo "Xóa tất cả container Docker..."
docker ps -aq | xargs -r docker rm

# Xóa volumes Docker
echo "Xóa tất cả volumes Docker..."
docker volume prune -f

# Xóa networks Docker
echo "Xóa tất cả networks Docker..."
docker network prune -f

# Xóa images Docker
echo "Xóa tất cả images Docker..."
docker images -q | xargs -r docker rmi -f

# Dừng và xóa Docker Compose container (nếu có)
if [ -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "Dừng các container từ Docker Compose..."
    cd $BASE_DIR
    docker-compose down
fi

# Gỡ cài đặt Docker và Docker Compose
echo "Gỡ cài đặt Docker và Docker Compose..."
apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose
apt-get autoremove -y
rm -rf /var/lib/docker
rm -rf /etc/docker

# Xóa thư mục dữ liệu của n8n và Uptime Kuma
echo "Xóa thư mục dữ liệu n8n và Uptime Kuma..."
rm -rf $N8N_DIR
rm -rf $UPTIME_DIR

# Xóa file cấu hình Docker Compose và Caddyfile
echo "Xóa file cấu hình Docker Compose và Caddyfile..."
rm -rf $DOCKER_COMPOSE_FILE
rm -rf $CADDYFILE

# Xóa các volume còn lại
echo "Xóa tất cả volumes và cache Docker..."
docker volume rm $(docker volume ls -q) 2>/dev/null

# Xóa logs và thư mục Caddy (nếu còn)
echo "Xóa các file và thư mục Caddy liên quan..."
rm -rf /data
rm -rf /config

# Dọn dẹp hệ thống
echo "Dọn dẹp các file và package không cần thiết..."
apt-get autoremove -y
apt-get autoclean -y

# Hoàn tất
echo "============================="
echo "Đã gỡ cài đặt hoàn toàn n8n, Uptime Kuma, Caddy và Docker!"
echo "============================="

