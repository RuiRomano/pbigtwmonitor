This project aim to help organizations with multiple gateway clusters centralize all their gateway logs and reports into a central storage (ADLS Gen 2) and allow easy and quick exploration of those logs either by:

- Easily access all the gateway logs without having to remote access to the gateway server
- Explore the logs with a Power BI Report
- Explore the logs using a SPARK Engine like Azure Synapse Analytics

# Requirements

- Azure Data Lake Storage Gen2 with hierarchical namespace enabled
  
# Configuration

## Azure Data Lake Storage

Create an Azure Data Lake Storage Gen 2 storage account:

https://docs.microsoft.com/en-us/azure/storage/blobs/create-data-lake-storage-account

## Deploy Script into Gateway Server

Copy the powershell scripts into a folder in the Gateway server, ex: c:\PBIGTWMonitor\

## Change Config.Json

- Change the 'GatewayLogsPath' to the path where the gateway files are stored - [more info](https://docs.microsoft.com/en-us/data-integration/gateway/service-gateway-log-files)
- StorageAccountConnStr
- Optional - Output path
  
## Save GatewayProperties.txt

Execute an manual [Export Logs](https://docs.microsoft.com/en-us/data-integration/gateway/service-gateway-tshoot#collect-logs-from-the-on-premises-data-gateway-app) on the gateway and copy the the 'GatewayProperties.txt' file to the root folder of the scripts

## Schedule Task

Configure a Schedule Task to run the script [Run.ps1](./Run.ps1) every hour


# Power BI Template

