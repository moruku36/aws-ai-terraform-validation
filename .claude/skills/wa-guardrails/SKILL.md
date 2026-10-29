---
name: wa-guardrails
description: wa-review の High / Critical 指摘を、再発防止の CI チェック案とクラウド側の統制案に変換して guardrails/ に生成する。
when_to_use: "TRIGGER when: ユーザーが明示的に /wa-guardrails を実行したとき。 SKIP: AI の判断での自動実行、レビュー自体、terraform の apply、クラウド設定の実変更。"
disable-model-invocation: true
---

# wa-guardrails

検出(wa-review)を予防に変える。出力は `guardrails/` 配下のファイルだけで、クラウド側の設定は変更せず、ワークフローは自動では有効にしない。

## 入力
`wa-review` の High / Critical 指摘(例: IAM ワイルドカード、SG 全開放、暗号化漏れ、バックアップ未設定、削除保護やクリーンアップ手順の欠落)。指摘がなければ、先に `wa-review` を実行するよう案内して止まる。

## 手順
1. 指摘を、`references/guardrail-catalog.md` の統制手段(CI チェック / 権限境界 / 組織ポリシー)に対応づける。
2. `guardrails/` に、チェック設定(checkov / trivy のルール設定、必要ならカスタム検証スクリプト)と、`guardrails/README.md` を生成する。
3. 各ガードレールに、次の3点を必ず書く。
   - 予防できる範囲
   - 限界(例: SCP では防げない項目は CI と権限境界で代替する)
   - 元の指摘(`ファイルパス:行番号`)
4. 生成したチェックの実行結果がない場合は、`UNEXECUTED` と書く。実行して確認したものだけを「動作確認済み」と書く。

## 守ること
- 既存の `.github/workflows/` は変更しない。CI への組み込みは差分案として提示し、人が確認して反映する。
- 費用・認証・権限の変更が必要な統制は、案として書くだけで実施しない。
