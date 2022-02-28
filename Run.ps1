#Requires -Modules Az.Storage, MicrosoftPowerBIMgmt.Profile

param(
    [string]$configFilePath = ".\Config.json"
    ,
    [array]$scriptsToRun = @(
        ".\Upload - GatewayLogs.ps1"
    )
)

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

Import-Module "$currentPath\Utils.psm1" -Force

Write-Host "Current Path: $currentPath"

Write-Host "Config Path: $configFilePath"

if (Test-Path $configFilePath) {
    $config = Get-Content $configFilePath | ConvertFrom-Json

    # Default Values

    if (!$config.OutputPath) {        
        $config | Add-Member -NotePropertyName "OutputPath" -NotePropertyValue ".\\Data" -Force
    }
}
else {
    throw "Cannot find config file '$configFilePath'"
}

try {

    Write-Host "Connecting to PowerBI..."
    
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $config.ServicePrincipal.AppId, ($config.ServicePrincipal.AppSecret | ConvertTo-SecureString -AsPlainText -Force)

    Connect-PowerBIServiceAccount -ServicePrincipal -Tenant $config.ServicePrincipal.TenantId -Credential $credential -Environment $config.ServicePrincipal.Environment

    foreach ($scriptToRun in $scriptsToRun)
    {        
        try {
            Write-Host "Running '$scriptToRun'"

            & $scriptToRun -config $config
        }
        catch {            
            Write-Error "Error on '$scriptToRun' - $($_.Exception.ToString())" -ErrorAction Continue            
        }   
    }
}
catch {

    $ex = $_.Exception

    throw    
}
