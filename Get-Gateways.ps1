param(
    [string]$configFilePath = ".\Config - RRMSFT.json"    
)

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

Import-Module MicrosoftPowerBIMgmt.Profile -MinimumVersion 1.2.1077 -Force

Write-Host "Current Path: $currentPath"

Write-Host "Config Path: $configFilePath"

if (Test-Path $configFilePath) {
    $config = Get-Content $configFilePath | ConvertFrom-Json
}
else {
    throw "Cannot find config file '$configFilePath'"
}


Write-Host "Connecting to PowerBI..."

$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $config.ServicePrincipal.AppId, ($config.ServicePrincipal.AppSecret | ConvertTo-SecureString -AsPlainText -Force)

Connect-PowerBIServiceAccount -ServicePrincipal -Tenant $config.ServicePrincipal.TenantId -Credential $credential -Environment $config.ServicePrincipal.Environment

$gatewaysJson = Invoke-PowerBIRestMethod -url "gateways" -method Get

Write-Host "Saving gateway info to: '$currentPath\GatewayInfo.json'"
$gatewaysJson | Out-File "$currentPath\GatewayInfo.json"
