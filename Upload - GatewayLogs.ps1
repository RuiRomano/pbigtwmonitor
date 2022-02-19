param(               
    [psobject]$config
    ,
    [string]$stateFilePath    
)

try {
    Write-Host "Upload - GatewayLogs Start"

    $stopwatch = [System.Diagnostics.Stopwatch]::new()
    $stopwatch.Start()   

    Write-Host "Find gateway info..."

    $gateways = @(Invoke-PowerBIRestMethod -url "gateways" -method Get | ConvertFrom-Json -Depth 5 | Select -ExpandProperty value)

    $thisComputer = $env:COMPUTERNAME

    $currentGateway = @($gateways |? { ($_.gatewayAnnotation | ConvertFrom-Json).gatewayMachine -ieq $thisComputer })[0]

    if (!$currentGateway)
    {
        throw "Cannot find any gateway for '$thisComputer'. Make sure the ServicePrincipal is a gateway admin on: https://admin.powerplatform.microsoft.com/ext/DataGateways"
    }

    $gatewayId = $currentGateway.id

    $rootOutputPath = "$($config.OutputPath)\logs"

    $runDate = [datetime]::UtcNow
    $lastRunDate = $null

    $outputPath = ("$rootOutputPath\{0:yyyy}\{0:MM}\{0:dd}\$gatewayId" -f $runDate)  
    
    New-Item -ItemType Directory -Path $outputPath -ErrorAction SilentlyContinue | Out-Null

    ConvertTo-Json $currentGateway | Out-File "$outputPath\GatewayInfo.json" -force -Encoding utf8

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

    foreach ($path in $config.GatewayLogsPath) {

        $logFiles = @(Get-ChildItem -File -Path "$path\*.log" -ErrorAction SilentlyContinue)

        Write-Host "Gateway log count: $($logFiles.Count)"

        $logFiles = @($logFiles | ? { $_.LastWriteTimeUtc -gt $lastRunDate -or $lastRunDate -eq $null }) 

        Write-Host "Gateway log count modified since last run: $($logFiles.Count)"

        foreach ($logFile in $logFiles) {
            
            Write-Host "Copying file: '$($logFile.Name)'"

            Copy-Item -Path $logFile.FullName -Destination $outputPath -Force
        }

        Add-FolderToBlobStorage -storageAccountConnStr $config.StorageAccountConnStr -storageContainerName $config.StorageAccountContainerName -storageRootPath $config.StorageAccountContainerRootPath -folderPath $outputPath -rootFolderPath $config.OutputPath
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