# アーキテクチャ

## 構成図

![AWS検証環境のアーキテクチャ構成図](images/aws-architecture.png)

```mermaid
flowchart TB
    Internet((Internet User))

    subgraph AWS["AWS / ap-northeast-1 (Tokyo)"]
        subgraph VPC["VPC (10.0.0.0/16)"]
            IGW["Internet Gateway"]

            subgraph Public["Public Subnets (2 AZs)"]
                ALB["Application Load Balancer<br/>Internet-facing / HTTP :80"]
                RT_Pub["Public Route Table<br/>0.0.0.0/0 -> IGW"]
            end

            subgraph Private["Private Subnets (2 AZs)"]
                subgraph AZ_1["AZ 1 (ap-northeast-1a)"]
                    EC2A["EC2 Web #1<br/>AL2023 + Nginx<br/>No Public IP"]
                end
                subgraph AZ_2["AZ 2 (ap-northeast-1c)"]
                    EC2B["EC2 Web #2<br/>AL2023 + Nginx<br/>No Public IP"]
                end
                RT_Priv["Private Route Table<br/>No 0.0.0.0/0 Route<br/>S3 PL -> S3 Endpoint"]
            end

            S3EP["S3 Gateway Endpoint<br/>com.amazonaws.ap-northeast-1.s3<br/>Amazon Linux repo"]
        end

        subgraph Monitoring["Observability"]
            CW["CloudWatch Alarms (7件)<br/>HealthyHost / 5xx / CPU / StatusCheck"]
            S3Log["S3 Bucket<br/>ALB Access Logs (14日保持)"]
        end
    end

    Internet -->|"HTTP :80"| ALB
    IGW --- ALB
    ALB -->|"HTTP :80<br/>(Source: ALB-SG)"| EC2A
    ALB -->|"HTTP :80<br/>(Source: ALB-SG)"| EC2B
    EC2A -->|"HTTPS :443<br/>(S3 Prefix List)"| S3EP
    EC2B -->|"HTTPS :443<br/>(S3 Prefix List)"| S3EP

    ALB -. "アクセスログ配信" .-> S3Log
    ALB -. "ELB/Targetメトリクス" .-> CW
    EC2A -. "System/Instanceメトリクス" .-> CW
    EC2B -. "System/Instanceメトリクス" .-> CW
```

## 通信ルールとセキュリティ境界

### Security Group ルールマトリクス

| リソース | 方向 | プロトコル / ポート | 送信元 / 宛先 | 用途 / 備考 |
| --- | --- | --- | --- | --- |
| **ALB SG** | Ingress | TCP / 80 | `0.0.0.0/0` | インターネットからのHTTPアクセス |
| **ALB SG** | Egress | TCP / 80 | EC2 SG | バックエンドEC2インスタンスへのトラフィック転送 & Health Check |
| **EC2 SG** | Ingress | TCP / 80 | ALB SG | ALBからの転送のみ許可（直接アクセス不可） |
| **EC2 SG** | Egress | TCP / 443 | `pl-xxxx` (AWS managed S3 prefix list) | AL2023のパッケージリポジトリ（dnf / Nginx導入） |
| **EC2 SG** | Egress | TCP / 80 | 不許可 | 外部Web通信禁止 |
| **EC2 SG** | Ingress | TCP / 22 | 不許可 | SSHアクセス禁止（インターネット・ローカル共に開放なし） |

### ルーティング設計

| Route Table | 宛先 CIDR / ターゲット | 経由先 | 備考 |
|---|---|---|---|
| **Public Route Table** | `0.0.0.0/0` | Internet Gateway (IGW) | ALBのインターネット公開用 |
| **Private Route Table** | S3 Prefix List | S3 Gateway Endpoint | VPCエンドポイント経由通信（無料・プライベート） |
| **Private Route Table** | `0.0.0.0/0` | **なし (Default route 未作成)** | インターネット直出不可・NAT Gateway非配置 |

## AWS固有の設計判断

1. **NAT Gatewayの排除とS3 Gateway Endpointの採用**:
   - Private EC2上のOSパッケージ（Amazon Linux 2023）はAWSが管理するS3リポジトリから配信されます。
   - NAT Gatewayを配置せず、無料のS3 Gateway Endpoint + S3 Managed Prefix ListによるEgress限定ルーティングを採用することで、NAT Gatewayの維持費（約32 USD/月）を削減しつつ十分なセキュリティを担保しました。
2. **2 AZ分散による高可用性**:
   - ALBおよびEC2を東京リージョンの2つの異なるAZ（`ap-northeast-1a`, `ap-northeast-1c`）に跨いで配置し、片系AZ障害への耐性を確保。
3. **完全SSHレス運用**:
   - EC2へのSSHポート開放やキーペア設定を行わず、ユーザーデータ（cloud-init）による自律プロビジョニングのみでNginxを起動。攻撃サーフェスを最小化しています。
