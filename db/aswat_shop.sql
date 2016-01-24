CREATE TABLE "user" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "name" TEXT NOT NULL,
  "password" TEXT NOT NULL,
  "cart_id" INTEGER DEFAULT NULL,
  "is_admin" INTEGER NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX "user_name" ON "user" ("name");
