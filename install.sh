#!/usr/bin/env bash
# Bayern Card Club — установка.
#   ./install.sh native   Postgres + Redis через apt (Debian/Ubuntu), без Docker. Самый лёгкий вариант.
#   ./install.sh docker   Postgres + Redis в Docker Compose с лимитами памяти.
set -euo pipefail
cd "$(dirname "$0")"
MODE="${1:-native}"
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

need_node() {
  if ! command -v node >/dev/null || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 20 ]; then
    echo "Нужен Node.js 20+. Установи: https://nodejs.org (или nvm) и запусти скрипт снова."; exit 1
  fi
}

gen_env() {
  [ -f .env ] && { echo ".env уже есть — не трогаю."; return; }
  local pw; pw=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)
  cp .env.example .env
  sed -i "s/change_me/${pw}/g" .env
  sed -i "s/^WEBHOOK_SECRET=.*/WEBHOOK_SECRET=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32)/" .env
  chmod 600 .env
  echo "Создан .env со случайным паролем БД. Впиши BOT_TOKEN, WEBAPP_URL и ADMIN_TELEGRAM_IDS."
}

setup_native() {
  command -v apt-get >/dev/null || { echo "native-режим рассчитан на Debian/Ubuntu. Используй: ./install.sh docker"; exit 1; }
  $SUDO apt-get update -y
  $SUDO apt-get install -y postgresql redis-server
  local pw; pw=$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2)

  # Лёгкие настройки Postgres (conf.d подхватывается основным конфигом)
  local pgconf; pgconf=$(ls -d /etc/postgresql/*/main | head -1)
  $SUDO mkdir -p "$pgconf/conf.d"
  $SUDO cp deploy/postgres.conf "$pgconf/conf.d/bayern.conf"
  $SUDO systemctl restart postgresql

  # Роль и база (повторный запуск безопасен)
  $SUDO -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='bayern') THEN
    CREATE ROLE bayern LOGIN PASSWORD '${pw}';
  ELSE
    ALTER ROLE bayern PASSWORD '${pw}';
  END IF;
END \$\$;
SQL
  $SUDO -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='bayern_cards'" | grep -q 1 \
    || $SUDO -u postgres createdb -O bayern bayern_cards

  # Redis: только localhost, жёсткий потолок памяти
  $SUDO cp deploy/redis.conf /etc/redis/redis-bayern.conf
  $SUDO sed -i 's#^bind .*##' /etc/redis/redis.conf
  $SUDO bash -c 'grep -q "include /etc/redis/redis-bayern.conf" /etc/redis/redis.conf || { echo "bind 127.0.0.1 -::1" >> /etc/redis/redis.conf; echo "include /etc/redis/redis-bayern.conf" >> /etc/redis/redis.conf; }'
  $SUDO systemctl restart redis-server
}

setup_docker() {
  command -v docker >/dev/null || { echo "Docker не найден: https://docs.docker.com/engine/install/"; exit 1; }
  docker compose up -d --wait postgres redis
}

need_node
gen_env
case "$MODE" in
  native) setup_native ;;
  docker) setup_docker ;;
  *) echo "Использование: ./install.sh [native|docker]"; exit 1 ;;
esac

npm install --no-audit --no-fund
bash scripts/init-db.sh
echo "Готово. База и Redis подняты, схема применена."
