# AWS + Terraform 検証環境

## 検証目的

AI/Codex にどこまでAWSインフラ実装を任せられるかを検証する、最小構成かつ破棄可能なTerraform環境です。現在はネットワーク、ALB、Private EC2、Nginxの構築と疎通確認まで完了しています。

今後は同じリポジトリを基に、TerraformのCI/CD、GitHub ActionsからAWSへのOIDC認証、監視を段階的に検証します。

## 現在の進捗

- AWS東京リージョンにVPC、Public / Private Subnet各2つ、ALB、Private EC2 2台を構築済み
- EC2にPublic IPおよびSSH公開はなく、外部公開はALBのHTTPのみ
- ALB経由でNginxのHTTP 200を確認済み
- 最終 `terraform plan` は `No changes`

> このリポジトリには認証情報、Terraform state、実環境のリソースIDやIPアドレスを含めません。

## 再現手順

前提: Terraform `>= 1.8.0, < 2.0.0`、AWS認証済みのローカル環境、対象リソースを作成できる最小権限。

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform plan -out tfplan
# planを確認してから実行する
terraform apply tfplan
terraform output -raw alb_url
```

検証終了後は、課金を止めるために必ず削除します。

```powershell
terraform destroy
```

## ドキュメント

- [検証シナリオ](docs/01-scenario.md)
- [アーキテクチャ](docs/02-architecture.md)
- [実装内容](docs/03-implementation.md)
- [トラブルシューティング](docs/04-troubleshooting.md)
- [検証結果](docs/05-results.md)
- [学びと次の段階](docs/06-lessons-learned.md)
- [CI/CD・OIDC・Remote State](docs/07-cicd-oidc-remote-state.md)
