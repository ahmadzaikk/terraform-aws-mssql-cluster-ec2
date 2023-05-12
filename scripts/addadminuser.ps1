param(

   

    [Parameter(Mandatory=$true)]
    [string]$AdminSecrets

)
$Admin = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecrets).SecretString

Add-LocalGroupMember -Group Administrators -Member $Admin.UserName -Verbose