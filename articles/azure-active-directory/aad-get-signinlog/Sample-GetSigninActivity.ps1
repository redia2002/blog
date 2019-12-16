########################################################
#
#Azure AD サインイン ログ取得スクリプト
#
#Lastupdate:2019/12/17
#詳細手順はXXXXXXXXXXXXXXXXXXXXXXXXXXを参照ください。
########################################################

Add-Type -Path ".\Tools\Microsoft.IdentityModel.Clients.ActiveDirectory\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"

## 環境に合わせ編集ください ##
$outfile = ".\outfile.csv" # ファイルエクスポート先パスです。任意の値を入力ください。
$ClientID     = "<ClientID>" # アプリケーションのクライアント ID です。
$ClientSecret =  "<ClientSecret>" # アプリケーションのクライアント シークレットです。
$tenantId = "<TenantId>" # ディレクトリ ID です。 Azure Active Directory のプロパティ - ディレクトリ ID より確認可能です。
## ここまで ##

$resource = "https://graph.microsoft.com" 
$daysago = "{0:s}" -f (get-date).AddDays(-7) + "Z"  # 例えば過去 30 日のデータを取得したい場合には $daysago = "{0:s}" -f (get-date).AddDays(-30) + "Z" とします。

$data = @()
$authUrl = "https://login.microsoftonline.com/$tenantId/" 
$authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext -ArgumentList $authUrl
$Credential = New-Object -TypeName "Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential" ($clientID, $clientSecret)
$authResult = $AuthContext.AcquireTokenAsync($resource, $Credential)
$headerParams = @{'Authorization' = "$($authResult.Result.AccessTokenType) $($authResult.Result.AccessToken)"}

## アクセス先 URL 、必要に応じてフィルター条件を追記します。
## フィルター例 "$resource/beta/auditLogs/signIns?api-version=beta&`$filter=((createdDateTime gt $daysago) and (startswith(deviceDetail/operatingSystem, 'Ios') or startswith(deviceDetail/operatingSystem, 'Android')))"
$uri = "$resource/beta/auditLogs/signIns?api-version=beta&`$filter=(createdDateTime gt $daysago)"


if ($null -ne $authResult.Result.AccessTokenType) {
    Do {
        $myReport = Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $uri
        $myReportValue = ($myReport.Content | ConvertFrom-Json).value
        $myReportVaultCount = $myReportValue.Count
        for ($j = 0; $j -lt $myReportVaultCount; $j++) {
            $eachEvent = @{}
 
            $thisEvent = $myReportValue[$j]
            $canumbers = $thisEvent.conditionalAccessPolicies.Count
 
            $eachEvent = $thisEvent |
            select id,
            createdDateTime,
            userDisplayName,
            userPrincipalName,
            userId,
            appId,
            appDisplayName,
            ipAddress,
            clientAppUsed,
            correlationId,
            conditionalAccessStatus,
 
            @{Name = 'status.errorCode'; Expression = {$_.status.errorCode}},
            @{Name = 'status.failureReason'; Expression = {$_.status.failureReason}},
            @{Name = 'status.additionalDetails'; Expression = {$_.status.additionalDetails}},
 
            @{Name = 'deviceDetail.deviceId'; Expression = {$_.deviceDetail.deviceId}},
            @{Name = 'deviceDetail.displayName'; Expression = {$_.deviceDetail.displayName}},
            @{Name = 'deviceDetail.operatingSystem'; Expression = {$_.deviceDetail.operatingSystem}},
            @{Name = 'deviceDetail.browser'; Expression = {$_.deviceDetail.browser}},

            @{Name = 'location.city'; Expression = {$_.location.city}},
            @{Name = 'location.state'; Expression = {$_.location.state}}
 
            for ($k = 0; $k -lt $canumbers; $k++) {
                $temp = $thisEvent.conditionalAccessPolicies[$k].id
                $eachEvent = $eachEvent | Add-Member @{"conditionalAccessPolicies.id$k" = $temp} -PassThru
 
                $temp = $thisEvent.conditionalAccessPolicies[$k].displayName
                $eachEvent = $eachEvent | Add-Member @{"conditionalAccessPolicies.displayName$k" = $temp} -PassThru
 
                $temp = $thisEvent.conditionalAccessPolicies[$k].enforcedGrantControls
                $eachEvent = $eachEvent | Add-Member @{"conditionalAccessPolicies.enforcedGrantControls$k" = $temp} -PassThru
 
                $temp = $thisEvent.conditionalAccessPolicies[$k].enforcedSessionControls
                $eachEvent = $eachEvent | Add-Member @{"conditionalAccessPolicies.enforcedSessionControls$k" = $temp} -PassThru
 
                $temp = $thisEvent.conditionalAccessPolicies[$k].result
                $eachEvent = $eachEvent | Add-Member @{"conditionalAccessPolicies.result$k" = $temp} -PassThru
            }
            $data += $eachEvent
            #
            #Get url from next link
            #
        }
        $url = ($myReport.Content | ConvertFrom-Json).'@odata.nextLink'
    }while ($url -ne $null)
}
else {
    Write-Host "ERROR: No Access Token"
}

$data | Sort-Object -Property createdDateTime  | Export-Csv $outfile -encoding "utf8" -NoTypeInformation
