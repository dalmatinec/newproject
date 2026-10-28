-- Bayern Card Club: ограничения и индексы, которые Prisma не умеет описывать.
-- Применяется ОДИН раз: scripts/init-db.sh дописывает этот файл в первую миграцию.

-- ── Целостность экономики ──
ALTER TABLE "Wallet"            ADD CONSTRAINT wallet_coins_nonneg   CHECK (coins >= 0);
ALTER TABLE "MarketListing"     ADD CONSTRAINT listing_price_pos     CHECK (price > 0);
ALTER TABLE "MarketTransaction" ADD CONSTRAINT mtx_amounts_ok        CHECK (price > 0 AND fee >= 0 AND fee <= price);
ALTER TABLE "MarketTransaction" ADD CONSTRAINT mtx_no_self_trade     CHECK ("buyerId" <> "sellerId");
ALTER TABLE "PlayerCard"        ADD CONSTRAINT card_rating_range     CHECK (rating BETWEEN 1 AND 99);
ALTER TABLE "PlayerCard"        ADD CONSTRAINT card_weight_nonneg    CHECK ("dropWeight" >= 0);
ALTER TABLE "UserCard"          ADD CONSTRAINT usercard_level_min    CHECK (level >= 1);
ALTER TABLE "Product"           ADD CONSTRAINT product_price_pos     CHECK ("starsPrice" > 0);
ALTER TABLE "Order"             ADD CONSTRAINT order_stars_pos       CHECK (stars > 0);
ALTER TABLE "Payment"           ADD CONSTRAINT payment_amount_pos    CHECK ("totalAmount" > 0);

-- ── Одна карта — одно активное объявление ──
CREATE UNIQUE INDEX "MarketListing_one_active_per_card"
  ON "MarketListing" ("userCardId") WHERE status = 'ACTIVE';

-- ── Частичные индексы: хранят только «живые» строки, занимают мало памяти ──
-- Лента рынка: сортировка по новизне и по цене
CREATE INDEX "MarketListing_active_new"
  ON "MarketListing" ("createdAt" DESC, id DESC) WHERE status = 'ACTIVE';
CREATE INDEX "MarketListing_active_price"
  ON "MarketListing" (price, id) WHERE status = 'ACTIVE';

-- Забаненные пользователи (админка)
CREATE INDEX "User_banned" ON "User" (id) WHERE "isBanned";

-- Невыставленные карты (выбор для продажи/улучшения)
CREATE INDEX "UserCard_free"
  ON "UserCard" ("userId", "cardId") WHERE NOT "isListed";

-- Платежи в обработке (фоновая проверка зависших заказов)
CREATE INDEX "Order_pending" ON "Order" ("createdAt") WHERE status = 'PENDING';

-- Действующие подписки (фоновое истечение срока)
CREATE INDEX "Subscription_live" ON "Subscription" ("expiresAt") WHERE status = 'ACTIVE';

-- ── Меньше раздувания таблиц, где строки часто обновляются ──
ALTER TABLE "Wallet"           SET (fillfactor = 70);
ALTER TABLE "MarketListing"    SET (fillfactor = 80);
ALTER TABLE "UserTaskProgress" SET (fillfactor = 80);
