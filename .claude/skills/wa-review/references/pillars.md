# ピラー一覧とリファレンスの入手先

リファレンス本文(数十万トークン規模)はこのリポジトリに含まれない。利用者が用意したローカルコピー、または公式ドキュメントを指定してもらう。設問 ID や本文を記憶から作らない。

| 対象 | フレームワーク | ピラー |
| --- | --- | --- |
| AWS(`aws/`、`aws-ai-terraform-validation`) | AWS Well-Architected Framework | Operational Excellence / Security / Reliability / Performance Efficiency / Cost Optimization / Sustainability(6) |
| Azure(`azure/`、`azure-ai-terraform-validation`) | Azure Well-Architected Framework | Reliability / Security / Cost Optimization / Operational Excellence / Performance Efficiency(5) |
| GCP(`gcp/`、`gcp-ai-terraform-validation`) | Google Cloud Well-Architected Framework | Operational excellence / Security, privacy, and compliance / Reliability / Cost optimization / Performance optimization(5。公式ドキュメントでピラー構成を要確認) |

マルチクラウドの `cloud-validation-level2-multicloud` は、`aws/` `azure/` `gcp/` を別々に Stage 1 から実行し、結果を並べる。

Azure と GCP のピラー構成は、レビュー前に公式ドキュメントで現在の構成を確認する。確認していない場合は、その旨を報告に書く。
