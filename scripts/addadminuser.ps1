param(

   

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret

)
$Admin = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret).SecretString

Add-LocalGroupMember -Group Administrators -Member $Admin.UserName -Verbose