#!/bin/bash

echo "=== Настройка Terraform для Yandex Cloud ==="

# Проверка yc CLI
if ! command -v yc &> /dev/null; then
    echo "❌ Yandex Cloud CLI (yc) не установлен"
    echo "Установите: curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash"
    exit 1
fi

echo "✅ Yandex Cloud CLI установлен"

# Проверка аутентификации
if ! yc config list &> /dev/null; then
    echo "❌ Yandex Cloud CLI не настроен"
    echo "Запустите: yc init"
    exit 1
fi

echo "✅ Yandex Cloud CLI настроен"

# Экспорт переменных окружения
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)

echo ""
echo "=== Переменные окружения настроены ==="
echo "YC_TOKEN: ${YC_TOKEN:0:20}..."
echo "YC_CLOUD_ID: $YC_CLOUD_ID"
echo "YC_FOLDER_ID: $YC_FOLDER_ID"
echo ""

# Сохранить в файл для последующего использования
cat > .env << EOF
export YC_TOKEN=$YC_TOKEN
export YC_CLOUD_ID=$YC_CLOUD_ID
export YC_FOLDER_ID=$YC_FOLDER_ID
EOF

echo "✅ Переменные сохранены в .env"
echo ""
echo "Для использования в будущем:"
echo "  source .env"
echo ""
echo "Теперь можно запустить:"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"
