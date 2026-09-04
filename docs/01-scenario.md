# 検証シナリオ

## 背景

TerraformによるAWSインフラ実装を、AI/Codexがどこまで自律的に実施・検証・修正できるかを確認する。

## 今回のスコープ

- AWS東京リージョンに新規VPCを作成する。
- 2つのAvailability ZoneにPublic SubnetとPrivate Subnetをそれぞれ作成する。
- Application Load Balancer（ALB）をPublic Subnetへ配置する。
- Amazon Linux 2023のEC2をPrivate Subnetへ2台配置し、起動時にNginxを導入する。
- ALBからEC2へHTTPで到達し、ブラウザからALB経由でWebページを取得できることを確認する。

## 受け入れ条件

| 観点 | 条件 |
| --- | --- |
| 到達性 | インターネットからALBのHTTPへ到達できる |
| Web | ALB経由でNginxのHTTP 200を返す |
| EC2公開 | EC2にPublic IPを割り当てない |
| SSH | TCP 22をインターネットへ公開しない |
| 通信制御 | ALBからEC2へのTCP 80だけを許可する |
| パッケージ取得 | EC2からAmazon Linuxリポジトリ向けS3へのTCP 443だけを許可する |
| 運用性 | `terraform destroy` でTerraform管理リソースを削除できる |

## 非スコープ

- NAT Gateway、Elastic IP、踏み台ホスト
- HTTPS終端、独自ドメイン、WAF
- 自動スケーリング、データベース、永続データ
- CI/CD、OIDC、監視の実装（次段階で扱う）
