# 実装内容

## Terraform構成

| ファイル | 役割 |
| --- | --- |
| `provider.tf` | Terraform / AWS Providerのバージョン固定、リージョン、共通タグ |
| `variables.tf` | リージョン、CIDR、AZ、インスタンスタイプなどの入力 |
| `main.tf` | VPC、Subnet、Route Table、Security Group、S3 Endpoint、ALB、EC2 |
| `outputs.tf` | ALB URL、EC2 ID一覧、VPC IDの出力 |
| `terraform.tfvars.example` | 上書き用の公開可能な設定例 |

Terraformは `>= 1.8.0, < 2.0.0`、AWS Providerは完全一致バージョンで固定している。

## 実装上の判断

### Private EC2でのNginx導入

Private EC2にNAT Gatewayを置かないため、一般的なインターネット経由でのパッケージ取得は行わない。Private Route TableにS3 Gateway Endpointを関連付け、Amazon Linux 2023のリポジトリバケットへの読み取りだけをEndpoint Policyで許可する。

さらにEC2 Security Groupの外向き通信は、AWS管理S3 Prefix List宛てのTCP 443に限定する。

### Security Group

- ALB: InternetからTCP 80を受信し、EC2 Security GroupへTCP 80を送信する。
- EC2: ALB Security GroupからTCP 80を受信する。外向きはS3 Prefix ListへのTCP 443だけを許可する。

### Nginx設定

EC2の`user_data`でNginxを導入・起動し、ホスト名を含む簡単なHTMLを配置する。Nginx導入に関わる`user_data`変更時は、初期化を確実にやり直すためEC2を置換する。

## 実行フロー

```powershell
terraform init
terraform fmt -check
terraform validate
terraform plan -out tfplan
# 内容を確認
terraform apply tfplan
terraform output -raw alb_url
```

認証情報はAWS SSO、プロファイル、または実行環境の一時環境変数で渡し、Terraform設定やGitへ保存しない。
