# AIは3クラウドの実装をどこまで担えるか
## AWS / Azure / GCP ライフサイクル横断検証・最終レポート

作成日: 2026-09-08（日本時間）

## 1. 結論

**今回のLevel 2相当の検証では、安全境界・レビュー・承認ポイントを設けることで、設計からTerraform実装、CI/CD、短期認証、Remote State、監視、障害試験、復旧、cleanupまでをAI主体で完了できた。**

価値があったのは、最初のコード生成だけではない。APIやProviderの制約、認証claimの不一致、部分apply、入力差、削除の伝播遅延に対し、AIが原因を調べ、差分を限定して修正し、状態の収束まで確認したことである。3環境とも、実行記録上は管理対象リソースの削除・残存確認まで完了している。[A1](https://github.com/moruku36/aws-ai-terraform-validation/blob/c5e5ab86aa701034347971ed52d6876bcee3594d/docs/09-final-results-and-cleanup.md)[Z1](https://github.com/moruku36/azure-ai-terraform-validation/blob/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/docs/05-results.md)[G1](https://github.com/moruku36/gcp-ai-terraform-validation/blob/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/docs/05-results.md)

この結果は、クラウド固有のAPIやTerraform記法の差をAIが相当程度吸収できることを示す。一方、要件、対象範囲、IAMの許容範囲、公開・課金の受容、本人確認、破壊的操作の承認は人間側に残った。人間の専門性は、AIの出力を評価し、実行してよい境界を決めるために必要だった。

ただし、**実験の完了と、現在のコードをそのまま再実行できることは別の評価**である。本レポートのコードレビューでは、AWSのTerraformバージョンとS3 lockingの不整合など、再現時に解消すべき点も見つかった。実施記録を否定する材料にはしないが、無条件に再現性を保証することもできない（第8節）。

## 2. 実験範囲と評価方法

本レポートの「Level 2」は、この検証で扱った標準的なWeb基盤と運用ライフサイクルを指す便宜的な呼称であり、業界共通の資格・成熟度基準ではない。

共通要件は、L7ロードバランサーからPrivate VM 2台へHTTPを配信し、VMのPublic IP・Internet向けSSHを設けず、Terraform、GitHub Actions、長期鍵を置かないFederation、Remote State、最低限の監視、安全な障害試験、削除まで確認することだった。AWS、Azure、GCPの順に実施し、前段の学びを後段へ持ち込んだ。[A1](https://github.com/moruku36/aws-ai-terraform-validation/blob/c5e5ab86aa701034347971ed52d6876bcee3594d/docs/09-final-results-and-cleanup.md)[Z1](https://github.com/moruku36/azure-ai-terraform-validation/blob/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/docs/05-results.md)[G1](https://github.com/moruku36/gcp-ai-terraform-validation/blob/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/docs/05-results.md)

本レポートは各リポジトリの実装と公開済み実行記録を照合した事後分析である。クラウドへの再接続、apply、障害注入、destroyは実行していない。原本のStateや全コマンドログは公開されていないため、記録された成功は「実行記録による確認」、コードから分かる状態は「静的レビュー」、そこからの解釈は「考察」として扱う。

| 評価観点 | 完了を判断する証拠 |
|---|---|
| 構築 | apply完了に加え、LB経由HTTP 200・Backend正常 |
| 認証・CI/CD | GitHubから短期認証、Remote State初期化、plan/apply |
| 状態整合性 | 移行後・修正後・障害復旧後のNo changes |
| 監視 | 定義の作成と、選定した障害に対する発報・解消 |
| Cleanup | delete-only plan、State 0、API等による対象残存確認 |
| 安全境界 | 既存環境の保持、権限不足時の停止、必要な承認 |

## 3. アーキテクチャ・実装比較

| 項目 | AWS | Azure | GCP |
|---|---|---|---|
| リージョン | 東京 | Japan East | 東京 |
| L7公開 | Regional ALB | Application Gateway Standard_v2 | Global External Application Load Balancer |
| Backend | 個別EC2 2台 | Zone指定Linux VM 2台 | Instance Template + Regional MIG 2台 |
| Zone設計 | AZごとにSubnet | Regional Subnet内でVMのZoneを指定 | Regional Subnet内でMIGを2 Zoneへ分散 |
| Private outbound | S3 Gateway Endpointによるパッケージ取得 | NAT Gateway | Cloud Router + Cloud NAT |
| Backend受信制限 | ALBのSGからHTTP | App Gateway SubnetからHTTP | GFE / Health Check範囲からHTTP |
| Federation | IAM OIDC Provider + STS Role | Entra Federated Credential + Managed Identity | WIF Pool/Provider + SA impersonation |
| PR / apply Identity | 同じIAM Roleを使用 | Managed Identityを分離 | Service Accountを分離 |
| Remote State | S3 | Azure Blob | GCS |
| Locking | S3 native lockfileの設計・記録。版不整合あり | Blob lease。競合拒否・解放後復旧を実証 | GCS backend標準locking |
| PR時のlocking | lockを無効化していない | `-lock=false` | `-lock=false` |
| Monitoring | CloudWatch Alarm 7件 | Metric Alert 7件、Activity Log Alert 1件、Action Group | Uptime Check 1件、Alert Policy 5件、log-based metric 1件 |
| ログ | 専用S3、14日保持の設計 | 専用Storage、30日保持の設計 | Project標準Cloud Logging |
| Cleanup境界 | State + tag + 既知名 | State + Resource Group | State + label + 既知名。Project保持 |

根拠: 各クラウドの構成・監視・bootstrap・workflow。[A2](https://github.com/moruku36/aws-ai-terraform-validation/blob/c5e5ab86aa701034347971ed52d6876bcee3594d/docs/08-monitoring.md)[A3](https://github.com/moruku36/aws-ai-terraform-validation/blob/c5e5ab86aa701034347971ed52d6876bcee3594d/bootstrap/main.tf)[A4](https://github.com/moruku36/aws-ai-terraform-validation/tree/c5e5ab86aa701034347971ed52d6876bcee3594d/.github/workflows)[Z2](https://github.com/moruku36/azure-ai-terraform-validation/blob/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/docs/08-monitoring.md)[Z3](https://github.com/moruku36/azure-ai-terraform-validation/blob/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/bootstrap/main.tf)[Z4](https://github.com/moruku36/azure-ai-terraform-validation/tree/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/.github/workflows)[G2](https://github.com/moruku36/gcp-ai-terraform-validation/blob/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/docs/08-monitoring.md)[G3](https://github.com/moruku36/gcp-ai-terraform-validation/tree/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/bootstrap)[G4](https://github.com/moruku36/gcp-ai-terraform-validation/tree/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/.github/workflows)

同一要件への実装であっても、同一構成ではない。GCPはMIGによる自己修復を含み、AWS/Azureは個別VM管理である。GCPのGlobal LBも、バックエンドを複数リージョン化したことを意味しない。AWSのNATなし構成は採用OSの取得経路に依存し、一般の外部リポジトリへアクセスできる設計とは異なる。

### 今回観測した難所

以下は本実験での定性的評価であり、サービス全体の難易度ランキングではない。

| 項目 | AWS | Azure | GCP |
|---|---|---|---|
| Terraform実装 | egressと起動処理の依存、改行による置換差分 | Provider属性、Probe Host、Service Tag制約 | root構築は初回成功。bootstrap型変換とMonitoring APIで修正 |
| Identity | refresh/create/deleteに必要なIAM Actionの反復調整 | Identity・Federated Credential・RBAC scope・backend認証方式の切り分け | mapping・condition・exact subject・SA IAMの多段切り分け |
| Remote State | object/version/lockfile権限と移行・削除順序 | CLI UserとCI OIDC認証の分離 | CIにbackend宣言がなく、既存環境を18 addと表示 |
| Cleanup | version全削除、IAM上限、削除API権限、反映待ち | RG境界は明瞭。App Gateway削除の伝播遅延 | root→bootstrapの順序で各1回。既存資源とsoft-deleteを区別 |

## 4. 定量結果と集計上の注意

| 指標 | AWS | Azure | GCP |
|---|---:|---:|---:|
| 初回root safe planまで | 同一定義の集計なし | 2回 | 1回 |
| 初回bootstrap safe planまで | 同一定義の集計なし | 集計なし | 4回 |
| 初回root apply完了まで | 同一定義の集計なし | 2回 | 1回 |
| No changes確認 | 複数回。総数未集計 | 少なくとも11回 | 13件 |
| 意図しない実環境差分 | 総数未集計 | 1回、12資源の追加タグ削除 | drift 0件 |
| 危険なplanの例 | CRLFによるEC2置換差分 | 入力差によるタグ更新 | backend欠落による18 add |
| 想定外destroy / replace | 統一定義の総数なし | 構築・修正集計で実行0回 | 0件 |
| 人間介入（原記録の集計） | 8カテゴリ | 5カテゴリ | 4件 |
| Cleanup root | 39件 | 41件 | 25件 |
| Cleanup bootstrap | 9件 | 12件 | 13件 |
| 削除後 | 管理対象残存なし | 管理対象残存0 | 管理対象active 0 |

数値は[A1](https://github.com/moruku36/aws-ai-terraform-validation/blob/c5e5ab86aa701034347971ed52d6876bcee3594d/docs/09-final-results-and-cleanup.md)[Z1](https://github.com/moruku36/azure-ai-terraform-validation/blob/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/docs/05-results.md)[G1](https://github.com/moruku36/gcp-ai-terraform-validation/blob/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/docs/05-results.md)を転記した。合計139件はTerraform管理項目の削除数（48 + 53 + 38）であり、VM台数や独立した課金リソース数ではない。GCPのVMはMIGが管理するため、Terraform項目数だけで構成規模を比較できない。

- **safe plan 1回はGCPの初回rootに限る。** bootstrapはCLI解析失敗2回、型エラー1回を含め4回。監視でも部分applyと修正があった。
- **drift 0は、誤ったplanがなかったという意味ではない。** GCPは18 addの不整合をapply前に止めた。MIG縮小による意図的な一時差分は、意図しないdriftの集計には含まれない。
- **想定外replace 0は、置換自体が0という意味ではない。** GCPのPR/Apply WIF bindingは各1件、承認した置換を実施している。
- **8→5→4を介入回数の削減率として計算できない。** AWS/Azureはカテゴリ、GCPは記録された承認・本人確認4件。GCP監視文書には別途実行承認も記載されており、ライフサイクル全体の承認が4回だけだったとは断定しない。
- GCPのMonitoringは結果集計に「4 attempt」、監視詳細に「3回目のmain apply」とある。runとattempt等の対応が明示されていないため、統一した成功率・試行回数を新たに算出しない。
- Azureの「実行されたdestroy / replace 0」は意図したcleanupを含む全期間の削除0ではない。AWSでは初期不具合修正にEC2再作成が記録されている。
- No changesの回数は確認機会の数に左右される。13回をそのまま品質スコアや成功率へ変換しない。

## 5. AIの失敗と復旧から分かったこと

| 事象 | 実環境への影響・検出段階 | AIの対応と残った教訓 |
|---|---|---|
| AWS: パッケージ取得用egress不足 | Nginx導入失敗、ALB 502 | S3 Prefix List宛443を許可して復旧。Private配置と起動時依存を一体で設計する |
| AWS: bootstrap権限不足 | AccessDenied、部分作成 | 不足Action/ResourceとStateを照合。権限追加は人間承認下で限定 |
| AWS: CRLFによるuser_data差分 | EC2置換plan | LF統一。ローカル/CIのファイル正規化もIaCの再現性に含む |
| Azure: 古い属性・Probe・DNS規則 | validate/plan失敗、29資源作成後の部分apply | Provider schema/APIを確認して不正設定を修正。生成コードのもっともらしさは十分な根拠にならない |
| Azure: CLI警告がGitHub Variableへ混入 | CI実行前に検出 | 出力を検証して単一値として入力。stdout/stderrと機械入力の境界が重要 |
| Azure: ローカルとCIのtags入力差 | 12資源の追加タグを実際に削除 | 入力を共通化し、承認後にタグだけ修復。正常終了したapplyも意図に反する場合がある |
| GCP: backend宣言のGit追跡漏れ | PRで既存18資源を新規作成扱い | 空のGCS backend宣言を追跡。applyせず修復 |
| 3クラウド: OIDC subjectの想定違い | 認証失敗 | 実claimと信頼条件を照合。GCPでは承認済みbinding置換。長期鍵や広い信頼条件への逃避は不要だった |
| GCP: Monitoring API制約 | 部分作成後に400 | duration/comparison/resource mappingを修正。未作成資源だけを再plan |
| Azure: cleanup伝播遅延 | NSG Rule削除の一時拒否 | 残存3件を確認しdelete-only planを再生成。Stateを強制操作せず収束 |

根拠: [A1](https://github.com/moruku36/aws-ai-terraform-validation/blob/c5e5ab86aa701034347971ed52d6876bcee3594d/docs/09-final-results-and-cleanup.md)[Z5](https://github.com/moruku36/azure-ai-terraform-validation/blob/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/docs/04-troubleshooting.md)[G5](https://github.com/moruku36/gcp-ai-terraform-validation/blob/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/docs/04-troubleshooting.md)。

これらはすべてAI能力の不足だけに帰せる事象ではない。生成コードの誤り、ローカル環境、認証設定、クラウドの非同期性が混在している。評価すべきは、問題の発生数に加え、影響範囲を限定し、承認境界を守り、状態を収束させたかどうかである。

「権限を自動拡張しない」は「検証期間中に権限変更が一切ない」という意味でもない。AWSは承認下でActionを追加し、GCPは初期bootstrapやVM実行Identityへのbinding追加を記録している。認証条件の修正と権限拡大も区別する必要がある。

## 6. 監視・障害試験の到達点

| クラウド | 実施した障害 | 観測できたこと | 未確認・範囲外 |
|---|---|---|---|
| AWS | EC2停止後、未使用port 81のTargetを一時登録 | 停止Targetがunusedとなる検知ギャップを発見。port 81でALARM→OK、HTTP 200維持 | 追加StatusCheckアラームの再停止発報は記録上未確認。CPU/5xx実発報、外部通知は未試験 |
| Azure | VM 1台をdeallocate | Backend異常、Fired相当→Resolved相当、HTTP 200維持 | 全監視ルール個別の発報、通知Receiver経由の到達は未確認 |
| GCP | MIG target sizeを2→1→2 | 容量低下、Incident Open→Closed、2台Healthy復旧、HTTP 200維持 | Health Check AlertのFiredは未確認。全ルール・外部通知の試験ではない |

根拠: [A2](https://github.com/moruku36/aws-ai-terraform-validation/blob/c5e5ab86aa701034347971ed52d6876bcee3594d/docs/08-monitoring.md)[Z2](https://github.com/moruku36/azure-ai-terraform-validation/blob/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/docs/08-monitoring.md)[G2](https://github.com/moruku36/gcp-ai-terraform-validation/blob/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/docs/08-monitoring.md)。

「監視が作れた」から一歩進み、実際の信号、アラート状態、サービス継続、復旧後の整合性まで確認できた。ただし、異なる障害を使っているため、検知速度や可用性をクラウド間で順位付けする実験ではない。通知先はいずれも未構成で、担当者への通知到達までを含む本番運用検証ではない。

## 7. Cleanupと「残存0」の意味

削除は、作成と同じく設計・承認・検証を要する工程だった。

| 項目 | AWS | Azure | GCP |
|---|---|---|---|
| 手順 | root→State全version→bootstrap・一時IAM | root→空State確認→bootstrap | root→空State確認→bootstrap |
| 特記事項 | State全12 version削除、IAM文字数上限・削除権限調整 | App Gateway伝播遅延後、残存3件のみ再実行 | root 25・bootstrap 13を各1回で削除 |
| 境界の保護 | 他用途の資源・既存managed policyを保持 | 検証外Resource Groupを保持 | Project、既存default network、既存SA 2件を保持 |
| Cleanup後CI | State/OIDC削除済み。明示的ACTIVE gateなし | ACTIVE gateあり | ACTIVE=false、cloud jobのSkippedを記録 |

根拠: [A1](https://github.com/moruku36/aws-ai-terraform-validation/blob/c5e5ab86aa701034347971ed52d6876bcee3594d/docs/09-final-results-and-cleanup.md)[Z1](https://github.com/moruku36/azure-ai-terraform-validation/blob/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/docs/05-results.md)[G1](https://github.com/moruku36/gcp-ai-terraform-validation/blob/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/docs/05-results.md)とworkflow静的確認。[A4](https://github.com/moruku36/aws-ai-terraform-validation/tree/c5e5ab86aa701034347971ed52d6876bcee3594d/.github/workflows)[Z4](https://github.com/moruku36/azure-ai-terraform-validation/tree/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/.github/workflows)[G4](https://github.com/moruku36/gcp-ai-terraform-validation/tree/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/.github/workflows)

残存0は、**検証で管理した対象のactiveリソースが残っていない**という意味である。アカウント全体が空、soft-delete資源が物理消去済み、保持ログが全消去済み、後日請求が一切ない、という保証ではない。GCPのProject標準Logging bucketも削除対象外だった。本レポートは公開記録を確認したもので、現在のクラウド残存を再照会したものではない。

費用についてはAWSのみ関連サービス概算約0.25 USDが記録されているが、厳密なタグ配賦ではない。Azure/GCPの同条件実測がないため、費用順位や費用削減率は算出しない。[A1](https://github.com/moruku36/aws-ai-terraform-validation/blob/c5e5ab86aa701034347971ed52d6876bcee3594d/docs/09-final-results-and-cleanup.md)

## 8. 最終コードレビューで判明した再現性・統制の課題

### 8.1 AWSのS3 lockingとTerraformバージョン

AWSの`backend.tf.example`は`use_lockfile = true`だが、両workflowはTerraform 1.9.8を指定し、rootの`required_version`も1.8以降を許容している。[A3](https://github.com/moruku36/aws-ai-terraform-validation/blob/c5e5ab86aa701034347971ed52d6876bcee3594d/bootstrap/main.tf)[A4](https://github.com/moruku36/aws-ai-terraform-validation/tree/c5e5ab86aa701034347971ed52d6876bcee3594d/.github/workflows)

S3 native lockingはTerraform 1.10.0で導入された機能である。[H1](https://github.com/hashicorp/terraform/blob/v1.10.0/CHANGELOG.md) したがって、現在の版指定とbackend設定は整合しない。過去の成功記録を現行checkoutの再現成功として扱うことはできず、再検証前に対応版へ揃え、実行版とログを記録する必要がある。このレポート作成では実装を変更していない。

### 8.2 AWSのPRは権限上read-onlyではない

AWSのPRとapplyは同じrepository VariableのRoleを使用し、bootstrapも両subjectを同じRoleで信頼している。[A3](https://github.com/moruku36/aws-ai-terraform-validation/blob/c5e5ab86aa701034347971ed52d6876bcee3594d/bootstrap/main.tf)[A4](https://github.com/moruku36/aws-ai-terraform-validation/tree/c5e5ab86aa701034347971ed52d6876bcee3594d/.github/workflows) PRで実行するコマンドがplanだけでも、Identityの権限がread-onlyであることとは異なる。Azure/GCPではPRとapplyのIdentityおよび権限を分離している。

### 8.3 承認とsaved planの関係

3クラウドともmain jobの中でplanを生成してapplyする。Environment指定は確認できるが、YAMLだけではrequired reviewer等の実設定を確認できない。また、PRで見たplanそのものをmainへ引き継いで承認している構成ではない。[A4](https://github.com/moruku36/aws-ai-terraform-validation/tree/c5e5ab86aa701034347971ed52d6876bcee3594d/.github/workflows)[Z4](https://github.com/moruku36/azure-ai-terraform-validation/tree/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/.github/workflows)[G4](https://github.com/moruku36/gcp-ai-terraform-validation/tree/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/.github/workflows)

したがって「人間が生成後の当該saved planを必ずレビューした」という仕組みまでは証明できない。再利用時には、承認対象と実際に適用するplanをどう一致させるかを明確にする必要がある。

### 8.4 Locking、CI停止、検証順序

Azure/GCPはPRのState読取権限を限定するため`-lock=false`を使い、apply側ではlockingを無効化していない。標準lockingを採用していても、全planがロックを取るわけではない。[Z4](https://github.com/moruku36/azure-ai-terraform-validation/tree/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/.github/workflows)[G4](https://github.com/moruku36/gcp-ai-terraform-validation/tree/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/.github/workflows)

AWSにはAzure/GCP相当の環境有効化gateがなく、削除済みの認証・Stateへ依存して停止する構成である。GCPのcloud-plan jobにはstatic-checksへの`needs`がなく、静的検証完了を待つ構造ではない。これらは今回の完了記録とは別に、次回利用前の統制改善点として残る。

## 9. GCPの安定化をどう解釈するか

GCPはroot safe plan初回成功、意図しないdrift 0、No changes 13回、cleanup各1回という成果を得た。Azureの振り返りには、入力値の統一、OIDC claim事前確認、cleanup依存順序、環境有効化フラグ、監視の評価窓を次段で改善する方針が記されている。[Z6](https://github.com/moruku36/azure-ai-terraform-validation/blob/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/docs/06-lessons-learned.md)[G1](https://github.com/moruku36/gcp-ai-terraform-validation/blob/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/docs/05-results.md)

このうち、入力差の抑制、cleanup順序、環境有効化gateはGCPの実装・結果にも現れている。一方、OIDC subject不一致はGCPでも発生しており、反省を持ち込めばすべての失敗を防げたわけではない。

**本実験から支持できるのは、前段の失敗を設計・確認手順へ反映する進め方が有効だったという実務的示唆である。** 単一の実施者・逐次実験であり、要件や構成、AIへの指示も完全に固定されていないため、改善をGCP自体の容易さやAIモデルの能力向上へ単独で帰属させることはできない。[G6](https://github.com/moruku36/gcp-ai-terraform-validation/blob/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/docs/06-lessons-learned.md)

## 10. AI時代のクラウドエンジニアに何が残るのか

| 責任・作業 | 今回AIへ委任できた範囲 | 人間に残る判断 |
|---|---|---|
| 要件・設計 | 要件の構造化、サービス選定案、Terraformへの具体化 | 可用性、予算、公開範囲、対象外を決める |
| Identity | Policy/binding案、claim照合、原因分析 | IAM/RBAC/WIFの権限と信頼境界を受容する |
| 実装・変更 | コード、CI、State移行、差分分析、限定修正 | 適用・破壊・サービス影響を承認する |
| 障害対応 | メトリクス・ログ調査、復旧案、実行・確認 | 許容停止時間と業務影響を判断する |
| Cleanup | 依存順序、delete-only plan、残存照合 | 消してよい資源と保持すべきものを確定する |
| 品質保証 | Provider/API調査、試験、文書化 | deprecated仕様、設計妥当性、証拠の不足をレビューする |

クラウド固有知識が不要になるという結論ではない。今回も、SG/NSG/Firewall、TrustとPermission、Control PlaneとData Plane、Stateと実体、発報と通知の違いを理解していなければ、AIの提案が要件を満たすか判断できない。

今回の結果が示す価値の移動は、APIやコマンドを記憶して一つずつ操作する作業から、**要件と制約を定義し、AIが提示する設計・差分・証拠をレビューし、結果に責任を持つ仕事へ比重が移ること**である。AIが実装を広く担うほど、何を成功とみなすか、何を禁止するか、いつ停止するかを定義する能力が重要になる。

## 11. 結論の適用範囲

今回確認できたのは、経験のあるクラウドエンジニアが安全境界を定めた、短期間・小規模・破棄可能な3環境での成功である。

以下は未検証のため、今回の成功から推定しない。

- 人間のみの実装に対する時間・費用・品質の優位性。統一した時間、token、操作工数の測定はない。
- 初心者でも同じ結果に到達できるか。所有者には設計・レビュー経験がある。
- 複数回の独立再実験での成功率、モデル間比較。モデル版・全プロンプト・全ログの統一記録はない。
- 本番のTLS、WAF、通知到達、SLO、長期運用、DB/データ移行、復旧訓練、複数リージョンDR、大規模ガバナンス。
- 現行コードの無修正再現。第8節の不整合を解消した後の再実行は未実施。

**最終評価は「定義したLevel 2検証は3クラウドとも完了。AI主体の実装・運用ライフサイクルは実証されたが、本番適合性と現行コードの再現性には別途確認が必要」である。**

## 12. 根拠・参照コミット

このレポート追加前のmainを固定して参照する。リンク先は更新されるmainではなく、確認時点のcommitである。実行結果の数値は各結果文書から採用し、未記録の数値は補完していない。

| クラウド | 確認コミット |
|---|---|
| AWS | `c5e5ab86aa701034347971ed52d6876bcee3594d` |
| Azure | `b5344c6c6ca9b2220c132137ed5bc26dd08b6753` |
| GCP | `8fbc809bd787d46801d7ff8e030eb40c0db4b35d` |

- A1: [AWS 最終結果・介入集計・Cleanup](https://github.com/moruku36/aws-ai-terraform-validation/blob/c5e5ab86aa701034347971ed52d6876bcee3594d/docs/09-final-results-and-cleanup.md)
- A2: [AWS 監視・障害試験](https://github.com/moruku36/aws-ai-terraform-validation/blob/c5e5ab86aa701034347971ed52d6876bcee3594d/docs/08-monitoring.md)
- A3: [AWS bootstrap / IAM](https://github.com/moruku36/aws-ai-terraform-validation/blob/c5e5ab86aa701034347971ed52d6876bcee3594d/bootstrap/main.tf)
- A4: [AWS workflows](https://github.com/moruku36/aws-ai-terraform-validation/tree/c5e5ab86aa701034347971ed52d6876bcee3594d/.github/workflows)
- Z1: [Azure 実行結果・集計・Cleanup](https://github.com/moruku36/azure-ai-terraform-validation/blob/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/docs/05-results.md)
- Z2: [Azure 監視・障害試験](https://github.com/moruku36/azure-ai-terraform-validation/blob/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/docs/08-monitoring.md)
- Z3: [Azure bootstrap / RBAC](https://github.com/moruku36/azure-ai-terraform-validation/blob/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/bootstrap/main.tf)
- Z4: [Azure workflows](https://github.com/moruku36/azure-ai-terraform-validation/tree/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/.github/workflows)
- Z5: [Azure 障害記録](https://github.com/moruku36/azure-ai-terraform-validation/blob/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/docs/04-troubleshooting.md)
- Z6: [Azure 学び・GCPへの改善点](https://github.com/moruku36/azure-ai-terraform-validation/blob/b5344c6c6ca9b2220c132137ed5bc26dd08b6753/docs/06-lessons-learned.md)
- G1: [GCP 実行結果・集計・Cleanup](https://github.com/moruku36/gcp-ai-terraform-validation/blob/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/docs/05-results.md)
- G2: [GCP 監視・障害試験](https://github.com/moruku36/gcp-ai-terraform-validation/blob/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/docs/08-monitoring.md)
- G3: [GCP bootstrap / WIF / IAM](https://github.com/moruku36/gcp-ai-terraform-validation/tree/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/bootstrap)
- G4: [GCP workflows](https://github.com/moruku36/gcp-ai-terraform-validation/tree/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/.github/workflows)
- G5: [GCP 障害記録](https://github.com/moruku36/gcp-ai-terraform-validation/blob/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/docs/04-troubleshooting.md)
- G6: [GCP 学び・最終評価](https://github.com/moruku36/gcp-ai-terraform-validation/blob/8fbc809bd787d46801d7ff8e030eb40c0db4b35d/docs/06-lessons-learned.md)
- H1: [HashiCorp Terraform 1.10.0 CHANGELOG（S3 native state locking導入）](https://github.com/hashicorp/terraform/blob/v1.10.0/CHANGELOG.md)

- [AWS 構成コード](https://github.com/moruku36/aws-ai-terraform-validation/tree/c5e5ab86aa701034347971ed52d6876bcee3594d)

- [AZURE 構成コード](https://github.com/moruku36/azure-ai-terraform-validation/tree/b5344c6c6ca9b2220c132137ed5bc26dd08b6753)

- [GCP 構成コード](https://github.com/moruku36/gcp-ai-terraform-validation/tree/8fbc809bd787d46801d7ff8e030eb40c0db4b35d)

