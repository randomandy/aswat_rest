CREATE TABLE "user" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "name" TEXT NOT NULL,
  "password" TEXT NOT NULL,
  "cart_id" INTEGER DEFAULT NULL,
  "is_admin" INTEGER NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX "user_name" ON "user" ("name");

CREATE TABLE "product" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "name" TEXT NOT NULL,
  "stock" INTEGER DEFAULT 0
);

CREATE TABLE "cart" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "cart_id" INTEGER NOT NULL,
  "product_id" INTEGER NOT NULL,
  "quantity" INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY ("product_id") REFERENCES "product"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "cart_id_product_id" ON "cart" ("product_id");