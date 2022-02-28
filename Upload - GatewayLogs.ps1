param(               
    [psobject]$config
    ,
    [string]$stateFilePath    
)

function ProcessLogFiles ($logFiles, $outputPath)
{
    Write-Host "Log count modified since last run: $($logFiles.Count)"

    foreach ($logFile in $logFiles) {
        
        Write-Host "Copying file: '$($logFile.Name)'"

        $fileOutputPath = "$outputPath\$($logFile.Name)"

        Copy-Item -Path $logFile.FullName -Destination $fileOutputPath -Force

        Add-FileToBlobStorage -storageAccountConnStr $config.StorageAccountConnStr -storageContainerName $config.StorageAccountContainerName -storageRootPath $config.StorageAccountContainerRootPath -filePath $fileOutputPath -rootFolderPath $config.OutputPath            
    }
}


try {
    Write-Host "Upload - GatewayLogs Start"

    $stopwatch = [System.Diagnostics.Stopwatch]::new()
    $stopwatch.Start()   

    Write-Host "Find gateway info..."

    $gateways = @(Invoke-PowerBIRestMethod -url "gateways" -method Get | ConvertFrom-Json | Select -ExpandProperty value)

    $thisComputer = $env:COMPUTERNAME

    $currentGateway = @($gateways |? { ($_.gatewayAnnotation | ConvertFrom-Json).gatewayMachine -ieq $thisComputer })[0]

    if (!$currentGateway)
    {
        throw "Cannot find any gateway for server '$thisComputer'. Make sure the ServicePrincipal is a gateway admin on: https://admin.powerplatform.microsoft.com/ext/DataGateways"
    }

    $gatewayId = $currentGateway.id
   
    $runDate = [datetime]::UtcNow
    $lastRunDate = $null

    $outputPathLogs = ("$($config.OutputPath)\{1:gatewayid}\\logs\\{0:yyyy}\\{0:MM}\\{0:dd}" -f $runDate, $gatewayId)  

    $outputPathMetadata = ("$($config.OutputPath)\{0:gatewayid}\\metadata" -f $gatewayId)  

    $outputPathReports = ("$($config.OutputPath)\{0:gatewayid}\\reports" -f $gatewayId)
    
    # Ensure folders
    @($outputPathLogs, $outputPathMetadata, $outputPathReports) |% {
        New-Item -ItemType Directory -Path $_ -ErrorAction SilentlyContinue | Out-Null
    }

    $gatewayMetadataFilePath = "$outputPathMetadata\GatewayMetadata.json"

    ConvertTo-Json $currentGateway | Out-File $gatewayMetadataFilePath -force -Encoding utf8

    Add-FileToBlobStorage -storageAccountConnStr $config.StorageAccountConnStr -storageContainerName $config.StorageAccountContainerName -storageRootPath $config.StorageAccountContainerRootPath -filePath $gatewayMetadataFilePath -rootFolderPath $config.OutputPath            

    if (!$stateFilePath) {
        $stateFilePath = "$($config.OutputPath)\state.json"
    }

    if (Test-Path $stateFilePath) {
        $state = Get-Content $stateFilePath | ConvertFrom-Json
    }
    else {
        $state = New-Object psobject 
    }
    
    if ($state.GatewayLogs.LastRun) {
        if (!($state.GatewayLogs.LastRun -is [datetime])) {
            $state.GatewayLogs.LastRun = [datetime]::Parse($state.GatewayLogs.LastRun).ToUniversalTime()
        }
        $lastRunDate = $state.GatewayLogs.LastRun
    }
    else {
        $state | Add-Member -NotePropertyName "GatewayLogs" -NotePropertyValue @{"LastRun" = $null } -Force
    }

    Write-Host "LastRun: '$lastRunDate'"

    if (!(Test-Path $config.GatewayLogsPath))
    {
        throw "Cannot find gateway logs path '$($config.GatewayLogsPath)' - https://docs.microsoft.com/en-us/data-integration/gateway/service-gateway-log-files"
    }

    foreach ($path in $config.GatewayLogsPath) {

        $logFiles = @(Get-ChildItem -File -Path "$path\*.log" -ErrorAction SilentlyContinue)

        Write-Host "Gateway log count: $($logFiles.Count)"

        $logFiles = @($logFiles | ? { $_.LastWriteTimeUtc -gt $lastRunDate -or $lastRunDate -eq $null })         

        ProcessLogFiles -logFiles $logFiles -outputPath $outputPathLogs

        $logFiles = @(Get-ChildItem -File -Path "$path\report\*.log" -ErrorAction SilentlyContinue)

        Write-Host "Gateway Report log count: $($logFiles.Count)"

        $logFiles = @($logFiles | ? { $_.LastWriteTimeUtc -gt $lastRunDate -or $lastRunDate -eq $null }) 

        ProcessLogFiles -logFiles $logFiles -outputPath $outputPathReports     
    }
    
    # Save state 

    $state.GatewayLogs.LastRun = $runDate.ToString("o")

    New-Item -Path (Split-Path $stateFilePath -Parent) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    
    ConvertTo-Json $state | Out-File $stateFilePath -force -Encoding utf8

}
finally {
    $stopwatch.Stop()

    Write-Host "Ellapsed: $($stopwatch.Elapsed.TotalSeconds)s"
}