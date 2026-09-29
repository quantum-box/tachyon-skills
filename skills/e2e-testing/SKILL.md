---
name: e2e-testing
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Create, update, or run Playwright E2E tests when E2E work is requested or needed as part of a
  user-flow change. Use browser-test for ad hoc browser evidence.
---

# E2E Testing Skill

## 開発フロー

1. **Playwright MCP で動作確認** — テストコードを書く前に `browser-test` スキルで実際のブラウザ操作を確認する
2. **操作手順をテストコードに変換** — MCP で確認したセレクタ・操作手順を `*.spec.ts` に記述する
3. **ローカルで全テスト通過を確認** — `mise run e2e` で実行する
4. **CI で通過を確認** — push 後に `tachyon_ci.yaml` の e2e ジョブで検証される

## ディレクトリ構成

```
apps/tachyon/
├── playwright.config.ts          # Playwright 設定
└── src/e2e-tests/
    ├── .auth/user.json           # 認証セッション（自動生成、gitignored）
    ├── auth.setup.ts             # NextAuth ログインセットアップ
    ├── smoke.spec.ts             # スモークテスト（ページ表示確認）
    ├── iam-users.spec.ts         # IAM ユーザー管理
    ├── feature-flags.spec.ts     # フィーチャーフラグ
    ├── agent-chat.spec.ts        # エージェントチャット
    └── settings.spec.ts          # 設定ページ
```

## テスト実行コマンド

前提: `mise run up-tachyon` でバックエンド（DB + API + フロントエンド）が起動済みであること。

```bash
# Playwright ブラウザインストール（初回のみ）
npx playwright install --with-deps chromium

# 全テスト実行
mise run e2e

# スモークテストのみ
mise run e2e-smoke

# ブラウザ表示ありで実行（デバッグ用）
mise run e2e-headed

# 特定ファイルのみ
mise run e2e -- src/e2e-tests/iam-users.spec.ts

# Playwright UI モード（インタラクティブデバッグ）
NO_WEB_SERVER=1 pnpm --dir apps/tachyon run e2e:ui
```

### 環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `TACHYON_HOST_PORT` | 16000 | フロントエンドのポート（worktree1 は 16100） |
| `NO_WEB_SERVER` | - | `1` で webServer 起動をスキップ（Docker 起動済み時） |
| `CI` | - | CI 環境フラグ（リトライ 2 回、ワーカー 1） |

## テスト作成パターン

### 基本テンプレート

```typescript
import { expect, test } from '@playwright/test'

const TENANT_ID = process.env.TACHYON_TEST_TENANT_ID
if (!TENANT_ID) throw new Error('Set TACHYON_TEST_TENANT_ID from the local dev seed')
const BASE_PATH = `/v1beta/${TENANT_ID}`

test.describe('Feature Name', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`${BASE_PATH}/your-page`)
    await expect(page.getByText('Page Title')).toBeVisible()
  })

  test('should display main content', async ({ page }) => {
    await expect(page.getByRole('heading', { name: 'Title' })).toBeVisible()
  })

  test('should handle mobile viewport', async ({ page, isMobile }) => {
    if (isMobile) {
      // Mobile-specific assertions
    } else {
      // Desktop-specific assertions
    }
  })
})
```

### セレクタの優先順位

1. **`getByRole`** — `getByRole('button', { name: 'Submit' })` — 最優先。アクセシビリティに基づく
2. **`getByText`** — `getByText('ユーザー管理')` — UIが日本語の場合は日本語テキストで指定
3. **`getByPlaceholder`** — `getByPlaceholder('Filter emails...')` — 入力フィールド用
4. **`getByLabel`** — `getByLabel('breadcrumb')` — aria-label で絞り込み
5. **`getByTestId`** — `getByTestId('user-table')` — 上記で一意に特定できない場合のフォールバック

CSS セレクタや XPath は使わない。

### 待機の書き方

```typescript
// Good: アサーションベースの待機
await expect(page.getByText('Loaded')).toBeVisible()
await expect(page.getByText('Loaded')).toBeVisible({ timeout: 15000 })

// Bad: 固定待機
await page.waitForTimeout(3000)  // 使わない
```

`waitForTimeout` は `fill` 後のデバウンス待ち（300ms 程度）にのみ限定的に使用可。

## 認証セットアップ

`auth.setup.ts` が NextAuth の Credentials ログインを実行し、セッションを `.auth/user.json` に保存する。
chromium / Mobile Chrome プロジェクトは `storageState` でこのセッションを共有するため、各テストでログイン操作は不要。

**認証フロー:**
1. `/api/auth/csrf` で CSRF トークン取得
2. `/sign_in` でログインフォーム表示
3. Username: `test`, Password: `${TACHYON_TEST_PASSWORD}` をignored local configから読み込んで入力
4. リダイレクト完了を待機
5. セッション情報を保存

**テストプロジェクト構成:**

| プロジェクト | デバイス | 依存 |
|-------------|---------|------|
| setup | - | なし |
| chromium | Desktop Chrome | setup |
| Mobile Chrome | Pixel 5 | setup |

## CI 設定 (`tachyon_ci.yaml`)

```yaml
e2e:
  needs: check-changes
  if: needs.check-changes.outputs.should_run == 'true' && github.event.pull_request.draft != true
  runs-on: tachyoncloud-4vcpu
  timeout-minutes: 30
  continue-on-error: true  # バックエンド API が CI にないため auth が失敗する想定
```

**CI フロー:**
1. `pnpm install --frozen-lockfile` + `pnpm exec turbo run build --filter=tachyon`
2. `npx playwright install --with-deps chromium`
3. Next.js standalone サーバーを起動（ポート 16000）
4. `npx wait-on tcp:16000` で起動待ち
5. `pnpm exec playwright test --project=chromium` 実行
6. テスト結果アーティファクト（`playwright-report/`, `test-results/`）を 14 日保持

**現在の制限:** CI にバックエンド API がないため `continue-on-error: true`。認証セットアップが失敗し、認証が必要なテストは全て失敗する。

## 注意事項

- `baseURL` は `playwright.config.ts` で設定済み。`page.goto()` には相対パスを使用する
- テナント ID は `TACHYON_TEST_TENANT_ID` から読み込み、ローカルseedから値を確認する
- 各テストは独立させ、他テストの状態に依存しない
- `forbidOnly: true`（CI）— `.only()` を残したままコミットすると CI が失敗する
- テスト追加は `apps/tachyon/src/e2e-tests/` 配下に `*.spec.ts` ファイルを作成する
