 param(
    [Parameter(Mandatory=$true)]
    [string]$DomainDNSServer1,

    [Parameter(Mandatory=$true)]
    [string]$DomainDNSServer2

)

Set-DnsClientServerAddress -InterfaceAlias * -ServerAddresses $DomainDNSServer1,$DomainDNSServer2

 
