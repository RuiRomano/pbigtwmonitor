# Requirements

## Ensure you have the propper permissions

- A [Power BI Administrator](https://docs.microsoft.com/en-us/power-bi/admin/service-admin-role) account to change the [Tenant Settings](https://docs.microsoft.com/en-us/power-bi/guidance/admin-tenant-settings)
- Permissions to create an [Azure Active Directory Service Principal](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal) 
- Permissions to create/use an [Azure Active Directory Security Group](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-groups-create-azure-portal)

## Create a Service Principal & Security Group

On Azure Active Directory:

1. Go to "App Registrations" select "New App" and leave the default options
2. Generate a new "Client Secret" on "Certificates & secrets" and save the Secret text
3. Save the App Id & Tenant Id on the overview page of the service principal
4. Create a new Security Group on Azure Active Directory and add the Service Principal above as member

![image](https://user-images.githubusercontent.com/10808715/142396742-2d0b6de9-95ef-4b2a-8ca9-23c9f1527fa9.png)

## Authorize the Service Principal on PowerBI Tenant

As a Power BI Administrator go to the Power BI Tenant Settings and authorize the Security Group on the following tenant settings:

- "Allow service principals to use Power BI APIs"

## Add Service Principal as Gateway Owner

As a Power BI Administrator go to [Power Platform Admin Portal] (https://admin.powerplatform.microsoft.com/ext/DataGateways) and for each gateway add the security group as Gateway Admin

## Configuration

### Change Config.Json

- Change the 'GatewayLogsPath' to the path where the gateway files are stored - [more info](https://docs.microsoft.com/en-us/data-integration/gateway/service-gateway-log-files)
- StorageAccountConnStr
- Optional - Output path
- Optional - Configure ServicePrincipal metatada: Id, Secret, Tenant

### Save GatewayProperties.txt

Execute an manual [Export Logs](https://docs.microsoft.com/en-us/data-integration/gateway/service-gateway-tshoot#collect-logs-from-the-on-premises-data-gateway-app) on the gateway and save in the same folder of the scripts the 'GatewayProperties.txt'

## Schedule Task

Configure a Schedule Task to run the script [Run.ps1](./Run.ps1) every hour

## Power BI Template

