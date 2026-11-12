# kernelの登録チェックリスト

新しい検証kernelを、ローカルの検証taskと定期実行のCIで、継続して実行するための手順。まず、リポジトリにある既存のrunnerの構造を読む。kernelの一覧（registry）にまとまっていれば、そこへ1件足すだけでよい。

## 基盤が無い場合

最初のkernelを入れる前に、次をそろえる。

1. **固定版のtoolchain:** `toolchain.json` などに、次を記録する。
   - Verusのrelease版とcommit
   - 各platform向けassetのsha256
   - 対応するRustの版
   - Z3の版
2. **runner:** 次を行うscriptを用意する。
   - 固定版のverifierを、checksumを確かめて取得する。
   - 版を照合する。
   - `--no-cheating --output-json` で、単一sourceを検証する。
   - `--self-test`（偽の事後条件が拒否されること）と `--mutations` を扱う。
   - 証拠のJSONを書き出す。
3. **成功の条件:** 次をすべて満たしたときだけ成功とする。
   - 終了コードが0
   - JSONの `success` がtrue
   - `verified` が0より多い
   - `errors` が0
   - crate全体を検証している

   timeout、JSONが無い、空の検証は失敗として扱う。
4. **証拠のJSON:** 次を入れる。
   - commit、working treeが汚れているか
   - 実行引数
   - sourceとadapterのsha256
   - toolchainとverifierのsha256、solverの版
   - 結果、self-testの結果、実行秒数
5. **登録:** ローカルのtask（例: `mise run verus`）を作る。定期実行のCI jobに、期待するcommit（`--expected-commit`）を渡す形で登録する。証拠は、artifactとして保存する。
6. **ドキュメント:** 方針のADRと、台帳を作る。台帳には、対象・性質・境界・sync commitを書く。

## 1. kernelの置き場所

- 本番crateが依存できる場所に、crateかmoduleとして置く。
- crateにする場合は `Cargo.toml` に次を書く。
  - `vstd = "=<toolchain と同じ版>"`
  - `[package.metadata.verus] verify = true`
  - `unexpected_cfgs` の `check-cfg`（`verus_only` / `verus_keep_ghost` / `verus_keep_ghost_body`）
- runnerが単一ファイルを `--crate-type lib` で検証する形なら、kernelは1ファイルで閉じるようにし、vstd以外のcrateに依存させない。
- editionは、本番crateと合わせる。runnerがeditionをどう選ぶか（ファイル名、引数など）を確かめる。

## 2. runnerへの登録

- 対象sourceの一覧（`--source` の選択肢やregistry）に、新しいsourceを足す。
- 入力digestの対象に、kernelと、それを呼ぶadapter（ドメイン型からの変換）のディレクトリを足す。adapterのdigestが無いと、入力の変換が変わったことを証拠から追えない。
- mutation casesを、kernelごとのモジュールとして作る。`cases(source)` が `(name, mutated_source)` を返す形にする。sourceに応じて、そのモジュールが選ばれるようにする。
- runner自体のテストがあれば、それが通ることを確かめる。

## 3. ローカルの検証task

```bash
<runner> --source <path> --self-test --mutations --output target/verus/<name>.json
```

上の1行を足す。出力名はkernelごとに分け、既存のものと重ねない。

## 4. 定期実行のCI

- 既存の行と同じ形で、`--expected-commit` 付きの1行を足す。
- jobの時間上限を確かめる。追加後の合計時間を手元で測り、上限に近ければ報告する。
- リポジトリがPRでCIを回さない方針なら、PR用のworkflowには登録しない。

## 5. TLA+の場合

- 対象パッケージの `formal/<topic>/` に、`.tla` と `check.sh` を置く。`check.sh` は次を満たす。
  - TLC jarのsha256を固定する。
  - JDKは `mise` などで用意する。
  - 範囲（定数）を明記する。
  - `mutants` 引数で、各性質が対応する変異で破れることを確かめる。
- 定期実行のCIに登録する。登録しないなら、その理由を台帳に書く。

## 6. 確認

- 検証taskを実行する。そのうえで、新しいJSONで次を確かめる。
  - `success` がtrue
  - `errors` が0
  - crate全体を検証した
  - self-testとすべての変異が `true`（拒否された）
- 本番crateのテストも実行する。
- 複数の作業が同時に、runner・task・CI・台帳へ書き足していることが多い。PRの前にdefault branchへrebaseし、他のkernelの行を消していないかdiffで確かめる。
