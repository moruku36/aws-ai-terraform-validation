# Antigravity向け引継ぎ

## この検証の目的

このリポジトリは、AIエージェントにAWSインフラ実装とTerraform運用をどこまで安全に任せられるかを検証するためのものです。単にリソースを作るだけでなく、次の一連を人間の最終判断を残しながら再現可能にすることを目標としています。

1. TerraformでAWSの最小Web基盤を構築する。
2. 外部公開・通信経路・State管理を安全に設計する。
3. GitHub Actionsから長期Access KeyなしでTerraformを実行する。
4. Pull Requestとmain mergeで実行権限を分離する。
5. 変更・失敗・判断を公開可能な文書として残す。

Antigravityには、まず本書と`README.md`、`docs/01-scenario.md`から`docs/07-cicd-oidc-remote-state.md`、`.github/workflows/`、`bootstrap/`を読ませてください。実環境の識別子、Credential、Stateはリポジトリに存在しません。

## 現在の到達点

以下は実環境で確認済みです。

- AWS東京リージョンに、VPC、Public/Private Subnet各2つ、Internet Gateway、Application Load Balancer、Private EC2 2台をTerraformで構築。
- EC2にPublic IPはなく、SSHはインターネット公開しない。外部から許可する通信はALBのHTTPだけ。
- ALBからEC2へはHTTP 80だけを許可。EC2はS3 Gateway Endpoint経由で必要なHTTPS通信だけを行い、Amazon Linux上でNginxが稼働。
- ALB経由のHTTP 200を確認済み。
- Terraform StateはS3 backendに移行済み。S3 Versioning、SSE-S3、Public Access Block、TLS強制を設定し、DynamoDBは使わず`use_lockfile = true`でS3 native lockfileを使う。
- bootstrapはState Bucket、GitHub OIDC Provider、GitHub Actions用IAM Roleおよびinline policyを管理する。
- GitHub Actionsでは、同一リポジトリからのPRでfmt / validate / OIDC / Remote State planを実行する。fork由来PRではAWS権限を使うjobを実行しない。
- main mergeでは`terraform-production` Environmentを使ってOIDC認証、plan、applyを実行する。
- PR workflowおよびmain merge後のapply workflowは、ともにOIDC認証に成功し、最終planは`No changes`、applyは追加0・変更0・削除0で成功した。

## 現在の設計

### Terraform構成

- Root: アプリケーション基盤。`provider.tf`、`variables.tf`、`main.tf`、`outputs.tf`に分離。
- `bootstrap/`: Remote StateとGitHub OIDC/IAMの初期構成。Rootとは別State。
- `backend.tf`: Git管理対象外。S3 backendの`use_lockfile = true`のみを含む。
- `backend.tf.example`: backend設定のテンプレート。
- `terraform.tfvars`およびbootstrapの実運用用tfvars: Git管理対象外。Credentialは書かない。

### GitHub Actions

- `.github/workflows/terraform-pr.yml`
  - 全PRでfmtとvalidateを実行。
  - 同一リポジトリ起点のPRだけが`id-token: write`を得てOIDC認証し、Remote Stateを使うread-only planを実行。
  - PR workflowにapplyはない。
- `.github/workflows/terraform-apply.yml`
  - mainへの対象ファイル変更を含むpushで実行。
  - `terraform-production` Environmentを指定。
  - OIDC認証後にplanを保存し、その同一planをapplyする。

### AWS認証・State

- GitHub SecretsにAWS Access Key / Secret Access Keyを置かない。
- GitHub Repository Variablesにはリージョン、State Bucket、State Key、Role ARNに相当する値だけを設定済み。値そのものをログ・文書・コードに書かない。
- OIDC ProviderのAudienceは`sts.amazonaws.com`に限定。
- Role Trust Policyは、同一リポジトリのPR用subjectと`terraform-production` Environment用subjectを限定許可する。
- このGitHubアカウントではOIDC subjectにowner/repository IDを含むcustom形式が発行される。実際のsubject文字列はGit管理外のbootstrap tfvarsで渡し、公開文書には一般形だけを記載する。
- State用Role権限はState Objectと`.tflock` Objectの必要操作に限定する。SSE-S3のためKMS権限は不要。

## 実施中に判明した重要事項

1. Private EC2からS3へのHTTPS通信をSecurity Groupで許可していないと、パッケージ取得に失敗し、ALBで502になる。AWS管理S3 Prefix List宛TCP 443を許可し、EC2再作成後にHTTP 200を確認した。
2. HashiCorpの現行S3 backend仕様に合わせ、DynamoDB lockingではなく`use_lockfile = true`を採用した。
3. GitHubのOIDC subjectは標準の`repo:<owner>/<repository>:...`ではなく、repository IDを含むcustom形式だった。PR用とEnvironment用を実際に短時間の診断jobで確認し、Trust Policyを最小範囲で合わせた。診断jobは削除済み。
4. bootstrap Stateをrefreshするだけでも、S3/IAMの読取権限が不足するとplanが止まる。一時bootstrap policyは必要時だけ使い、既存リソースに限定し、権限不足時に自動拡張しない運用を採用した。

## Antigravityが作業を始める前の確認事項

次の順で、変更なしの確認から始めてください。

```powershell
git status
git switch main
git pull --ff-only origin main
terraform fmt -check -recursive
terraform validate
terraform plan
```

注意事項:

- AWS Credential、State、backend実値、実リソースID、ALB URL、Account ID、Role ARNを出力・保存・commitしない。
- `terraform apply`、GitHub main merge、IAM変更、State移行、destroyの前には必ずplanまたは差分を確認し、人間の明示承認を得る。
- AccessDeniedが発生した場合は権限を自動追加しない。Action、Resource、対象Terraform resourceを特定して停止する。
- `bootstrap/`は通常のRoot変更で実行しない。State backend、OIDC、Role policyを変更する必要があるときだけ、最小権限の一時Identityで扱う。
- Stateやbootstrapの操作に、アプリケーション用の広い権限や一時管理権限を流用しない。
- `terraform destroy`は検証環境を消すため、ユーザーが明示的に依頼した場合だけ実行する。

## 残っている検証

次の項目は未実施または深掘り候補です。上から順に進めると安全です。

1. **実際の変更を伴うCI/CD apply**
   - 現在のapply workflowは`No changes`のapply成功まで確認済み。
   - 次は、低リスクかつ可逆なTerraform変更をPRで提案し、PR planの差分、レビュー、main merge、apply、post-apply planを一連で確認する。
   - 変更内容と期待差分を先に人間が承認する。ALB/EC2の置換、ネットワーク削除、公開範囲の拡大を伴う変更は避ける。
2. **GitHub運用のガードレール**
   - mainのBranch Protection、PR review必須化、status check必須化を確認・必要に応じて設定する。
   - `terraform-production` Environmentのrequired reviewersやdeployment protection rulesを、必要な運用レベルに合わせて検証する。
   - 同一リポジトリのPRはOIDC Roleを得られるため、workflow変更を含むPRにはレビュー・Branch Protectionが特に重要である。
3. **IAM最小権限の継続的な見直し**
   - GitHub Actions RoleのEC2/ELB管理権限にはAWS API仕様上Resource制限が難しいActionが含まれる。CloudTrail等の実使用Actionを根拠に絞り込み候補を評価する。
   - bootstrapに使った一時IAM inline policyが残っていれば、必要性を確認後に専用のcleanup手順で削除する。削除権限は普段のpolicyに追加しない。
4. **監視と運用性**
   - ALBのHTTP 5xx、Target GroupのUnHealthyHostCount、EC2 StatusCheckFailedなどのCloudWatch Alarmを設計・追加する。
   - 通知先、ログ保持期間、コスト上限を人間と決めてから実装する。
5. **障害・安全性テスト**
   - fork PRがAWS権限を使えないこと、PRでapplyされないこと、State lock競合時に安全に待機・失敗することを、破壊しない方法で確認する。
   - S3 State Bucketのpublic access block、TLS強制、versioning、lockfile権限を定期的に検証する。
6. **終了・クリーンアップ検証**
   - 検証終了時のみ、destroy planを人間と確認してから実行し、S3 StateとVersioned Object、bootstrap resourcesをどう扱うか別途決める。

## Antigravityに渡す開始プロンプト

以下をそのまま渡せます。

```text
このリポジトリはAWS + Terraform + GitHub Actions OIDCの検証環境です。
まず README.md と docs/08-antigravity-handoff.md、docs/07-cicd-oidc-remote-state.md、.github/workflows/、bootstrap/ を読み、現在の設計と安全制約を理解してください。

実環境のCredential、State、backend実値、AWS Account ID、Role ARN、リソースID、ALB URLは出力・保存・commitしないでください。
作業開始時は git status、main最新化、terraform fmt -check、validate、planで変更なしを確認してください。
apply、IAM変更、main merge、State操作、destroyの前にはplanを確認し、想定外の差分やAccessDeniedでは権限を自動拡張せず停止して原因を報告してください。

次の候補は、低リスクで可逆なTerraform変更をPRからmainへ通し、CI/CD applyの実変更まで確認することです。実装前に、変更内容・期待plan・影響範囲を提示してください。
```
