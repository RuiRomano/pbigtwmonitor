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

    $gatewayPropertiesFilePath = ".\GatewayProperties.txt"

    if (!(Test-Path $gatewayPropertiesFilePath))
    {
        Write-Warning "GatewayProperties.txt is not found on '$gatewayPropertiesFilePath', trying to solve the gateway name using the Power BI REST API's."

        Write-Host "Discover gateway properties..."

        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $config.ServicePrincipal.AppId, ($config.ServicePrincipal.AppSecret | ConvertTo-SecureString -AsPlainText -Force)

        Connect-PowerBIServiceAccount -ServicePrincipal -Tenant $config.ServicePrincipal.TenantId -Credential $credential -Environment $config.ServicePrincipal.Environment

        $gateways = @(Invoke-PowerBIRestMethod -url "gateways" -method Get | ConvertFrom-Json | Select -ExpandProperty value)

        $thisComputer = $env:COMPUTERNAME

        $currentGateway = @($gateways |? { ($_.gatewayAnnotation | ConvertFrom-Json).gatewayMachine -ieq $thisComputer })[0]

        if (!$currentGateway)
        {
            throw "Cannot find any gateway for server '$thisComputer'. Make sure the ServicePrincipal is a gateway admin on: https://admin.powerplatform.microsoft.com/ext/DataGateways"
        }     
        
        $gatewayProperties = @{
            GatewayObjectId = $currentGateway.id
            ;
            GatewayName = $currentGateway.name
        }
    }
    else {
        Write-Host "GatewayProperties is present, will skip the API connection"

        $gatewayProperties = Get-Content $gatewayPropertiesFilePath | ConvertFrom-Json
    }

    $gatewayId = $gatewayProperties.GatewayObjectId
   
    $runDate = [datetime]::UtcNow

    $lastRunDate = $null

    $localOutputPath  = $config.OutputPath

    $outputPathLogs = ("$($config.StorageAccountContainerRootPath)/{0:gatewayid}/logs" -f  $gatewayId)  

    $outputPathMetadata = ("$($config.StorageAccountContainerRootPath)/{0:gatewayid}/metadata" -f $gatewayId)  

    $outputPathReports = ("$($config.StorageAccountContainerRootPath)/{0:gatewayid}/reports" -f $gatewayId)
    
    # Ensure folders
    @($localOutputPath) |% {
        New-Item -ItemType Directory -Path $_ -ErrorAction SilentlyContinue | Out-Null
    }

    $gatewayMetadataFilePath = "$localOutputPath\GatewayProperties.json"

    ConvertTo-Json $gatewayProperties | Out-File $gatewayMetadataFilePath -force -Encoding utf8

    ProcessLogFiles -logFiles (Get-ChildItem $gatewayMetadataFilePath) -storagePath $outputPathMetadata   

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

    foreach ($path in $config.GatewayLogsPath) {

        $logFiles = @(Get-ChildItem -File -Path "$path\*.log" -ErrorAction SilentlyContinue)

        Write-Host "Gateway log count: $($logFiles.Count)"

        $logFiles = @($logFiles | ? { $_.LastWriteTimeUtc -gt $lastRunDate -or $lastRunDate -eq $null })         

        ProcessLogFiles -logFiles $logFiles -storagePath $outputPathLogs -executionDate $runDate -tempPath $localOutputPath

        $logFiles = @(Get-ChildItem -File -Path "$path\report\*.log" -ErrorAction SilentlyContinue)

        Write-Host "Gateway Report log count: $($logFiles.Count)"

        $logFiles = @($logFiles | ? { $_.LastWriteTimeUtc -gt $lastRunDate -or $lastRunDate -eq $null }) 

        ProcessLogFiles -logFiles $logFiles -storagePath $outputPathReports -tempPath $localOutputPath    

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