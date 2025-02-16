#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then 
  echo "Script này cần được chạy với quyền root"
  exit 1
fi

# Đường dẫn thư mục dữ liệu
N8N_DIR="/home/deploy/n8n"
UPTIME_DIR="/home/deploy/uptime-kuma"
DOCKER_COMPOSE_FILE="/home/deploy/docker-compose.yml"
BACKUP_DIR="/root/backup-apps"

# Hiển thị tuỳ chọn nâng cấp
echo "=================================="
echo " Lựa chọn nâng cấp:"
echo "  1) Chỉ nâng cấp n8n"
echo "  2) Chỉ nâng cấp Uptime Kuma"
echo "  3) Nâng cấp cả hai"
echo "=================================="

read -p "Nhập lựa chọn của bạn (1/2/3): " choice

# Xác định ứng dụng cần nâng cấp
case $choice in
  1)
    APPS=("n8n")
    ;;
  2)
    APPS=("uptime-kuma")
    ;;
  3)
    APPS=("n8n" "uptime-kuma")
    ;;
  *)
    echo "Lựa chọn không hợp lệ! Thoát script."
    exit 1
    ;;
esac

# Hiển thị cảnh báo
echo "=== CẢNH BÁO ==="
echo "Quá trình nâng cấp có thể ảnh hưởng đến dữ liệu."
echo "Bạn nên backup dữ liệu trước khi tiếp tục."
echo "================="

# Hỏi người dùng có muốn backup dữ liệu
read -p "Bạn có muốn backup dữ liệu không? (y/n): " backup_choice
if [[ $backup_choice == [yY] || $backup_choice == [yY][eE][sS] ]]; then
    echo "Bắt đầu backup..."

    # Tạo thư mục backup nếu chưa tồn tại
    mkdir -p "$BACKUP_DIR/n8n"
    mkdir -p "$BACKUP_DIR/uptime-kuma"

    for app in "${APPS[@]}"; do
        if [[ $app == "n8n" ]]; then
            echo "Backup dữ liệu n8n..."
            if rsync -a --delete "$N8N_DIR/" "$BACKUP_DIR/n8n/"; then
                echo "Backup n8n hoàn tất tại $BACKUP_DIR/n8n"
            else
                echo "Lỗi khi backup n8n! Hủy quá trình nâng cấp."
                exit 1
            fi
        fi

        if [[ $app == "uptime-kuma" ]]; then
            echo "Backup dữ liệu Uptime Kuma..."
            if rsync -a --delete "$UPTIME_DIR/" "$BACKUP_DIR/uptime-kuma/"; then
                echo "Backup Uptime Kuma hoàn tất tại $BACKUP_DIR/uptime-kuma"
            else
                echo "Lỗi khi backup Uptime Kuma! Hủy quá trình nâng cấp."
                exit 1
            fi
        fi
    done
else
    read -p "Bạn có chắc chắn muốn tiếp tục mà không backup? (y/n): " confirm
    if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
        echo "Hủy quá trình nâng cấp."
        exit 1
    fi
fi

# Kiểm tra file docker-compose.yml
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "Không tìm thấy file docker-compose.yml tại $DOCKER_COMPOSE_FILE. Hủy quá trình nâng cấp."
    exit 1
fi

# Bắt đầu nâng cấp
echo "============================="
echo "Bắt đầu nâng cấp..."
echo "============================="

# Di chuyển đến thư mục chứa docker-compose.yml
cd "$(dirname "$DOCKER_COMPOSE_FILE")" || { echo "Không thể di chuyển đến thư mục docker-compose!"; exit 1; }

# Kéo image mới nhất chỉ cho ứng dụng đã chọn
for app in "${APPS[@]}"; do
    echo "Kéo image Docker mới nhất cho $app..."
    if ! docker-compose pull "$app"; then
        echo "Lỗi khi tải image mới của $app. Hủy quá trình nâng cấp."
        exit 1
    fi
done

# Dừng container cũ
echo "Dừng các container cần nâng cấp..."
docker-compose stop "${APPS[@]}"

# Khởi động lại container với image mới
echo "Khởi động lại container..."
if ! docker-compose up -d "${APPS[@]}"; then
    echo "Lỗi khi khởi động lại container! Kiểm tra lại Docker Compose."
    exit 1
fi

# Kiểm tra trạng thái container sau khi nâng cấp
echo "Đợi 10 giây để kiểm tra trạng thái container..."
sleep 10

for app in "${APPS[@]}"; do
    if docker-compose ps | grep -q "$app.*Up"; then
        echo "Nâng cấp $app thành công!"
    else
        echo "Có lỗi xảy ra với $app! Kiểm tra logs:"
        docker-compose logs --tail=50 "$app"
        exit 1
    fi
done

echo "============================="
echo "Quá trình nâng cấp hoàn tất!"
echo "============================="