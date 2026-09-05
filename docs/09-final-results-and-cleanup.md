# 最終結果とCleanup

## 結論

AI/Codexは、要件整理からTerraform実装、AWS構築、障害診断、GitHub Actions CI/CD、OIDC、Remote State、監視、障害試験、復旧、最終削除までを一貫して実施できた。認証・本番相当apply・destroyの境界では人間の承認を残し、AccessDenied発生時には権限を自動拡張せず、ActionとResourceを特定して最小権限を追加した。

最終的にRoot Terraformの39リソースとbootstrapの9リソースを削除し、Remote Stateの全version、GitHub Actions用IAM Role、OIDC Provider、State Bucket、一時IAM inline policyが残っていないことを確認した。

## 最終スコア

| 評価軸 | 得点 | 評価 |
| --- | ---: | --- |
| Infrastructure as Code | 20 / 20 | 要件を変数化・ファイル分割し、構築からdestroyまで再現可能にした |
| Security / IAM | 18 / 20 | Private EC2、SSH非公開、OIDC、対象Resource限定の権限を実現。bootstrap権限の調整には複数回の人間操作を要した |
| CI/CD / State | 19 / 20 | PR plan、Environment apply、S3 native lockfile、State移行を実証。Cleanup後のworkflowは再bootstrapまで実行不能 |
| Monitoring / Reliability | 18 / 20 | 停止、Target異常、CPU、5xxを監視し、ALBログも保存。CPUと5xxの実発報試験、通知経路は未実施 |
| Autonomy / Operations | 18 / 20 | 診断、修正、PR、適用、障害試験、復旧、削除、残存確認を自律実行。権限付与と重要操作の承認は人間が担当 |
| **合計** | **93 / 100** | AWS検証として完了 |

減点は失敗そのものではなく、本番運用へ進む場合に残る改善余地を表す。特に、通知先、予算アラート、IAM権限セットの事前テスト、5xx/CPUの安全な自動試験が次の候補となる。

## 人間介入の集計

単純な了承、再実行依頼、会話メッセージ数ではなく、意味のある操作・判断を1カテゴリとして数えた。合計は **8カテゴリ** である。

1. AWSログインとローカルCredentialの準備
2. GitHub repository名とState Bucket名の決定
3. bootstrap用一時IAM権限の付与・更新
4. Remote State移行用profileと最小S3権限の準備
5. GitHubへのログイン、Variables、Environmentの設定
6. main mergeと本番相当applyの承認
7. サービス影響を伴い得る障害試験の承認
8. 最終destroyとcleanupの承認

このうち、認証、環境所有者による命名、apply、障害試験、destroyは、意図的に人間を残すべき統制点である。一時IAM権限の反復調整は自動化余地がある。

## AIが自律実行した範囲

- Windows上のAWS CLI / Terraform実行環境の確認
- VPC、2 AZ、Public / Private Subnet、ALB、Private EC2、S3 Gateway Endpointの設計と実装
- `fmt`、`init`、`validate`、`plan`、安全性確認、`apply`
- ALB 502のログ調査、原因特定、S3 Prefix List向けHTTPS許可、復旧確認
- bootstrap、OIDC Trust Policy、S3 Remote State、native lockfileの設計と実装
- Local Stateのバックアップ・整合性確認・Remote State移行
- GitHub Actions workflow、Pull Request、OIDC claimの安全な診断、main applyの検証
- CloudWatchアラーム、ALBアクセスログ、保持期間、最小IAM権限の設計と実装
- サービス継続下のTarget異常試験、発報確認、復旧、残存差分確認
- Cost Explorerによる関連サービス費用の概算
- destroy planの確認、Root/State/bootstrapの順序付きcleanup、一時policy削除、残存確認
- 公開文書の匿名化

## 発生した障害と修正

| # | 事象 | 原因 | 修正・判断 |
| ---: | --- | --- | --- |
| 1 | ALBが502を返した | NATなしのPrivate EC2がOSパッケージを取得するS3へのHTTPS egressを許可していなかった | AWS管理S3 Prefix List宛TCP 443を許可し、EC2再作成後にHTTP 200を確認 |
| 2 | bootstrapのplan/applyが複数回AccessDenied | AWS Providerのrefresh APIと作成APIに対する一時権限が不足 | 不足Action、Resource、Terraform resourceを都度特定し、対象限定で追加 |
| 3 | bootstrapの一部リソースが途中作成状態になった | 最小権限の段階追加中にapplyが部分成功 | 実体とStateを調査し、不要な再作成を避けて収束 |
| 4 | IAM policy document生成が失敗 | Statementの`Sid`が重複 | 権限とResourceを変えず`Sid`だけを一意化 |
| 5 | PR workflowが起動しなかった | workflowの`paths`条件がdocs-only変更を除外 | 安全な検証変更とtrigger条件を整合させた |
| 6 | GitHub Actionsの設定不足 | Region等のrepository Variableが未設定 | GitHub Variablesを設定し、秘密情報をSecretsへ保存しない構成を維持 |
| 7 | OIDC AssumeRoleが失敗 | 実tokenの`sub`が想定した標準subjectと異なった | token本体を出さず`sub`と`aud`だけをdecodeし、完全一致のTrust Policyへ修正 |
| 8 | Terraform planがEC2置換を示した | WindowsのCRLFにより`user_data`差分が発生 | `.gitattributes`でTerraform関連ファイルをLFへ統一 |
| 9 | 監視IAM更新がAccessDenied | Role inline policy更新用Actionが不足 | 対象Role限定の必要Actionだけを一時付与 |
| 10 | 監視適用後のlocal planが失敗 | 実行Userに新規ログバケットの読取権限がなく、inline policy文字数上限にも到達 | 既存権限を広げず、同等の読取権限を持つGitHub OIDC workflowで`No changes`を確認 |
| 11 | EC2停止でALB異常アラームが発報しなかった | 停止Targetが`unhealthy`ではなく`unused`として扱われた | EC2ごとの`StatusCheckFailed`アラームを追加 |
| 12 | Cleanup policyを保存できなかった | IAM Userのinline policy合計が2,048文字上限を超えた | 不要になった移行用policyを削除し、cleanup専用にActionを圧縮 |
| 13 | bootstrap destroyがAccessDenied | S3削除系APIのIAM Action対応とRole refresh用Actionが不足 | 公式API仕様に従い、正確な対象Resourceだけへ必要Actionを追加 |
| 14 | Ownership Controls削除が一度失敗 | 更新直後のIAM権限反映に時間差があった | 権限を拡張せず同一APIを再試行し成功 |

## 実コスト確認

Cost Explorerで検証期間を含む当月のUnblended Costを確認した。Project tagによる厳密な配賦ではないため、以下は同期間の関連サービスカテゴリを合算した概算である。

| サービス区分 | 概算額 (USD) |
| --- | ---: |
| EC2 compute | 0.0844 |
| Elastic Load Balancing | 0.1216 |
| EC2 Other | 0.0024 |
| VPC | 0.0435 |
| S3 | 0.0002 |
| **関連サービス合計** | **約0.2521** |

アカウント全体の同期間推定額は税等を含め約0.2821 USDだった。プロジェクト外利用を含む可能性があるため、最終評価では関連サービス合計の **約0.25 USD** を採用した。NAT Gateway、Elastic IP、CloudWatch Logs ingest、外部監視サービスを追加しなかったことが低コスト化に寄与した。

## Cleanup手順と結果

### 1. Root Terraform

1. ALBアクセスログバケットへ`force_destroy = true`を追加した。
2. GitHub OIDC Roleへ、対象ログバケットのversion一覧・object version削除だけを追加した。
3. PRで`fmt`、`init`、`validate`、OIDC認証、planを実行した。差分はcleanup準備のin-place変更だけで置換なしだった。
4. main適用後、手動destroy workflowをplan-onlyで実行した。
5. **0追加、0変更、39削除**、置換なしを確認してからdestroyした。
6. Remote Stateはresource 0件になったことを確認した。

### 2. Remote Stateとbootstrap

1. RootとbootstrapのStateをGit管理外へ一時バックアップし、ハッシュを取得した。
2. Remote State keyとlockfile key以外を拒否するwhitelist確認を行った。
3. Remote State objectの全12 versionを削除し、current object、version、delete markerが空であることを確認した。
4. bootstrap destroyを実行した。途中のAccessDeniedでは権限を拡張せず、正確なActionとResourceだけを追加した。
5. 最後に空のState Bucketを削除し、bootstrap Stateがresource 0件になったことを確認した。
6. GitHub Actions用Role、OIDC Provider、移行用・bootstrap用の一時IAM inline policyを削除した。

Cleanup完了後、Root / bootstrapのState、移行前・削除前の一時バックアップ、実環境用backend設定、実値を含むbootstrap変数ファイル、保存済みplan、Terraform backend cacheをワークスペースから削除した。Stateやplanは機密情報を含む可能性があるため、GitHubへは一度も追加していない。これらのローカルファイルは復元できないが、再検証に必要なTerraformソースとexample設定は保持している。

## 残存確認

Project tagと既知の論理名を用い、次を個別に確認した。

- EC2 instance: 0
- VPC / Subnet / Security Group / Route Table / Internet Gateway / VPC Endpoint: 0
- ALB / Target Group: not found
- CloudWatch Alarm: 0
- ALB access log bucket: not found
- Terraform State bucket: not found
- GitHub Actions IAM Role: not found
- GitHub Actions OIDC Provider: not found
- bootstrap用・State移行用の一時IAM inline policy: 0
- ローカルState / backend cache / 一時Stateバックアップ / 保存済みplan / 実値変数ファイル: 0

確認対象は本プロジェクトが作成したリソースに限定した。他用途のAWSリソースや既存IAM managed policyには変更を加えていない。

## GitHub Actionsの終了状態

Cleanup用workflowはdestroy成功後にリポジトリから削除する。State BucketとOIDC Roleも削除済みであるため、通常のPR plan / main apply workflowを再利用する場合は、先にbootstrapを再作成してGitHub VariablesとEnvironment設定を確認する必要がある。

最終ドキュメントはAWS権限消去後のため、AWSへ接続するCIではなくdocs-only変更として保存する。
