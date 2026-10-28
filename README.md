# Bayern Card Club

Неофициальная фан-игра: коллекционные карточки в Telegram Mini App. Не связана с FC Bayern München;
все карточки и рейтинги — тестовые, игровые.

## Что уже есть (этап 1: база и инфраструктура)

- `prisma/schema.prisma` — 20 моделей из ТЗ (+ история цен объявления), индексы и уникальные ограничения.
- `prisma/extra_constraints.sql` — то, что Prisma не описывает: `CHECK (coins >= 0)`, один активный листинг на карту,
  частичные индексы (только по «живым» строкам, поэтому занимают мало памяти).
- `deploy/postgres.conf`, `deploy/redis.conf` — настройки под малый расход памяти.
- `docker-compose.yml` — Postgres (лимит 256 МБ) и Redis (лимит 64 МБ, `maxmemory 48mb`).
- `install.sh` — установка без Docker (`native`) или через Docker (`docker`).

Приложение (API + бот + статика одним Node-процессом, куча ограничена `--max-old-space-size=192`) — следующий этап.

## Установка

```bash
git clone https://github.com/dalmatinec/newproject && cd newproject
./install.sh native    # Debian/Ubuntu, без Docker
# или
./install.sh docker    # Postgres + Redis в контейнерах
```

Скрипт создаёт `.env` со случайным паролем БД. Впиши `BOT_TOKEN`, `WEBAPP_URL`, `ADMIN_TELEGRAM_IDS`.
При первом запуске создаётся миграция `prisma/migrations/*_init` — закоммить её.

## Индексы: что и зачем

| Таблица | Индекс | Для чего |
|---|---|---|
| WalletTransaction | `(userId, createdAt DESC)`, `idempotencyKey UNIQUE` | история с пагинацией, защита от повторов |
| UserCard | `(userId, cardId)`, `(userId, obtainedAt DESC)`, частичный `WHERE NOT isListed` | коллекция, дубликаты, прогресс альбома |
| MarketListing | частичные `WHERE status='ACTIVE'`: по дате и по цене; `UNIQUE(userCardId) WHERE ACTIVE` | лента рынка, запрет двойной продажи карты |
| MarketTransaction | `listingId UNIQUE`, `(buyerId, createdAt)`, `(sellerId, createdAt)` | нельзя купить дважды, история сделок |
| UserTaskProgress | PK `(userId, taskId, day)` | одна награда за задание в день |
| AlbumRewardClaim | PK `(userId, collectionId)` | награда за страницу один раз |
| Payment | `telegramPaymentChargeId UNIQUE` | нет повторного начисления за один платёж |
| Subscription | `(userId, status, expiresAt)`, частичный `WHERE ACTIVE` | проверка и истечение подписки |
