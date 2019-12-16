---
title: クライアント シークレットを利用して Azure AD サインイン アクティビティ レポートを CSV ファイルで取得する PowerShell スクリプト
date: 2019-12-16
tags:
  - Azure AD
  - graph api
  - signin log
---

# クライアント シークレットを利用して Azure AD サインイン アクティビティ レポートを CSV ファイルで取得する PowerShell スクリプト

こんにちは、 Azure & Identity サポート チームの平形です。
以前紹介した Azure AD のサインイン アクティビティ レポートと監査アクティビティ レポートを Azure AD Graph API を経由して取得するスクリプトを紹介しました。
今回はモジュールの更新によってコマンド等も少々変わっておりますので、改めてのご紹介と共にいくつかのサインイン ログ・監査ログを取得するサンプルをご用意いたしました。

前回は証明書を使ってトークンを取得する手順をご案内いたしましたので、今回は平文のキーを使っての取得方法をお伝えします。
セキュリティ観点では証明書を用いて認証を行う前回のスクリプトを推奨しますが、手元で簡易的にテストする際などは平文のキーの方が容易なため、テスト目的で利用する場合はこちらをご利用いただければと存じます。

なお、今回ご紹介しているサインイン ログを取得するスクリプトは Azure AD Premium P1 ライセンス以上のライセンスがテナントに対して 1 つ以上必要です。


### A. 事前準備 - Azure AD 上にアプリケーションを登録する -
認証に使用するアプリケーションを Azure AD に登録します。
以下の手順に従って、アプリケーションを登録します。

Azure AD Reporting API にアクセスするための前提条件

https://docs.microsoft.com/ja-jp/azure/active-directory/active-directory-reporting-api-prerequisites-azure-portal

上記公開情報記載の「構成設定を収集する」に記載されております以下の内容を手元に記録しておきます。

- ドメイン名
- クライアント ID
- クライアント シークレット (クライアント シークレットの取り扱いには十分に注意ください。)


なお、上記公開情報記載の手順では「API を使用するためのアクセス許可をアプリケーションに付与するには」にて「Azure Active Directory Graph」に対してアクセス許可を付与する手順が記載されておりますが、後述のスクリプトを実行するためには 「Microsoft Graph」の監査ログの読み取り権限も必要です。
上記公開手順実施に合わせて以下の手順も実施ください。

1. [API のアクセス許可] - [アクセス許可の追加] の順に選択します。
2. [+ アクセス許可の追加] を選択します。
3. [Microsoft Graph] を選択します。
4. [アプリケーションの許可] を選択し、 AuditLog.Read.All を選択します。選択後は画面下の「アクセス許可の追加」を選択します。

![](./aad-get-signinlog/appview.jpg)

5. アクセス許可の追加後、「XX に管理者の同意を与えます」を選択し、権限を付与します。


### B. 処理に必要なライブラリを nuget で取得するスクリプトの準備と実行
こちらは前回と同様の手順です。
テキスト エディターを開き、下記の URL から GetModuleByNuget.ps1 をダウンロードします。
ダウンロードしたファイルを C:\SignInReport フォルダー配下に保存および実行ください。

本スクリプトを実行すると、C:\SignInReport 配下に Tools というフォルダーが作成され、Microsoft.IdentityModel.Clients.ActiveDirectory.dll などのファイルが保存されます。

[GetModuleByNuget.ps1](https://github.com/jpazureid/blog/blob/microsoft-graph-api-signin-activity-reports-v2/articles/azure-active-directory/aad-get-signinlog/GetModuleByNuget.ps1)


### C. スクリプトの編集と実行

GitHub 上の以下のスクリプトをダウンロードし、 C:\SignInReport 配下に保存します。

[Sample-GetSigninActivity.ps1](https://github.com/jpazureid/blog/blob/microsoft-graph-api-signin-activity-reports-v2/articles/azure-active-directory/aad-get-signinlog/Sample-GetSigninActivity.ps1)

保存後はクライアント シークレットなどの箇所を作成したアプリの値に合わせて編集ください。


### D. 編集箇所について
上記サンプル スクリプトはサインイン アクティビティ レポートを出力するスクリプトですが、 URL (クエリ パラメーター) を編集することで様々なログの取得が可能です。

**例 : 特定のリスクが検出されたサインイン イベントのみ抽出したい**

(riskState eq 'atRisk' or riskState eq 'confirmedCompromised') というフィルターを追加します。

**例 : 特定期間のサインイン イベントのみ抽出したい**

(createdDateTime le $currentdate and createdDateTime ge $prevdate) といった具体に日時を指定してフィルターを追加します。

日時の形式は  2019-12-08T00:00:00Z といった形式にする必要があります。
スクリプト内で実行するのであれば、例えば以下のようなコマンドが考えられます。

// 現在日時を取得
> ((Get-Date).ToUniversalTime()).ToString("yyyy'-'MM'-'dd HH':'mm':'ss'Z'").Replace(' ', 'T')

// 現在日時から前日の値を取得
> ((Get-Date).ToUniversalTime()).AddDays(-1).ToString("yyyy'-'MM'-'dd HH':'mm':'ss'Z'").Replace(' ', 'T')


**例 : 特定の OS からのアクセスを抽出したい**

(startswith(deviceDetail/operatingSystem, 'Ios') というフィルターを追加します。

クエリ パラメーターについては以下の公開情報を参照ください。

[クエリ パラメーターを使用して応答をカスタマイズする](https://docs.microsoft.com/ja-jp/graph/query-parameters)


### E. その他、 Graph API を実行する際の便利なツールなど
Graph API を利用するツールは他にも様々用意がございます。
ここではツールや、 Graph API を利用するにあたって必要な権限を調べる場合などで便利なツールや公開情報をご紹介いたします。


#### Graph Explorer
視覚的に分かりやすく、必要な権限付与も行いやすいため URL が正しいか等を確認するのに最適です。

[Graph Explorer](https://developer.microsoft.com/ja-jp/graph/graph-explorer)

#### Az コマンド
事前に Az コマンドをインストールする必要はありますが、今回のようにスクリプトを用意せずに実行することが可能です。
CLI ベースで確認されたい場合にはこちらをご利用ください。
Az rest コマンドを使用することで、任意の HTTP リクエストを作成し、取得することが可能です。

[Azure CLI のインストール](https://docs.microsoft.com/ja-jp/cli/azure/install-azure-cli?view=azure-cli-latest)


[az コマンドについての公開情報](https://docs.microsoft.com/ja-jp/cli/azure/reference-index?view=azure-cli-latest#az-rest)


#### Graph API 公開情報
Graph API を実行する際には事前に権限付与が必要な場合があります。
例えば今回のサインイン ログの場合は以下の公開情報に記載のある通り、監査ログに対する読み取り権限が必要です。

実行する Graph API ごとに要求される権限が異なるため、公開情報から実行する Graph API に必要な権限を確認し、実行するアプリケーション、もしくはユーザーに権限付与を行ってください。

[List signIns](https://docs.microsoft.com/en-us/graph/api/signin-list?view=graph-rest-1.0&tabs=http)

「Application	AuditLog.Read.All and Directory.Read.All」という文言から、アプリケーションがこの Graph API を実行するにはこれらの権限が必要なことが分かります。
そのため事前準備でこれらの権限をアプリケーションに対して付与しました。


***
いかがでしたでしょうか。
お客様の要件に合わせて適宜フィルター条件を追加したり、整形しやすく出力することが可能です。

Azure AD 上のサインイン ログを長期的に保管する際に是非ご活用ください。
