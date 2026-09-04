# 検証結果

## 結果

| 項目 | 結果 |
| --- | --- |
| Terraform整形 | `terraform fmt -check` 成功 |
| Terraform検証 | `terraform validate` 成功 |
| 初回plan | 必要リソースの追加計画を確認後に適用 |
| Web疎通 | ALB経由でNginxページのHTTP 200を確認 |
| 最終plan | `No changes` |
| 削除 | `terraform destroy` で全Terraform管理リソースを削除可能 |

## 作成対象

- VPC、Internet Gateway
- Public Subnet 2つ、Private Subnet 2つ、Route Tableと関連付け
- S3 Gateway Endpoint
- ALB、Listener、Target Group
- Security Group 2つと最小限の通信ルール
- Private EC2 2台とTarget Group登録

## セキュリティ上の確認

- EC2にPublic IPを割り当てない。
- インターネットからEC2へのSSHを許可しない。
- HTTP公開はALBのTCP 80に限定する。
- EC2へのHTTPはALB Security Groupを送信元とする。
- EC2からのパッケージ取得はS3 Prefix List宛てTCP 443に限定する。

本ドキュメントには実環境のURL、IPアドレス、AWSアカウントID、アクセスキー、リソースIDを記載しない。
