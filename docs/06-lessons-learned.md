# 学びと次の段階

## 今回の学び

1. **AIは実装だけでなく検証・修正まで担える**
   - Terraformコードの分割、バージョン固定、整形、検証、plan確認、適用、HTTP疎通、原因分析と修正まで一連で実施できた。

2. **Private Subnetでは外向き通信設計が重要**
   - EC2を非公開にするだけでは起動時のパッケージ導入は成立しない。NATを使わない場合、VPC Endpoint、Route Table、Endpoint Policy、Security Group Egressを整合させる必要がある。

3. **疎通確認はALB到達だけでは不十分**
   - ALBが応答しても502となることがある。Target Groupの実アプリケーション応答まで確認することで、Nginx導入失敗を検出できた。

4. **planの確認と状態の収束確認が有効**
   - 適用前のplanで作成・置換対象を確認し、修正後に`terraform plan`が`No changes`となることを確認した。

## 次の検証ステップ

### Phase 2: CI/CD

- Pull Requestで`terraform fmt -check`、`terraform validate`、`terraform plan`を実行する。
- plan結果をレビュー可能な形で保存・表示する。
- applyとdestroyの実行条件を明確にする。

### Phase 3: GitHub Actions OIDC

- 長期Access KeyをCI/CDに置かない。
- GitHub Actions用IAM RoleとOIDC Trust Policyを最小権限で設計する。
- 対象リポジトリ、ブランチ、EnvironmentをTrust Policyで制限する。

### Phase 4: Monitoring

- ALBのHTTPコード、Target GroupのHealthyHostCount、EC2の基本メトリクスを監視する。
- 502/5xxやUnhealthy Hostを検知できるアラームを検討する。
- 監視のコストと通知経路もTerraformで管理する。

## 公開前チェックリスト

- [ ] `terraform.tfstate`、バックアップ、`.terraform/`をGitへ追加しない。
- [ ] `terraform.tfvars`に認証情報や実環境固有の設定を置かない。
- [ ] Access Key、Secret Key、AWSアカウントID、実IP、リソースIDを文書・画像・ログに含めない。
- [ ] ALB URLなど、公開が不要な実環境URLを文書に含めない。
- [ ] `terraform plan`を確認してから`terraform apply`を実行する。
