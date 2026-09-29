---
name: design-doc
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Create or update Tachyon Design Documents (DDs). Use proactively when: (1) API, DB, UI
  workflow, or cross-context behavior is being designed, (2) implementation needs a plan before
  code, (3) the user asks for DD/design doc, or (4) a taskdoc contains design details that
  should be separated.
---

# Design Doc

## Purpose

Use a DD to explain the design before implementation. A DD is not a progress
log; it captures the proposed shape of the solution, key alternatives, rollout,
and test strategy. The taskdoc links to it and tracks execution.

## When To Create

Create a DD for:

- new APIs, GraphQL mutations, REST endpoints, or public SDK behavior
- database schema or migration strategy
- cross-context Clean Architecture changes
- UI workflows with meaningful product behavior
- security, authz, billing, deployment, or operational behavior
- changes that need review before implementation

Do not create a DD for:

- small bug fixes with an obvious local fix
- formatting, warning cleanup, or trivial copy changes
- pure verification or investigation logs

## Location

- Delivery-specific DD: `docs/src/tasks/<bucket>/<slug>/design.md`
- Durable service docs: `docs/src/services/<service>/<feature>.md`
- Tachyon product docs: `docs/src/tachyon-apps/<category>/<feature>.md`
- Architecture docs: `docs/src/architecture/<component>.md`

Use `docs/src/template/software-design-document.md` as the starting structure
when a full DD is needed. Keep task-local DDs concise.

## Workflow

1. Confirm scope.
   - Link the Linear issue and taskdoc.
   - State goals and non-goals.
   - Identify affected modules and owners.

2. Write the design（文体と構成は下記 Writing Style に従う）。
   - Context and problem statement
   - Options considered
   - Proposed design
   - API / UI / data model changes
   - Migration and rollout plan
   - Security, authz, billing, and operational considerations
   - Test and verification plan
   - Open questions and deferred work

3. Decide whether an ADR is required.
   - If the DD chooses a long-lived architectural rule, provider strategy,
     security constraint, or adoption/rejection decision, create or update an
     ADR with `adr-check`.

4. Link everything.
   - Link the DD from `task.md`.
   - Link related ADRs from the DD.
   - Update `docs/SUMMARY.md` when the DD is durable or reader-facing.

## Writing Style（DDは人間が読むための文書）

DDは日本語で書く（`docs/src` 配下の文書は日本語。コードコメントとコミット
メッセージは英語のまま）。読み手はレビューアと、数か月後に「なぜこの設計に
したのか」を調べに来る人である。仕様の網羅的な羅列やテンプレートの機械的な
穴埋めではなく、**設計の理由が地の文で追える文書**にする。

良い例: `docs/src/tasks/completed/v0.29.47/plt-3165-user-profile-lost-update/design.md`

- 問題: 現象から入り、「なぜ既存の仕組みでは解けないのか」まで段落で書く。
  解決案から書き始めない。読み手が問題を再現できるだけの具体（対象コード、
  失敗する条件）を含める。
- 検討した選択肢: 不採用案こそ理由とセットで残す。後から同じ案が再提案
  されるのを防ぐのが目的なので、「筋は通るがこの制約と衝突する」まで書く。
- 採用設計: 何を選んだかより、なぜ選べたかを書く。**守る不変条件**（この
  変更で絶対に壊してはいけないもの）を明示する。既存挙動が変わらない範囲も
  書く（「宣言ゼロなら挙動不変」など）。
- 図: plantuml / mermaid は、データモデルの関連や分岐の多い評価フローなど
  「文章にすると本当に長くなる」ものだけに使う。図は本文の要約であって代替
  ではないので、図を貼って地の文の説明を省略しない。図が2枚を超えたら、
  本文で説明すべきことを図に押し込んでいないか疑う。
- 表: 短く列挙できる事実（対応表、フィールド所有権、フェーズ一覧）に使う。
  説明は表のセルではなく地の文に置く。
- ロールアウト: 段階ごとに「何が変わるか」を書く。**戻し方**（ロールバック
  手順と、戻したときに何が起きるか）を必ず書く。
- 未解決の課題: 先送りした判断は「いつ・何をトリガーに・誰が決めるか」まで
  書く。「Phase 3で判断する」のように条件を残す。
- 文体: だ・である調または体言止め。ID・パス・型名・テーブル名はコード
  スパンにする。冗長な前置きや定型文は書かない。

## Output

Report:

- DD path
- linked taskdoc
- linked ADRs, if any
- open questions
- implementation entry points
