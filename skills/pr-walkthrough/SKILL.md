---
name: pr-walkthrough
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  PRの実装内容を人間に説明しながら一緒に確認するコードウォークスルー。Clean
  Architectureのレイヤーごとに「こういう実装をしています」と説明し、人間が内容を把握した上でマージ判断できるようサポートする。使用タイミング: (1)
  PRマージ前の確認時、(2) /pr-walkthrough で手動呼び出し時。
---

# PR Walkthrough

PRの実装内容を人間に説明しながら一緒に確認するスキル。
「問題を指摘する」のではなく、「こういう実装をしていますよ」と説明することで、人間がコード内容を理解した上でマージ判断できるようにする。

## 基本方針

- **説明ファースト**: 各レイヤーで「何を実装したか」を先に説明する
- **対話的に進める**: 説明後に人間の確認を待ち、質問があれば答える
- **段階的に進行**: Clean Architectureのレイヤーごとに順番に確認

## Workflow

```
Phase 0: 差分把握・概要説明
    ↓
Phase 1: ドメイン層の説明
    ↓
Phase 2: ユースケース層の説明
    ↓
Phase 3: アダプター層の説明
    ↓
Phase 4: ハンドラー/API層の説明
    ↓
Phase 5: フロントエンドの説明（ある場合）
    ↓
Phase 6: テスト・その他の説明
    ↓
Phase 7: 最終確認
```

## Phase 0: 差分の把握と概要説明

```bash
git diff main...HEAD --name-only
```

変更ファイルを以下のように分類して表示:

```markdown
## 変更ファイル一覧

### Rust Backend
- **Domain**: `packages/xxx/domain/src/...`
- **Usecase**: `packages/xxx/src/usecase/...`
- **Adapter**: `packages/xxx/src/interface_adapter/...`
- **Handler**: `apps/xxx-api/src/...`

### Frontend
- **Pages**: `apps/xxx/src/app/...`
- **Components**: `apps/xxx/src/components/...`
- **GraphQL**: `*.graphql`

### Other
- **Migrations**: `migrations/...`
- **Tests**: `tests/...`
- **Config**: その他設定ファイル
```

表示後:
> 「このPRでは〇〇という機能を追加/修正しています。まずドメイン層から説明していきますね。よろしいですか？」

## Phase 1-6: レイヤーごとの説明

各フェーズでは以下の流れで進める:

### 1. 実装内容の説明

```markdown
## [Phase名]: [レイヤー名]の説明

### 追加/変更したもの
- `XxxEntity`: 〇〇を表すエンティティです
- `YyyValueObject`: △△の値を保持する値オブジェクトです

### 実装のポイント
- ここでは〇〇というパターンを採用しました
- △△の理由で、このような設計にしています

### コード例（必要に応じて）
```rust
// 重要な部分を抜粋して見せる
```
```

### 2. 確認を待つ

> 「ここまでで質問はありますか？問題なければ次の〇〇層に進みます」

### 3. 人間の反応に応じて対応

- 質問があれば回答
- 気になる点があれば詳細を説明
- OKなら次のフェーズへ

## 各レイヤーの説明ポイント

**詳細**: See [references/walkthrough-guide.md](references/walkthrough-guide.md)

| Phase | Layer | 説明すべきポイント |
|-------|-------|-------------------|
| 1 | Domain | エンティティ/値オブジェクトの役割、`def_id!`使用、ビジネスルール |
| 2 | Usecase | 処理の流れ、InputData/OutputData、権限チェック |
| 3 | Adapter | DBアクセス方法、外部サービス連携 |
| 4 | Handler | APIエンドポイント、GraphQL resolver/mutation |
| 5 | Frontend | ページ構成、コンポーネント設計、状態管理 |
| 6 | Test | テスト方針、カバレッジ |

## アーキテクチャレビューチェックリスト

各フェーズでの説明時に、以下のパターン違反がないか確認する:

### Usecase層の確認ポイント

1. **AuthApp::check_policy の確認**
   - ユースケースの execute 冒頭で `self.policy_check()` を呼んでいるか
   - webhook 受信など署名検証で代替するケースは例外
   - 欠けている場合は指摘: 「このユースケースに権限チェックがありません」

2. **InputData/OutputData パターン**
   - `execute` メソッドが `InputData` 構造体を受け取っているか
   - 複数の `execute_xxx` メソッドではなく、単一の `execute` + フィルター引数パターンか
   - 例: `ListIntegrations` は `filter: IntegrationFilter::All|Enabled|Featured` で分岐

### Handler/Resolver層の確認ポイント

1. **Resolver での Usecase 直接生成の禁止**
   - ❌ アンチパターン: Resolver 内で `Usecase::new(...)` を呼んでいる
   - ✅ 正しいパターン: `database_app.list_integrations().execute(...)` のように App 経由でアクセス
   - 違反を発見した場合: 「Resolver で直接 usecase を生成しています。App パターンを使用してください」

2. **Sync Usecases の集約確認**
   - inbound_sync / outbound_sync の usecase は `database::App` に集約されているか
   - `with_inbound_sync()` / `with_outbound_sync()` ビルダーで追加されているか
   - GraphQL Context に `database_app` が登録されているか

### 指摘の仕方

発見した問題は「こうなっています」と事実を伝え、改善案を提示:

```markdown
### ⚠️ アーキテクチャ上の懸念

#### Usecase での権限チェック欠落
- `ListConnections::execute()` で `policy_check` が呼ばれていません
- 推奨: 冒頭に `self.policy_check("library:ListConnections", input).await?` を追加

#### Resolver での直接生成
- `resolver.rs:520` で `ListIntegrations::new()` を直接呼んでいます
- 推奨: `database_app.list_integrations()` 経由でアクセス
```

## Phase 7: 最終確認

すべてのレイヤーの説明が終わったら、全体のサマリーを提示:

```markdown
## PR Walkthrough Summary

### 実装概要
- [このPRで実現したこと]

### 変更の構成
| Layer | Changes |
|-------|---------|
| Domain | XxxEntity, YyyValueObject追加 |
| Usecase | CreateXxx, UpdateXxx追加 |
| Adapter | SqlxXxxRepository実装 |
| Handler | GraphQL mutation追加 |
| Frontend | Xxxページ追加 |
| Test | シナリオテスト追加 |

### マージ前の確認事項
- [ ] `mise run docker-ci` でCIチェック済み
- [ ] `mise run tachyon-api-scenario-test` でテスト済み

### 質問・懸念点
- [ウォークスルー中に出た質問や議論があれば記載]
```

> 「以上がこのPRの全体像です。マージして問題ないか、最終確認をお願いします」
