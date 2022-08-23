param(               
    [psobject]$config
    ,
    [string]$stateFilePath     
)

function ProcessLogFiles ($logFiles, $storagePath, $executionDate, $tempPath)
{
    Write-Host "Files modified since last run: $($logFiles.Count)"

    foreach ($logFile in $logFiles) {
                
        $storagePathTemp = $storagePath

        # Try to parse the date out of the file name

        if ($executionDate)
        {
            $dateRegExMatches = ($logFile.Name | Select-String  -pattern ".+(\d{8}).\d+").Matches

            if ($dateRegExMatches)
            {
                $fileDateStr = $dateRegExMatches.Groups[1].Value

                $fileDate = [datetime]::ParseExact($fileDateStr, "yyyyMMdd", [Globalization.CultureInfo]::InvariantCulture)            
            }
            else
            {
                $fileDate = $executionDate            
            }

            if ($fileDate)
            {
                $storagePathTemp = ("$storagePath/{0:yyyy}/{0:MM}/{0:dd}" -f $fileDate)
            }
        }
        
        if ($tempPath)
        {
            # Local copy the file, because it could be blocked by Gateway

            Write-Host "Copying file: '$($logFile.FullName)' to '$tempPath'"

            $fileOutputPath = "$tempPath\$($logFile.Name)"                

            New-Item -ItemType Directory -Path (Split-Path $fileOutputPath -Parent) -ErrorAction SilentlyContinue | Out-Null

            Copy-Item -Path $logFile.FullName -Destination $fileOutputPath -Force
        }
        else{
            $fileOutputPath = $logFile.FullName
        }

        Write-Host "Sync '$fileOutputPath' to BlobStorage"

        # Send to Storage

        Add-FileToBlobStorage -storageRootPath $storagePathTemp -filePath $fileOutputPath -storageAccountConnStr $config.StorageAccountConnStr -storageContainerName $config.StorageAccountContainerName        

        if ($tempPath)
        {
            Write-Host "Deleting local file copy: '$fileOutputPath'"

            # Remove the local copy 
            
            Remove-Item $fileOutputPath -Force
        }
    }
}


try {
    Write-Host "Upload - GatewayLogs Start"

    $stopwatch = [System.Diagnostics.Stopwatch]::new()
    $stopwatch.Start()   
   
    $runDate = [datetime]::UtcNow

    $lastRunDate = $null

    $localOutputPath  = $config.OutputPath
    
    # Ensure folders
    @($localOutputPath) |% {
        New-Item -ItemType Directory -Path $_ -ErrorAction SilentlyContinue | Out-Null
    }

    if (!$stateFilePath) {
        $stateFilePath = ".\state.json"
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

    foreach ($obj in $config.GatewayLogsPath) {

        $gatewayProperties = @{                
            GatewayObjectId = $null             
        }

        if ($obj -is [PSCustomObject])
        {
            $path = $obj.Path

            $gatewayProperties.GatewayObjectId = $obj.GatewayId
            $gatewayProperties.GatewayName = $obj.GatewayName        
        }
        else {
            $path = $obj
        }

        # If GatewayObjectId is not specified try to find it in the logs

        if (!$gatewayProperties.GatewayObjectId)
        {
            $reportFile = Get-ChildItem -path $path -Recurse  |? {$_.Name -ilike "SystemCounterAggregationReport_*"} | Select -first 1

            if (!$reportFile)
            {
                throw "Cannot find a Gateway report file 'SystemCounterAggregationReport_*' to infer the GatewayId, please configure the config.json to configure the GatewayId"
            }

            $gatewayIdFromCSV = Get-Content -path $reportFile.FullName -First 2 | ConvertFrom-Csv | Select -ExpandProperty GatewayObjectId
            
            $gatewayProperties.GatewayObjectId = $gatewayIdFromCSV  

        }

        # Try to get the gateway core count

        if (!$gatewayProperties.NumberOfCores)
        {    
            try {
                $serverCPU = (Get-ComputerInfo -Property CsProcessors).CsProcessors

                $gatewayProperties.NumberOfCores = $serverCPU.NumberOfLogicalProcessors
            }
            catch {
                Write-Warning "Error getting the server core count"
            }
        }

        $gatewayId = $gatewayProperties.GatewayObjectId

        if (!$gatewayId)
        {
            throw "Gateway Id is not defined."
        }

        $outputPathLogs = ("$($config.StorageAccountContainerRootPath)/{0:gatewayid}/logs" -f  $gatewayId)  

        $outputPathMetadata = ("$($config.StorageAccountContainerRootPath)/{0:gatewayid}/metadata" -f $gatewayId)  
    
        $outputPathReports = ("$($config.StorageAccountContainerRootPath)/{0:gatewayid}/reports" -f $gatewayId)

        # GatewayProperties json file 

        $gatewayMetadataFilePath = "$localOutputPath\GatewayProperties.json"

        ConvertTo-Json $gatewayProperties | Out-File $gatewayMetadataFilePath -force -Encoding utf8

        ProcessLogFiles -logFiles (Get-ChildItem $gatewayMetadataFilePath) -storagePath $outputPathMetadata   
        
        # Gateway Logs

        $logFiles = @(Get-ChildItem -File -Path "$path\*.log" -ErrorAction SilentlyContinue)

        Write-Host "Gateway log count: $($logFiles.Count)"

        $logFiles = @($logFiles | ? { $_.LastWriteTimeUtc -gt $lastRunDate -or $lastRunDate -eq $null })         

        ProcessLogFiles -logFiles $logFiles -storagePath $outputPathLogs -executionDate $runDate -tempPath $localOutputPath

        # Gateway Reports

        $logFiles = @(Get-ChildItem -File -Path "$path\report\*.log" -ErrorAction SilentlyContinue)

        Write-Host "Gateway Report log count: $($logFiles.Count)"

        $logFiles = @($logFiles | ? { $_.LastWriteTimeUtc -gt $lastRunDate -or $lastRunDate -eq $null }) 

        ProcessLogFiles -logFiles $logFiles -storagePath $outputPathReports -tempPath $localOutputPath    

        # Gateway Config Properties

        $logFiles = @(Get-ChildItem -File -Path "$path\*ConfigurationProperties.json" -ErrorAction SilentlyContinue)

        Write-Host "Gateway Config file count: $($logFiles.Count)"

        $logFiles = @($logFiles | ? { $_.LastWriteTimeUtc -gt $lastRunDate -or $lastRunDate -eq $null }) 

        ProcessLogFiles -logFiles $logFiles -storagePath $outputPathMetadata -tempPath $localOutputPath 
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