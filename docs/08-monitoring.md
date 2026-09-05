# 最低限の監視設計

## 目的

既存のALB、Private EC2、Nginxで構成するWebシステムに対し、障害検知と初動調査に必要な最低限の監視をTerraformで追加する。高額な常時収集基盤や通知先未確定のサービスは追加しない。

## 採用設計

### 使用するAWSサービス

- **Amazon CloudWatch**: ALBとEC2が標準で発行するメトリクスに対するアラーム。
- **Amazon S3**: ALBアクセスログの保存先。Public Access Block、SSE-S3、TLS強制、14日ライフサイクルを設定する。
- **Application Load Balancer access logs**: リクエスト、応答、接続先を障害調査用にS3へ配信する。

CloudWatch Agent、CloudWatch Logs、NAT Gateway、EC2への追加IAM Role、SNSは採用しない。Private EC2で追加エージェントを動かしたり、通知先未指定のまま外部通知を送信したりせず、標準メトリクスとALBログで必要最小限の可観測性を確保する。

## 監視項目とアラーム条件

| 目的 | CloudWatch metric | 条件 | 判定理由 |
| --- | --- | --- | --- |
| Webサービス停止 | `HealthyHostCount` | 1未満、1分×2回 | 全Targetが利用不能となり、ALB経由のWeb提供ができない状態を検知する。 |
| バックエンド異常 | `UnHealthyHostCount` | 1以上、1分×2回 | 片系障害を含むTargetの健全性低下を早期検知する。 |
| HTTP 5xx増加 | `HTTPCode_Target_5XX_Count` + `HTTPCode_ELB_5XX_Count` | 合計5件以上/5分 | Target起因とALB起因の5xxを1つのアラームで検知する。 |
| EC2 CPU異常 | `CPUUtilization` | 平均80%以上、5分×3回、各EC2 | 瞬間的なスパイクを避けつつ、継続的なCPU逼迫を個別に検知する。 |

`HealthyHostCount`、`UnHealthyHostCount`、Target/ALBのHTTP 5xxは`AWS/ApplicationELB`の標準メトリクスである。`HTTPCode_Target_5XX_Count`はTargetが返した5xx、`HTTPCode_ELB_5XX_Count`はALBが発生させた5xxを対象とする。[AWS公式メトリクス仕様](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html)

アラームアクションは設定しない。通知先が未指定の検証段階では、CloudWatch ConsoleのAlarm stateとS3アクセスログで確認する。通知先が決まった時点で、SNSまたは既存の運用通知基盤を別変更として追加する。

## ログ・メトリクス取得方法

ALBアクセスログを専用S3バケットの限定prefixへ配信する。バケットは同一リージョンに作成し、ELBログ配信Service Principalへ対象アカウントのprefixだけに`PutObject`を許可する。S3 Public Access Block、Bucket Owner Enforced、SSE-S3、TLS強制を設定し、14日後に自動削除する。ALBのアクセスログ属性とS3配信要件は[AWS公式ガイド](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html)に従う。

メトリクスはCloudWatch Consoleで、ALB/Target Group/EC2の各dimensionを指定して確認する。追加のcustom metricやLogs Insights課金を避けるため、初期構成では標準メトリクスだけを使う。

## 想定コスト

- CloudWatch: 論理アラーム5件。標準解像度アラームは1 alarm-metricあたり月額0.10 USDが料金例として示されている。5xxのmetric mathは2つの基礎メトリクスを参照するため、無料枠を除き概算で月額0.50〜0.60 USD程度を見込む。実際の請求はリージョン、無料枠、メトリクス課金単位で確認する。[CloudWatch料金](https://aws.amazon.com/cloudwatch/pricing/)
- S3: 保存量、PUT request、取得量に応じた従量課金。14日で削除するため、低トラフィックの検証環境では小額を想定する。S3には最低料金はなく、使用量に応じて課金される。[S3料金](https://aws.amazon.com/jp/s3/pricing/)
- 追加しないもの: NAT Gateway、CloudWatch Agent、CloudWatch Logs ingest、custom metric、SNS、外部監視サービス。

## Terraform変更内容

- `monitoring.tf`: S3ログバケット、アクセスログ用Bucket Policy、CloudWatch metric alarm 5件。
- `variables.tf`: しきい値、評価期間、ログ保持日数、prefixを変数化。
- `main.tf`: ALBのaccess logsを有効化。既存の通信設定・Target Group・EC2設定には変更しない。
- `bootstrap/`: GitHub Actions Terraform Roleに、監視アラームとログバケットだけを作成・読取・削除する最小権限を追加。

Rootのlocal plan結果は **11追加、1変更、0削除** だった。追加はアラーム5件とログバケット関連6件、既存リソースの変更はALBのアクセスログ有効化だけである。既存リソースのdestroy/recreateは含まれない。

## GitHub Actions・適用状況

GitHub Actions Roleの監視権限を反映するbootstrap applyは完了した。適用内容は既存Role inline policyのin-place更新1件のみで、0追加、1変更、0削除だった。適用後のbootstrap planは`No changes`となった。PR workflow、main merge、Root apply、障害試験は後続工程として実施する。

## 発生したエラーと修正方針

### bootstrap IAM更新のAccessDenied

bootstrap planは、既存GitHub Actions Terraform Roleのinline policyをin-place更新する1件だけを示した。applyでは次の権限が不足して停止した。

- 不足Action: `iam:PutRolePolicy`
- 対象Resource: GitHub Actions Terraform Role（実ARNは記載しない）
- 対象Terraform resource: `aws_iam_role_policy.github_actions_terraform`

人間の明示承認後、AWS Consoleからbootstrap専用の一時inline policyへ、対象Roleに限定した`iam:PutRolePolicy`だけを追加した。`iam:PassRole`、AdministratorAccess、ワイルドカードResourceは追加していない。再実行したbootstrap planはRole inline policy更新だけを示し、apply後のplanは`No changes`となった。

### ローカルCredential CSVの不在

過去に利用したローカルCredential CSVは見つからなかった。既存のローカルAWS認証設定で読み取りplanは成功したため、Credentialの表示・保存・再作成はしていない。

## 障害試験方針

監視リソースのapply後にのみ、次の低リスクな試験を検討する。

1. Target Groupから一方のEC2を一時的にderegisterし、`UnHealthyHostCount`またはTarget健全性アラームを確認後、直ちに再登録する。
2. 5xx試験はNginx設定変更がEC2再作成を伴う可能性があるため、事前に明確な手順と復旧planを作成して人間の承認を得る。
3. CPU試験は負荷生成がコスト・可用性へ影響するため、初期検証では実施しない。必要時は短時間・上限付きの負荷試験を別途承認する。

ALB/EC2の停止、Security Group変更、SSH公開、Public IP付与は本試験では行わない。

## 人間とAIの担当

- **人間が介入した箇所**: AWS Console上の一時権限更新に対する明示承認。今後はPR merge、Root apply、障害試験の最終承認、通知先の決定が該当する。
- **AIが自律的に実施済み**: 監視設計、コスト比較、Terraform実装、format/validate、Root plan、bootstrap plan、既存リソース置換の有無確認、権限不足の特定、AWS Consoleでの対象限定権限設定、bootstrap apply、適用後の`No changes`確認、匿名化した記録。
