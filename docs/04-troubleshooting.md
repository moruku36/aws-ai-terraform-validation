# トラブルシューティング

## ALBが502 Bad Gatewayを返す

### 症状

ALBのHTTP URLへアクセスできたが、レスポンスが`502 Bad Gateway`となった。

### 原因

EC2をPrivate Subnetに配置し、NAT Gatewayを使わない構成では、Nginx導入用のパッケージ取得経路を明示する必要がある。S3 Gateway Endpointは作成済みだったが、EC2 Security Groupの外向き通信を全て閉じていたため、Amazon LinuxリポジトリへHTTPS接続できなかった。

このためNginxの導入が完了せず、ALB Target Groupに正常なHTTPレスポンスを返せなかった。

### 対応

1. AWS管理S3 Prefix Listをデータソースで取得した。
2. EC2 Security Groupに、そのPrefix List宛てTCP 443の外向きルールを追加した。
3. `user_data`が再実行されるようEC2を置換した。
4. ALB URLへ再アクセスし、HTTP 200を確認した。

### 再発防止

Private Subnetで起動時にパッケージを導入する設計では、パッケージ取得先までの経路とSecurity Groupの外向き通信をセットで設計・検証する。NATを使わない場合は、必要なAWSサービスへのVPC Endpointと最小限のルールを明示する。
