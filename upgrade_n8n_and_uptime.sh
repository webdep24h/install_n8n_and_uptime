#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then 
  echo "Script này cần được chạy với quyền root"
  exit 1
fi

# Đường dẫn thư mục
N8N_DIR="/home/deploy/n8n"
UPTIME_DIR="/home/deploy/uptime-kuma"
DOCKER_COMPOSE_FILE="/home/deploy/docker-compose.yml"
BACKUP_DIR="/root/backup-apps"

# Hiển thị cảnh báo
echo "=== CẢNH BÁO ==="
echo "Quá trình nâng cấp có thể ảnh hưởng đến dữ liệu."
echo "Bạn nên backup dữ liệu trước khi tiếp tục."
echo "================="

# Hỏi người dùng có muốn backup dữ liệu
read -p "Bạn có muốn backup dữ liệu không? (y/n): " answer
if [[ $answer == [yY] || $answer == [yY][eE][sS] ]]; then
    echo "Bắt đầu backup..."

    # Tạo thư mục backup nếu chưa tồn tại
    mkdir -p "$BACKUP_DIR/n8n"
    mkdir -p "$BACKUP_DIR/uptime-kuma"

# Backup dữ liệu n8n
echo "Backup dữ liệu n8n..."
if rsync -a --delete "$N8N_DIR/" "$BACKUP_DIR/n8n/"; then
    echo "Backup n8n hoàn tất tại $BACKUP_DIR/n8n"
else
    echo "Lỗi khi backup n8n! Hủy quá trình nâng cấp."
    exit 1
fi

# Backup dữ liệu Uptime Kuma
echo "Backup dữ liệu Uptime Kuma..."
if rsync -a --delete "$UPTIME_DIR/" "$BACKUP_DIR/uptime-kuma/"; then
    echo "Backup Uptime Kuma hoàn tất tại $BACKUP_DIR/uptime-kuma"
else
    echo "Lỗi khi backup Uptime Kuma! Hủy quá trình nâng cấp."
    exit 1
fi
else
    read -p "Bạn có chắc chắn muốn tiếp tục mà không backup? (y/n): " confirm
    if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
        echo "Hủy quá trình nâng cấp."
        exit 1
    fi
fi

# Bắt đầu nâng cấp
echo "============================="
echo "Bắt đầu nâng cấp n8n và Uptime Kuma..."
echo "============================="

# Kiểm tra file docker-compose.yml
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "Không tìm thấy file docker-compose.yml tại $DOCKER_COMPOSE_FILE. Hủy quá trình nâng cấp."
    exit 1
fi

# Di chuyển đến thư mục chứa docker-compose.yml
cd "$(dirname "$DOCKER_COMPOSE_FILE")"

# Pull image mới nhất
echo "Kéo các image Docker mới nhất..."
docker-compose pull

# Dừng và xóa container cũ
echo "Dừng các container cũ..."
docker-compose down

# Khởi động container với image mới
echo "Khởi động lại các container với image mới..."
docker-compose up -d

# Kiểm tra trạng thái
echo "Đợi 10 giây để kiểm tra trạng thái các container..."
sleep 10

if docker-compose ps | grep -q "Up"; then
    echo "Nâng cấp thành công n8n và Uptime Kuma!"
    echo "Kiểm tra logs:"
    docker-compose logs --tail=50
else
    echo "Có lỗi xảy ra! Một hoặc nhiều container không hoạt động."
    echo "Kiểm tra logs:"
    docker-compose logs --tail=50
fi

echo "============================="
echo "Quá trình nâng cấp hoàn tất!"
echo "============================="
