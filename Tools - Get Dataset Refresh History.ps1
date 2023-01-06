﻿#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(
    $datasets = @(
        @{workspaceId = "ff9f6b54-83e8-4aa5-901b-a7675e001c77";datasetId = "4aee5203-4d36-4b2e-87b4-904a7bd38016"}
        ,
        @{workspaceId = "7331d174-e08f-4802-acba-898b8cecbc75";datasetId = "ecb5768c-3057-433a-91c0-c56bece634ae"}
    )
)

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

# Get running refreshes, only 1 operation is allowed "Only one refresh operation at a time is accepted for a dataset. If there's a current running refresh operation and another is submitted"

Connect-PowerBIServiceAccount

foreach ($dataset in $datasets)
{    
    Write-Host "Workspace: $($dataset.workspaceId); Dataset: $($dataset.datasetId)"
    
    Write-Host "Gateway Info"

    $bindedGateways = Invoke-PowerBIRestMethod -url "groups/$($dataset.workspaceId)/datasets/$($dataset.datasetId)/Default.GetBoundGatewayDatasources" -method Get | ConvertFrom-Json | select -ExpandProperty value

    $bindedGateways | Format-Table

    Write-Host "Refresh History"

    # https://docs.microsoft.com/en-us/rest/api/power-bi/datasets/get-refresh-history-in-group

    $refreshes = Invoke-PowerBIRestMethod -url "groups/$($dataset.workspaceId)/datasets/$($dataset.datasetId)/refreshes?`$top=5" -method Get | ConvertFrom-Json | select -ExpandProperty value

    $refreshes | Format-Table
}