---
title: マネージド ID を利用して Azure AD サインイン アクティビティ レポートを CSV ファイルで取得する PowerShell スクリプト
date: 2019-12-16
tags:
  - Azure AD
  - graph api
  - signin log
  - PowerShell
  - Managed ID
---

# マネージド ID を利用して Azure AD サインイン アクティビティ レポートを CSV ファイルで取得する PowerShell スクリプト

こんにちは、 Azure & Identity サポート チームの平形です。
以前紹介した Azure AD のサインイン アクティビティ レポートと監査アクティビティ レポートを Azure AD Graph API を経由して取得するスクリプトを紹介しました。

今回はスクリプト内にクライアント シークレットや証明書が不要なマネージド ID を使用してのレポート取得方法と共にいくつかのサインイン ログ・監査ログを取得するサンプルをご用意いたしました。


マネージド ID は特殊なサービス プリンシパルであり、このサービスプリンシパルを用いて認証を行うには Azure 内部のみアクセス可能な特殊なエンドポイントに対して認証を行う必要があります。

通常のサービスプリンシパルと同じように RBAC を行うことで Azure 各種リソースへアクセスが可能になる一方、サービスプリンシパルと異なり明示的に証明書やクライアント シークレットをスクリプト内で指定したり、用意する必要はございません。

そのため、コード内に資格情報を埋め込むリスクや、証明書漏洩のリスクを考慮する必要がなくよりセキュアな運用が可能です。


マネージド ID については下記公開情報をご覧ください。

Azure リソースのマネージド ID とは

https://docs.microsoft.com/ja-jp/azure/active-directory/managed-identities-azure-resources/overview

なお、今回ご紹介しているサインイン ログを取得するスクリプトは Azure AD Premium P1 ライセンス以上のライセンスがテナントに対して 1 つ以上必要です。


### A. 事前準備 - マネージド ID を有効化します。 -
Azure Virtual Machine を 1 台デプロイします。
デプロイ後、スクリプトを実行する Azure Virtual Machine のマネージド ID を有効化します。
以下の手順に従って、マネージド ID を有効化します。

Resource Manager で VM にリソース グループへのアクセスを許可する

https://docs.microsoft.com/ja-jp/azure/active-directory/managed-identities-azure-resources/tutorial-windows-vm-access-arm#grant-your-vm-access-to-a-resource-group-in-resource-manager

上記公開情報記載の「Resource Manager で VM にリソース グループへのアクセスを許可する」の手順実行後、オブジェクト ID を記録しておきます。


### B. 事前準備 - サインイン ログ取得に必要な権限をマネージド ID に付与して付与します。 -

以下のコマンドを実行し、マネージド ID に対して Graph API および Azure Active Directory に対するサインイン ログ読み取りに必要な権限を割り当てます。

下記コマンド実行には Azure AD for Graph (Azure AD v2) が必要です。

インストールしていない場合には [Azure Active Directory の PowerShell モジュール](https://jpazureid.github.io/blog/azure-active-directory/powershell-module/) を参照しインストールください。


```PowerShell
# グローバル管理者でサインインします。
Connect-AzureAD

$graph = Get-AzureADServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"
$auditReadPermission =  $graph.AppRoles | Where-Object Value -Like "AuditLog.Read.All" | Where-Object AllowedMemberTypes -contains 'Application' | Select-Object -First 1
$directoryReadPermission = $graph.AppRoles | Where-Object Value -Like "Directory.Read.All" | Select-Object -First 1

# A. の手順で確認したマネージド ID の Object ID を以下の <ObjectID> 部分に代入します。
$msi = Get-AzureADServicePrincipal -ObjectId <ObjectID> 

New-AzureADServiceAppRoleAssignment -Id $auditReadPermission.Id -ObjectId $msi.ObjectId -PrincipalId $msi.ObjectId -ResourceId $graph.ObjectId
New-AzureADServiceAppRoleAssignment -Id $directoryReadPermission.Id -ObjectId $msi.ObjectId -PrincipalId $msi.ObjectId -ResourceId $graph.ObjectId
```


### C. サインイン ログの収集 - スクリプトの編集と実行 -

GitHub 上の以下のスクリプトをダウンロードし、マネージド ID を有効化した Azure Virtual Machine 上の C:\SignInReport 配下に保存します。

[Sample-GetSigninActivity.ps1](https://github.com/jpazureid/blog/blob/microsoft-graph-api-signin-activity-reports-v2/articles/azure-active-directory/aad-get-signinlog/Sample-GetSigninActivity.ps1)

保存後はファイル エクスポート先等適宜編集ください。
既定では過去 7 日のログを、スクリプトを実行したカレント ディレクトリ上に outfile.csv という名前で保存します。


### D. 参考情報 - スクリプトのフィルターの書き方について一例 -
上記サンプル スクリプトはサインイン アクティビティ レポートを出力するスクリプトですが、 URL (クエリ パラメーター) を編集することで様々なログの取得が可能です。

例 : 特定のリスクが検出されたサインイン イベントのみ抽出したい

(riskState eq 'atRisk' or riskState eq 'confirmedCompromised') というフィルターを追加します。

例 : 特定期間のサインイン イベントのみ抽出したい

(createdDateTime le $currentdate and createdDateTime ge $prevdate) といった具体に日時を指定してフィルターを追加します。

日時の形式は  2019-12-08T00:00:00Z といった形式にする必要があります。
スクリプト内で実行するのであれば、例えば以下のようなコマンドが考えられます。

// 現在日時を取得
> ((Get-Date).ToUniversalTime()).ToString("yyyy'-'MM'-'dd HH':'mm':'ss'Z'").Replace(' ', 'T')

// 現在日時から前日の値を取得
> ((Get-Date).ToUniversalTime()).AddDays(-1).ToString("yyyy'-'MM'-'dd HH':'mm':'ss'Z'").Replace(' ', 'T')


例 : 特定の OS からのアクセスを抽出したい
> (startswith(deviceDetail/operatingSystem, 'Ios') というフィルターを追加します。

クエリ パラメーターについては以下の公開情報を参照ください。

[クエリ パラメーターを使用して応答をカスタマイズする](https://docs.microsoft.com/ja-jp/graph/query-parameters)

### E. その他、 Graph API を実行する際の便利なツールなど
Graph API を利用するツールは他にも様々用意がございます。
ここではツールや、 Graph API を利用するにあたって必要な権限を調べる場合など


# Graph Explorer
視覚的に分かりやすく、必要な権限付与も行いやすいため URL が正しいか等を確認するのに最適です。

[Graph Explorer](https://developer.microsoft.com/ja-jp/graph/graph-explorer)

# Az コマンド
事前に Az コマンドをインストールする必要はありますが、今回のようにスクリプトを用意せずに実行することが可能です。
CLI ベースで確認されたい場合にはこちらをご利用ください。
Az rest コマンドを使用することで、任意の HTTP リクエストを作成し、取得することが可能です。

[Azure CLI のインストール](https://docs.microsoft.com/ja-jp/cli/azure/install-azure-cli?view=azure-cli-latest)


[az コマンドについての公開情報](https://docs.microsoft.com/ja-jp/cli/azure/reference-index?view=azure-cli-latest#az-rest)


# Graph API 公開情報
Graph API を実行する際には事前に権限付与が必要な場合があります。
例えば今回のサインイン ログの場合は以下の公開情報に記載のある通り、監査ログに対する読み取り権限が必要です。

実行する Graph API ごとに要求される権限が異なるため、公開情報から実行する Graph API に必要な権限を確認し、実行するアプリケーション、もしくはユーザーに権限付与を行ってください。

[List signIns](https://docs.microsoft.com/en-us/graph/api/signin-list?view=graph-rest-1.0&tabs=http)

「Application	AuditLog.Read.All and Directory.Read.All」という文言から、アプリケーションがこの Graph API を実行するにはこれらの権限が必要なことが分かります。
そのため事前準備でこれらの権限をアプリケーションに対して付与しました。


いかがでしたでしょうか。
お客様の要件に合わせて適宜フィルター条件を追加したり、整形しやすく出力することが可能です。

Azure AD 上のサインイン ログを長期的に保管する際に是非ご活用ください。
