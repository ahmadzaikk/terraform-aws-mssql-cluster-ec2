param(

    [Parameter(Mandatory=$true)]
    [string]$SQLSecrets
)
$SQLUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $SQLSecrets).SecretString
Add-LocalGroupMember -Group Administrators -Member $SQLUser.UserName -Verbose