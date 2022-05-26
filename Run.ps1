#requires -Modules Az.Storage
#requires -Modules MicrosoftPowerBIMgmt.Profile

param(
    [string]$configFilePath = ".\Config - RRMSFT.json"
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
