---
name: wa-review
description: Terraform コードを Well-Architected の観点で、棚卸し→簡易採点→弱点ピラーのみ深掘りの2段階でレビューする。
when_to_use: "TRIGGER when: 「/wa-review」「Well-Architected レビュー」「Terraform の設計レビュー」「ピラー別に採点」を求められたとき。 SKIP: コードの修正、terraform の plan/apply、CI チェックの生成(それは wa-guardrails)。"
allowed-tools: Read, Grep, Glob, AskUserQuestion
---

# wa-review

全リファレンスを一度に読み込まない。簡易採点で弱点を絞り、該当ピラーだけを1設問ずつ読む。読み取り専用で、`terraform plan` / `apply` は実行しない。

## Stage 1: Quick Review
1. `*.tf`(`main.tf` / `variables.tf` / `outputs.tf` / `monitoring.tf` など)のリソースを棚卸しする。
2. 評価対象の business criticality(`standard` / `validation-lab` など)を、AskUserQuestion で明示的に確認する。コード内の `environment = "production"` のような変数だけで、基準を厳しくしない。
3. 対象クラウドのピラー(`references/pillars.md`)ごとに、設問レベルで素早く採点し、弱いピラーを決める。
4. 採点結果と、深掘りするピラーの一覧を先に報告する。

## Stage 2: Pillar-Specific Deep Dive
1. Stage 1 で低かったピラーだけを対象にする。特に Security、Cost Optimization、削除・クリーンアップを含む Operational Excellence / Reliability を優先する。
2. そのピラーのリファレンスを、1設問ずつ逐次ロードする(`references/pillars.md` の入手先)。
3. 各所見に `ファイルパス:行番号`(例: `main.tf:82-97`)の根拠と、深刻度(Critical / High / Medium / Low)を付ける。
4. コードから判断できない項目(転送時の SSL 強制、組織側の統制など)は推測せず、**Cannot Determine(判断不能)** と返す。

## 守ること
- 事実(コードに書いてあること)、観測(実行して確認したこと)、推測を区別する。実行していない確認を「確認済み」と書かない。
- ファイルを書き換えない。修正は人または implementer が行う。
- High / Critical の所見は、`wa-guardrails` への入力になる。
