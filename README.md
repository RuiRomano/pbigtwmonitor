# Configuration

## Change Config.Json

- Change the 'GatewayLogsPath' to the path where the gateway files are stored - [more info](https://docs.microsoft.com/en-us/data-integration/gateway/service-gateway-log-files)
- StorageAccountConnStr
- Optional - Output path
  
## Save GatewayProperties.txt

Execute an manual [Export Logs](https://docs.microsoft.com/en-us/data-integration/gateway/service-gateway-tshoot#collect-logs-from-the-on-premises-data-gateway-app) on the gateway and copy the the 'GatewayProperties.txt' file to the root folder of this solution

# Schedule Task

Configure a Schedule Task to run the script [Run.ps1](./Run.ps1) every hour

# Power BI Template

