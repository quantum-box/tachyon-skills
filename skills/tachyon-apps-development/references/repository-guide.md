# Agents Quick Guide

## 入口ルール

- 会話は常に丁寧な日本語で行う。コードコメントとコミットメッセージは英語で書く。
- 詳細な開発プロセス、基本コマンド、品質チェック、コード規約は `development-process` スキルを正とする。ここには常時読むべき横断ルールだけを書く。
- `serena mcp` が利用可能なときは優先して使う。調査・差分確認・編集は Serena の検索/シンボル/編集ツールを先に試し、通常のシェルコマンドは補助にする。
- タスクランナーは `mise run` を使う。`just` は使わない。
- PRはReadyで作る。PRタイトルに `[codex]` を付けない。
- Linearで先行issueに依存する後続タスク（`blocked by`）や、実装が先行PRを前提とするタスクは同じ作業列として扱う。先行PRが未マージなら後続タスクはstack PRにし、後続ブランチは直前PRのheadから切り、PR baseも直前PRのブランチにする。
- issueを作るときはGitHub issueではなくLinear issueを作る。このrepoでは `プラットフォーム事業` teamを使う。
- GitHubリポジトリの作成・変更・削除は、`gh` やGitHub UIで直接行わず、必ず `quantum-box/governance` リポジトリのTerraformで管理する。
- 普段使いの `gh` 認証はread-onlyまたは未認証に限定し、`admin:org`、`repo`、`workflow` などの強い権限を保存しない。
- 秘密情報はコミットしない。`.env.local`、`.secrets.json` などのローカルファイルで管理する。
- Tachyon pluginの `tachyon-apps-development` スキルをrepo固有Codexガイドの正本とする。repo rootの `AGENTS.md` はpluginを案内し、`CLAUDE.md` はこれをimportしてClaude固有の補足だけを持つ。
- Rust変更のlocal検証は変更範囲に対する最小チェックを優先し、workspace全体・Docker・CI相当の重い検証はPR前・merge前・高リスク変更時に限定する。未実行の検証は最終報告に明記する。
- browserを使う時はin-app browserまたは `browser-test` / `agent-browser` 系スキルを使うとよい。UI変更の動作確認をAPI疎通だけで完了扱いにしない。
- Tachyon apps向けCodexスキルの正本は `quantum-box/tachyon-skills` pluginとする。Claude固有スキルは `.claude/skills/` に置き、旧 `.agents/skills/` は使わない。

## スキルルーティング

- 非自明な開発を始める前に `development-process` を使い、標準フロー、基本コマンド、品質チェック、コード規約、taskdoc/DD/ADR運用を確認する。
- 現状把握が必要なら `project-status`、ドメイン文脈が必要なら `context-loader`、既存実装パターン確認は `explore` / `find-pattern` を使う。
- そこそこの規模の実装では `taskdoc-create` を使う。taskdocは実行ログと検証エビデンスであり、設計判断の置き場ではない。
- API、DB、UI workflow、クロスコンテキスト、認可、課金、デプロイ、運用に影響する設計は `design-doc` を使う。
- 長期的なアーキテクチャ判断、採用/非採用判断、運用ルールは `adr-check` を使い、既存ADRを確認してから作成・更新する。
- 実装時は `implement-*`、`create-migration`、`codegen`、`create-scenario-test`、`create-storybook` など該当スキルを優先する。
- DBスキーマ変更は必ず `create-migration` を使い、TiDB互換性とプロジェクト規約をそこで確認する。
- TypeScript/Rustの重い品質チェック系スキルは普段使いしない。通常は `development-process` の軽量チェックを使い、PR前や高リスク変更で `rust-quality-checker` / `node-quality-checker` / `final-quality-gate` を使う。
- PR Ready準備、対象componentの最低patch version bump、taskdoc archiveは `task-pr-ready` を使う。すべての実装PRで少なくともpatch versionを上げる。merge後のchangelog、release notes、tag、post-merge docsは `task-complete` を使う。
- `in-progress` taskdocが溜まったら `taskdoc-audit` を使い、実作業中でないものを `todo` / `backlog` / `completed` へ戻す。

## ドキュメント配置

- 基本コマンド、細かいコード規約、テスト手順、ローカルURL、開発用ヘッダーなどは `development-process` スキルに置く。
- ドメイン固有の設計はDD、長期的な意思決定はADR、作業進捗と検証結果はtaskdocに置く。
- 古い知見や一時的な実装メモを `AGENTS.md` / `CLAUDE.md` に追記しない。必要なら既存DD/ADR/taskdocを探し、なければ適切なドキュメントを作る。
