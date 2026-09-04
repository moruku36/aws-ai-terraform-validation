# アーキテクチャ

以下は公開用に一般化した構成図です。IPアドレス、AWSアカウントID、リソースIDは含めていません。

```mermaid
flowchart TB
    Internet((Internet))

    subgraph AWS["AWS / ap-northeast-1"]
        subgraph VPC["VPC"]
            IGW["Internet Gateway"]

            subgraph Public["Public Subnets / 2 AZs"]
                ALB["Application Load Balancer\nInternet-facing / HTTP :80"]
            end

            subgraph Private["Private Subnets / 2 AZs"]
                EC2A["EC2 Web #1\nAmazon Linux 2023 + Nginx\nPublic IPなし"]
                EC2B["EC2 Web #2\nAmazon Linux 2023 + Nginx\nPublic IPなし"]
            end

            S3EP["S3 Gateway Endpoint\nAmazon Linux package repository"]
        end
    end

    Internet -->|"HTTP :80"| ALB
    IGW --- ALB
    ALB -->|"HTTP :80\nALB SGからのみ"| EC2A
    ALB -->|"HTTP :80\nALB SGからのみ"| EC2B
    EC2A -->|"HTTPS :443\nS3 managed prefix listのみ"| S3EP
    EC2B -->|"HTTPS :443\nS3 managed prefix listのみ"| S3EP
```

## 通信ルール

| 送信元 | 宛先 | プロトコル / ポート | 用途 |
| --- | --- | --- | --- |
| Internet | ALB | HTTP / 80 | Webアクセス |
| ALB Security Group | EC2 Security Group | HTTP / 80 | アプリケーション通信・ヘルスチェック |
| EC2 Security Group | AWS管理S3 Prefix List | HTTPS / 443 | Amazon Linuxパッケージ取得 |

EC2へのSSH（TCP 22）ルールは作成しない。Private SubnetのRoute Tableにはインターネット向けデフォルトルートを置かず、NAT Gatewayも使わない。
