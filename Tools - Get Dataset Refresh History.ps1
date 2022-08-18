#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(
    $workspaceId = "7331d174-e08f-4802-acba-898b8cecbc75"
    ,
    $datasetId = "ecb5768c-3057-433a-91c0-c56bece634ae"
)

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

# Get running refreshes, only 1 operation is allowed "Only one refresh operation at a time is accepted for a dataset. If there's a current running refresh operation and another is submitted"

Connect-PowerBIServiceAccount

Write-Host "Gateway Info"

$bindedGateways = Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/Default.GetBoundGatewayDatasources" -method Get | ConvertFrom-Json | select -ExpandProperty value

$bindedGateways | Format-Table

Write-Host "Refresh History"

$refreshes = Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/refreshes?`$top=5" -method Get | ConvertFrom-Json | select -ExpandProperty value

$refreshes | Format-Table

