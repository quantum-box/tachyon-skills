---
name: formal-verification
description: >-
  Decide whether new or changed critical logic in a Tachyon codebase needs formal verification,
  then verify the production decision itself (Verus for Rust by default, TLA+ for ordering,
  retries, and concurrency), register it in the repository's pinned verification task and
  scheduled CI, and record proven properties and trusted boundaries in the repository ledger.
  Use proactively when implementing or changing authn/authz, tenant/resource binding, grants,
  billing/amount/currency, ledgers or budgets, state transitions with retries or callbacks, or
  approval/ownership logic; when a change touches code already listed as verified; or when
  the user asks for 形式検証 / Verus / TLA+.
---

# Formal Verification

テストは書いた例しか確かめない。形式検証は、決めた範囲の全入力または全実行順を確かめる。このスキルは、Tachyonで重要なロジックを新しく実装するときに、検証を最初から入れるための手順である。既存の検証対象を変更するときの保守手順も含む。

Tachyonの方針は [verification-policy.md](references/verification-policy.md) にある。作業前に読む。

## 0. リポジトリの現状を確かめる

作業するリポジトリで、次を探す。

- 固定版のverifierを取得して実行するrunner（例: `scripts/verus/`、`toolchain.json`、`verify.py`）。
- 検証のtask（例: `mise.toml` の `[tasks.verus]`）。
- 検証を定期実行しているCI job。
- 検証済み対象の台帳と、形式検証についてのADR。
- 既存の検証kernel（`verus!` を含むファイル）と、TLA+モデル（`*.tla`）。

```bash
rg -l 'verus!|vstd' --type rust; rg --files -g '*.tla' -g 'check.sh'; rg -n 'verus|tlc' mise.toml .github/workflows
```

基盤がすでにあれば、その形に合わせる。リポジトリの現行のコード・ADR・台帳が、このスキルや参照文書と食い違うときは、リポジトリに従う。そのうえで、食い違いを報告する。

基盤が無ければ、[kernelの登録チェックリスト](references/registering-a-kernel.md) の「基盤が無い場合」を先に行う。

## 1. 対象にするかを決める

「誤った判断で誰がどう困るか」で決める。純粋関数かどうかでは決めない。I/Oと混ざっていても、判断部分を切り出す作業ごと対象にする。

対象にするもの（1つでも当てはまれば対象）:

- 誤許可・越境: 主体/tenant/scope変換、grantの上限、resource限定、所有者照合、承認範囲。
- お金: 金額・単位・丸め・overflow、二重計上、再送、payer/口座の選択、利用権。
- 状態と時間: 世代・lease・callbackの到着順、結果不明からの回復、終端状態の安定性、単回消費。
- 既存の証明に入力を渡す変換（ここが検証外なら、既存の証明は守りたい性質を保証しない）。

対象外でよいもの: 表示整形、ログ、誤っても次の検査で必ず止まる前処理。外す場合は、その理由を台帳かPRに1行書く。

迷ったら、[判断の型と道具の選び方](references/choosing-the-check.md) を読む。

## 2. 道具を選ぶ

| 問い | 道具 | 置き場所 |
| --- | --- | --- |
| この関数は全入力で正しく判断するか | Verus（Rustの既定） | 本番crateが依存する検証kernelのcrate／module |
| 複数の操作・再送・並行実行が悪い順に並んだらどうなるか | TLA+/TLC | 対象パッケージの `formal/<topic>/` |
| DB CAS・transaction・時刻・JWT・外部API | 統合テスト | 境界として台帳へ記録する |

- Rust以外の言語で、コードに直接かけられるverifierが無い場合は、そう明記する。そのうえで、本番の関数に生成した入力を与えてテストする（property-based testなど）。手で書いた模型は使わない。
- TLA+を使ったときは、モデルの各actionを本番の関数やSQL文に1対1で対応づける。対応が取れない部分は、モデルの外の仮定として記録する。

## 3. 仕様を先に書く（コードより前）

PRか作業記録に、次を先に書く。

1. 業務意図と、防ぎたい不正操作（1文ずつ）。
2. 許可/受理の必要十分条件。拒否の各理由と、同時に成立したときのエラー優先。
3. 例外（System/Owner/Sandbox、互換経路など）。空入力、境界値（0・最大値・重複・同値表記）。
4. 現行コードとの差。違いがあれば、具体的な入力の反例で示す。

**証明が通らないときに仕様を弱めない。** 現行コードが性質を破るなら、それは発見である。

- バグ: 修正と回帰テストを、証明とは別のcommitにする。
- 仕様のほうが誤っていた: 意図の変更として理由を書き、人のレビューに回す。

未確定の業務意図を、証明しやすい前提で埋めない。

## 4. Verusで本番関数を検証する

- `verus! { }` の中に、spec fnと実行関数の両方を書く。本番crateはその実行関数を直接呼ぶ。
- コピーした模型は作らない。判定済みのboolだけを受け取る定理も作らない。ID・集合・金額の照合そのものを検証する。
- 公開関数は全域関数にする。`requires` を置かず、不正入力は返り値で拒否する。
- 中核に `assume`／`admit`／`external_body` を足さない。verifierは `--no-cheating` で実行する。
- 本番側の呼出元は、ドメイン型から検証kernelの入力（bytes・Vec・整数・enum）へ変換する薄いadapterにする。adapterが情報を落とさないこと（scope・tenant・単位）を、通常のテストで確かめる。
- ensuresは `result == spec(...)` の双方向で書く。片方向（`result ==> ...`）だと、常に拒否する実装でも通ってしまう。
- 手本になる既存のkernelがリポジトリにあれば、その書き方（spec名、bytes比較、ループ不変条件）に合わせる。

## 5. 失敗できることを示す

一度も失敗を見ていない証明は、何も示していない。

- 新しいkernelごとに、mutation cases（変異の定義）を用意する。
- 重要な条件を1つずつ壊す。例: 常に許可、常に拒否、照合を外す、Denyを無視、エラー優先を逆にする、境界を1ずらす、overflow checkを外す。
- 各変異が検証エラーとして拒否されることを確かめる。生き残った変異は、仕様の穴か、ensuresの書き方の誤りである。
- 偽の事後条件が拒否されること（self-test）も確かめる。verifierが何でも通す状態になっていないかを見るため。
- TLA+の場合は、各性質が、対応する変異で破れることを示す（例: `check.sh mutants`）。

## 6. 登録する

[kernelの登録チェックリスト](references/registering-a-kernel.md) に従う。要点:

- runner（固定版のverifier）に、source・入力digestの範囲・mutation casesを登録する。
- ローカルの検証task（例: `mise run verus`）に足す。
- 定期実行のCI job（例: mainの毎時batch）に足す。
- リポジトリがPRでCIを回さない方針なら、PR用のworkflowは増やさない。

## 7. 記録する

リポジトリの形式検証の台帳に、kernelごとに次を書く。

- 証明した性質（平文で1文ずつ）。
- 対象の本番関数・adapter・すべての呼出入口。
- 確認したcommit（sync commit）。
- 残る仮定と信頼境界（DB・時刻・外部API・並行更新）。
- 変異の一覧。

証明・変異・通常テスト・統合テストの結果は分けて書く。証明が通ったことから、実行していないテストの成功を推論しない。

## 既存の検証対象を変更するとき

台帳に載っている関数・adapter・呼出元を変えるときは、次の順で進める。

1. 変更前に検証taskを1回実行し、結果を控える。
2. 変更が次のどれに当たるかを決める。
   - 判断に影響しない。
   - 本番コードの形が変わり、検証が実装と食い違った（分岐・入口・値域の追加など）。
   - 意図して約束を変えた（根拠を示す）。
   - 根拠なく約束が破れた。
3. 検証を本番コードに合わせて直す。通すために性質を弱めない。性質を変えるのは、意図した仕様変更のときだけ。旧文言・新文言・根拠を残す。
4. 再実行する。
   - 通った場合: 新しい分岐を壊す変異を1つ足し、拒否されることを確かめる。
   - 失敗した場合: 反例を本番コードでたどる。たどれれば本番のバグ、たどれなければ検証側の誤り。
5. 台帳のsync commitを、確認したcommitへ進める。確認できなかったkernelのsync commitは進めず、そう報告する。

複数のcommitをまたいで、検証の追従が漏れていそうなときは、pstackの `/maintain-formal-verification-skill` の手順を使う（diffの読み方と判定の分類）。

## 完了の条件

- 仕様（意図・必要十分条件・例外・境界）が、PRか作業記録にある。
- 本番の呼出経路が、検証済みの実行関数を通っている。
- 検証taskが通り、self-testとすべての変異が拒否されている。
- 通常の回帰テストと、境界の統合テストが通っている。
- ローカルの検証taskと、定期実行のCIの両方に登録されている。
- 台帳に、性質・境界・sync commitが追記されている。
- リポジトリの最終チェックが通っている（例: `mise run ci`）。

## 報告

ユーザーへの報告には次を書く。

- 何を検証したか（平文）、道具とその理由、範囲と仮定。
- 見つかったバグや仕様の差（反例を手順で）。
- 検証していないもの。
- 実行コマンドと結果。PRには、少なくとも「verified件数・errors 0・変異の拒否数」と対象commitを書く。
