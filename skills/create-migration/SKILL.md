---
name: create-migration
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Create TiDB-compatible SQLx migration files. Use proactively when: (1) New database table
  needs to be created, (2) Existing table schema needs modification (ADD/DROP/MODIFY COLUMN),
  (3) Index addition or removal needed, (4) Task involves database schema changes. Ensures TiDB
  DDL compatibility and follows project conventions.
---

# Create TiDB-Compatible Migration

TiDB互換のSQLxマイグレーションファイルを作成するスキル。

## TiDB DDL 重要制約

TiDBはMySQL互換だが、DDLに関して以下の重要な違いがある。**これらを理解せずにマイグレーションを書くとデプロイ時に失敗する。**

### 1. DDLは自動コミット（最重要）

TiDBではDDLステートメントは暗黙的にトランザクションをコミットする。**DDLとDMLを同一トランザクション/マイグレーションファイルに混在させてはならない。**

```sql
-- ❌ NG: DDL + DML を同じマイグレーションに書く
CREATE TABLE `new_table` (...);
INSERT INTO `new_table` VALUES (...);  -- DDLの自動コミット後に実行され、ロールバック不可

-- ❌ NG: ALTER TABLE 後に UPDATE
ALTER TABLE `users` ADD COLUMN `role` VARCHAR(20) DEFAULT 'user';
UPDATE `users` SET `role` = 'admin' WHERE `id` = 'us_xxx';  -- 同上

-- ✅ OK: DDLのみをマイグレーションに書く
ALTER TABLE `users` ADD COLUMN `role` VARCHAR(20) NOT NULL DEFAULT 'user';
-- データ投入はシードファイル（yaml-seeder）で行う
```

### 2. ADD COLUMNの制約

```sql
-- ✅ サポートされる
ALTER TABLE t ADD COLUMN col1 INT;
ALTER TABLE t ADD COLUMN IF NOT EXISTS col1 INT;
ALTER TABLE t ADD COLUMN col1 INT AFTER existing_col;
ALTER TABLE t ADD COLUMN col1 INT FIRST;
ALTER TABLE t ADD COLUMN col1 INT, ADD COLUMN col2 VARCHAR(50);  -- v6.2.0+

-- ❌ サポートされない
ALTER TABLE t ADD COLUMN col1 INT PRIMARY KEY;        -- 新カラムをPKに設定不可
ALTER TABLE t ADD COLUMN col1 INT AUTO_INCREMENT;     -- 新カラムをAUTO_INCREMENTに設定不可

-- ❌ 同じALTER内で新カラムをAFTERで参照不可
ALTER TABLE t ADD COLUMN c1 INT, ADD COLUMN c2 INT AFTER c1;  -- c1はまだ存在しないためエラー
-- ✅ 別のALTER文に分ける
ALTER TABLE t ADD COLUMN c1 INT;
ALTER TABLE t ADD COLUMN c2 INT AFTER c1;
```

### 3. Multi-Schema Change（v6.2.0+）

単一のALTER TABLEで複数の操作が可能。ただし**同じオブジェクトを複数回変更することは不可**。

```sql
-- ✅ OK: 異なるカラムを同時に操作
ALTER TABLE `t`
  ADD COLUMN `a` INT,
  ADD COLUMN `b` VARCHAR(50),
  DROP COLUMN `c`;

-- ❌ NG: 同じカラムを複数回変更
ALTER TABLE `t`
  ADD COLUMN `a` INT,
  MODIFY COLUMN `a` BIGINT;  -- 同じカラム `a` を2回変更
```

### 4. DROP COLUMNの制約

```sql
-- ✅ サポートされる
ALTER TABLE t DROP COLUMN col1;
ALTER TABLE t DROP COLUMN IF EXISTS col1;

-- ❌ サポートされない
-- PKカラムのDROPは不可
-- 複合インデックスに含まれるカラムのDROPは不可（インデックスを先に削除する）
-- ビューやエクスプレッションインデックスから参照されているカラムのDROPは不可

-- ❌ 複数カラムの同時DROPは不可
ALTER TABLE t DROP COLUMN col1, DROP COLUMN col2;  -- エラー: can't run multi schema change
-- ✅ 別々のALTER文に分ける
ALTER TABLE t DROP COLUMN col1;
ALTER TABLE t DROP COLUMN col2;
```

### 5. MODIFY COLUMN の制約

```sql
-- ✅ サポートされる: 型の拡大（INT→BIGINT）、NULLable化、デフォルト値変更、COMMENT変更
ALTER TABLE t MODIFY COLUMN col1 BIGINT;
ALTER TABLE t MODIFY COLUMN col1 VARCHAR(100) NULL;

-- ⚠️ 制限付き: 型変更はLossy Column Type Change（データロスの可能性）
--   INTEGER型同士の変更は可能（INT→BIGINT等）
--   VARCHAR長の拡大は可能
--   VARCHAR→TEXT等の互換性のない変更は要注意
```

### 6. ADD INDEX のパフォーマンス影響

ADD INDEXはオンライン操作だが、**書き込み負荷の高い本番環境では性能に影響する**。

- 状態遷移: `absent → delete only → write only → write reorg → public`
- `write reorg`フェーズでバックフィルが発生し、TiKVのCPU/IOを消費
- 書き込みが多いカラムへのインデックス追加はTPSが大幅に低下する可能性あり

**本番での対策:**
```sql
-- インデックス作成の並列度を下げる（デフォルトの1/8）
SET @@global.tidb_ddl_reorg_worker_cnt = 4;
SET @@global.tidb_ddl_reorg_batch_size = 256;
```

### 7. テーブル置き換えパターン（大規模スキーマ変更）

PKの変更やカラム位置の大幅変更には「テーブル置き換え」パターンを使用する。

```sql
-- 1. 新テーブル作成
CREATE TABLE `users__new` (
    `id` VARCHAR(29) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    -- 新しいスキーマ定義
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. データコピー
INSERT INTO `users__new` (`id`, `name`)
SELECT `id`, `name` FROM `users`;

-- 3. テーブル入れ替え（アトミック）
RENAME TABLE `users` TO `users__legacy`,
             `users__new` TO `users`;

-- 4. 旧テーブル削除
DROP TABLE `users__legacy`;
```

### 8. JSON型カラムのDEFAULT制約

TiDB v8.0+ではJSONカラムのデフォルト値は**式（expression）でのみ**指定可能。リテラル値は不可。

```sql
-- ✅ OK: 式で指定
CREATE TABLE t (j JSON DEFAULT (JSON_OBJECT()));
CREATE TABLE t (j JSON DEFAULT (JSON_ARRAY()));

-- ❌ NG: リテラルは不可
CREATE TABLE t (j JSON DEFAULT '{}');
CREATE TABLE t (j JSON DEFAULT '[]');

-- ✅ OK: NULLは常に可能（このプロジェクトではこちらを推奨）
CREATE TABLE t (j JSON NULL);
CREATE TABLE t (j JSON DEFAULT NULL);
```

**プロジェクト方針**: JSON カラムは `JSON NULL`（デフォルトなし）を使用し、ドメインレイヤーで初期値を管理する。

### 9. インデックスの非サポート事項

```sql
-- ❌ 降順インデックス: 非サポート（構文はパースされるが無視される）
CREATE INDEX idx ON t (col DESC);  -- DESC は無視される

-- ❌ FULLTEXT インデックス: クエリ利用不可（構文のみ対応）
CREATE FULLTEXT INDEX idx ON t (col);  -- パースはされるが検索に使えない

-- ❌ SPATIAL インデックス: 非サポート
CREATE SPATIAL INDEX idx ON t (col);
```

### 10. 照合順序の注意

TiDBのデフォルト照合順序はMySQLと異なる。

```
MySQL:  utf8mb4_0900_ai_ci (v8.0) / utf8mb4_general_ci (v5.7)
TiDB:   utf8mb4_bin（バイナリ照合）
```

**このプロジェクトでは `utf8mb4_unicode_ci` を明示指定**しているので問題ないが、照合順序を省略すると `utf8mb4_bin`（大文字小文字を区別）が適用される点に注意。

### 11. VARCHARの長さ制限

- VARCHAR最大長: **16,383文字**（MySQL: 行サイズ上限65,535バイトに依存）
- インデックスキー最大長: **3,072バイト**（utf8mb4で768文字）

### 12. 外部キー

TiDB v8.5.0+で外部キーがGA。CASCADE DELETE/UPDATEをサポート。ただし、**このプロジェクトでは外部キーは原則使用しない**（アプリケーション層で整合性を管理）。

---

## プロジェクト規約

### ファイル命名

```
packages/{context}/migrations/YYYYMMDDhhmmss_description.up.sql
packages/{context}/migrations/YYYYMMDDhhmmss_description.down.sql
```

- **タイムスタンプ**: 14桁（`YYYYMMDDhhmmss`）
- **スネークケース**: `create_xxx`, `add_xxx_to_yyy`, `drop_xxx`, `rename_xxx`
- **UP/DOWNペア**: 必ず両方作成する
- **パッケージ別ディレクトリ**: `platform/aip/gateway/migrations/`, `packages/auth/migrations/`, `packages/payment/migrations/`

### マイグレーション配置先

| コンテキスト | ディレクトリ |
|------------|------------|
| LLMs/Agent | `platform/aip/gateway/migrations/` |
| Auth | `packages/auth/migrations/` |
| Payment | `packages/payment/migrations/` |

### CREATE TABLE テンプレート

```sql
CREATE TABLE `{table_name}` (
    `id` VARCHAR(29) NOT NULL COMMENT '{Entity} ID (ULID with prefix)',
    `tenant_id` VARCHAR(29) NOT NULL COMMENT 'Tenant ID',
    -- ビジネスカラム
    `status` VARCHAR(20) NOT NULL DEFAULT 'active' COMMENT 'Record status',
    `metadata` JSON NULL COMMENT 'Additional metadata',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'Creation time',
    `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT 'Last update time',
    PRIMARY KEY (`id`),
    INDEX `idx_{table_name}_tenant` (`tenant_id`),
    INDEX `idx_{table_name}_created` (`tenant_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='{テーブルの説明}';
```

### ALTER TABLE テンプレート（カラム追加）

```sql
-- UP
ALTER TABLE `{table_name}`
  ADD COLUMN `{column_name}` {TYPE} {NULL|NOT NULL} {DEFAULT value} COMMENT '{説明}' AFTER `{existing_column}`;

-- 必要に応じてインデックス追加
CREATE INDEX `idx_{table_name}_{column_name}` ON `{table_name}` (`{column_name}`);
```

```sql
-- DOWN
DROP INDEX `idx_{table_name}_{column_name}` ON `{table_name}`;
ALTER TABLE `{table_name}` DROP COLUMN `{column_name}`;
```

### DOWN ファイルの書き方

- UPの逆操作を完全に記述する
- テーブル削除には `IF EXISTS` を使う: `DROP TABLE IF EXISTS {table_name};`
- カラム削除: `ALTER TABLE t DROP COLUMN IF EXISTS col;`
- インデックス削除 → カラム削除の順序を守る（依存関係）
- 制約の復元が必要な場合は元の状態に戻す

### 型の規約

| 用途 | 型 | 例 |
|------|---|---|
| ULID ID | `VARCHAR(29)` or `VARCHAR(32)` or `CHAR(26)` | `id`, `tenant_id` |
| ステータス | `VARCHAR(20)` or `ENUM(...)` | `status` |
| 短い文字列 | `VARCHAR(N)` | `name`, `email` |
| 長い文字列 | `TEXT` | `description`, `prompt` |
| JSON構造体 | `JSON NULL` | `metadata`, `config` |
| 金額 | `BIGINT` | `*_nanodollars` |
| 真偽値 | `BOOLEAN NOT NULL DEFAULT FALSE` | `is_system` |
| 高精度日時 | `DATETIME(6)` | `created_at`, `updated_at` |
| 日時（標準） | `TIMESTAMP` | レガシーテーブル |

### COMMENT規約

- **最新マイグレーション**: テーブル・カラム・インデックスにCOMMENT必須
- テーブルCOMMENT: テーブルの目的を端的に（英語）
- カラムCOMMENT: カラムの意味、フォーマット、選択肢を記述（英語）

### インデックス命名

```
idx_{table_name}_{column(s)}     -- 通常のインデックス
uk_{table_name}_{column(s)}      -- ユニーク制約
fk_{table_name}_{ref_table}      -- 外部キー（原則使用しない）
```

---

## チェックリスト

マイグレーション作成時に以下を確認する:

- [ ] **UP/DOWNペア**: 両方のファイルが存在する
- [ ] **DDL/DML分離**: DDLのみ含み、INSERT/UPDATE/DELETEは含まない
- [ ] **文字セット**: `ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`
- [ ] **COMMENT**: テーブル・重要カラムにCOMMENTあり
- [ ] **タイムスタンプ**: `DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6)` 使用
- [ ] **DOWN完全性**: UPの逆操作がすべて記述されている
- [ ] **TiDB互換**: ADD COLUMNにPK/AUTO_INCREMENTを設定していない
- [ ] **TiDB互換**: 同一ALTER内で同じオブジェクトを複数回変更していない
- [ ] **TiDB互換**: 複数カラムの同時DROPをしていない（個別ALTER文に分ける）
- [ ] **TiDB互換**: 新カラムのAFTER指定で同じALTER内の他の新カラムを参照していない
- [ ] **TiDB互換**: JSONカラムにリテラルDEFAULT（`'{}'`）を使用していない（`NULL`か式を使用）
- [ ] **インデックス**: 検索パターンに応じた複合インデックスが定義されている
- [ ] **インデックス**: 降順/FULLTEXT/SPATIALインデックスを使用していない
- [ ] **冪等性**: DROP文には `IF EXISTS` を使用

## 実行コマンド

```bash
# マイグレーション実行（Docker内）
mise run docker-sqlx-migrate

# シード投入
mise run docker-seed

# SQLxのprepareキャッシュ更新（必要時のみ）
mise run sqlx-prepare
```
