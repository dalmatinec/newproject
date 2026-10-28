#!/usr/bin/env bash
# Создаёт первую миграцию из schema.prisma и дописывает в неё ограничения/частичные индексы.
# Запускается один раз; если миграции уже есть — просто применяет их.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

if ! ls prisma/migrations/*/migration.sql >/dev/null 2>&1; then
  npx prisma migrate dev --name init --create-only --skip-generate
  dir=$(ls -d prisma/migrations/*_init | head -1)
  { echo; echo "-- ===== prisma/extra_constraints.sql ====="; cat prisma/extra_constraints.sql; } >> "$dir/migration.sql"
  echo "Первая миграция создана: $dir (закоммить её в git)"
fi
npx prisma migrate deploy
npx prisma generate
