# PR Walkthrough Guide

各レイヤーで「何を説明すべきか」のガイド。
人間が実装内容を理解できるように、以下のポイントを押さえて説明する。

## Phase 1: ドメイン層

`domain/` 配下の変更を説明:

### 説明すべきポイント

**エンティティ・値オブジェクト**
- 新しく追加したエンティティは何を表現しているか
- 値オブジェクトはどんな値を保持するか
- ビジネスルールはどこに書いてあるか

**ID定義**
- `def_id!` マクロでどんなIDを定義したか
- IDのプレフィックスは何か（例: `us_`, `tn_`）

**例: 説明の仕方**
```markdown
### Domain層で追加したもの

- `LibraryItem`: ライブラリに登録されるアイテムを表すエンティティです
  - `def_id!(LibraryItemId, "li_")` でIDを定義
  - `title`, `description`, `status` などのフィールドを持ちます

- `ItemStatus`: アイテムの状態を表す値オブジェクト（enum）です
  - `Draft`, `Published`, `Archived` の3状態があります
```

## Phase 2: ユースケース層

`usecase/` 配下の変更を説明:

### 説明すべきポイント

**処理の流れ**
- このユースケースは何をするものか
- どんな入力を受け取って、どんな出力を返すか
- 内部でどんな処理をしているか

**権限チェック**
- どのアクションで権限チェックをしているか
- どんなユーザーが実行できるか

**例: 説明の仕方**
```markdown
### Usecase層で追加したもの

- `CreateLibraryItem`: ライブラリにアイテムを新規作成するユースケースです
  - 入力: タイトル、説明、カテゴリ
  - 出力: 作成されたアイテムのID
  - 権限: `library:CreateItem` アクションで検証

- 処理の流れ:
  1. 権限チェック
  2. バリデーション
  3. エンティティ作成
  4. リポジトリに保存
  5. イベント発行（必要に応じて）
```

## Phase 3: アダプター層

`interface_adapter/` または `adapter/` 配下を説明:

### 説明すべきポイント

**リポジトリ実装**
- どのテーブルにアクセスするか
- CRUDのどの操作を実装したか

**外部サービス連携**
- 外部APIとの連携があれば説明

**例: 説明の仕方**
```markdown
### Adapter層で追加したもの

- `SqlxLibraryItemRepository`: DBへのアクセスを実装
  - `library_items` テーブルを使用
  - `save`, `find_by_id`, `find_all`, `delete` を実装

- マイグレーション: `20250104_create_library_items.sql`
  - テーブル定義とインデックスを追加
```

## Phase 4: ハンドラー/API層

### 説明すべきポイント

**GraphQL**
- 追加したQuery/Mutationは何か
- 引数と戻り値の型は何か

**REST**
- 追加したエンドポイントは何か
- HTTPメソッドとパスは何か

**例: 説明の仕方**
```markdown
### API層で追加したもの

#### GraphQL
- `createLibraryItem` mutation: アイテムを作成
  - 引数: `CreateLibraryItemInput { title, description, categoryId }`
  - 戻り値: `LibraryItem`

- `libraryItems` query: アイテム一覧を取得
  - 引数: `first`, `after`（ページネーション）
  - 戻り値: `LibraryItemConnection`

#### DI設定
- `di.rs` で `LibraryItemRepository` を登録
```

## Phase 5: フロントエンド

### 説明すべきポイント

**ページ構成**
- 追加したページは何か
- どのURLでアクセスできるか

**コンポーネント**
- 主要なコンポーネントは何か
- Server/Client Componentの選択理由

**状態管理**
- どんな状態を管理しているか
- GraphQLクエリの使い方

**例: 説明の仕方**
```markdown
### Frontend で追加したもの

#### ページ
- `/v1beta/[tenant_id]/library/items`: アイテム一覧ページ
- `/v1beta/[tenant_id]/library/items/new`: アイテム作成ページ

#### コンポーネント
- `LibraryItemList`: 一覧表示（Server Component）
- `LibraryItemForm`: 作成/編集フォーム（Client Component - インタラクション必要）

#### GraphQL
- `LibraryItemsQuery.graphql`: 一覧取得
- `CreateLibraryItemMutation.graphql`: 作成
```

## Phase 6: テスト

### 説明すべきポイント

**テスト方針**
- どんなテストを書いたか
- カバーしている範囲は何か

**シナリオテスト**
- APIのE2Eテストがあれば説明

**例: 説明の仕方**
```markdown
### テストで追加したもの

- ユニットテスト: `create_library_item_test.rs`
  - 正常系: アイテム作成成功
  - 異常系: バリデーションエラー、権限エラー

- シナリオテスト: `library_item_crud.yaml`
  - 作成 → 取得 → 更新 → 削除 の一連の流れをテスト
```

## 参照ドキュメント

- `CLAUDE.md` - プロジェクト規約
- `docs/src/for-developers/clean-architecture.md` - Clean Architecture規約
- `docs/src/for-developers/coding-conventions.md` - コーディング規約
