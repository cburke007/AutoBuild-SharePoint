#Function Get NetBios Name for current AD
function Get-LocalLogonInformation
{
    try
    {

        $ADSystemInfo = New-Object -ComObject ADSystemInfo

        $type = $ADSystemInfo.GetType()

        New-Object -TypeName PSObject -Property @{

            UserDistinguishedName = $type.InvokeMember('UserName','GetProperty',$null,$ADSystemInfo,$null)
            ComputerDistinguishedName = $type.InvokeMember('ComputerName','GetProperty',$null,$ADSystemInfo,$null)
            SiteName = $type.InvokeMember('SiteName','GetProperty',$null,$ADSystemInfo,$null)
            DomainShortName = $type.InvokeMember('DomainShortName','GetProperty',$null,$ADSystemInfo,$null)
            DomainDNSName = $type.InvokeMember('DomainDNSName','GetProperty',$null,$ADSystemInfo,$null)
            ForestDNSName = $type.InvokeMember('ForestDNSName','GetProperty',$null,$ADSystemInfo,$null)
            PDCRoleOwnerDistinguishedName = $type.InvokeMember('PDCRoleOwner','GetProperty',$null,$ADSystemInfo,$null)
            SchemaRoleOwnerDistinguishedName = $type.InvokeMember('SchemaRoleOwner','GetProperty',$null,$ADSystemInfo,$null)
            IsNativeModeDomain = $type.InvokeMember('IsNativeMode','GetProperty',$null,$ADSystemInfo,$null)
        }

    }

    catch
    {

        throw
    }
}

# Get current script execution path and the parent path
$0 = $myInvocation.MyCommand.Definition
$env:dp0 = [System.IO.Path]::GetDirectoryName($0)
$bits = Get-Item $env:dp0 | Split-Path -Parent
$env:AutoSPPath = $bits + "\AutoSPInstaller"

$AutoSPXML = [xml](get-content "$env:AutoSPPath\Default_AutoSPInstallerInput.xml" -EA 0)
    
# Start Logging of CORE AD Info Tab data
$netbios = (Get-LocalLogonInformation).DomainShortName
$dnsName = (Get-LocalLogonInformation).DomainDNSName
$forestName = (Get-LocalLogonInformation).ForestDNSName
$dom = [System.DirectoryServices.ActiveDirectory.Domain]::getcurrentdomain()
$domControllers = $dom.DomainControllers | Select Name
$dcs = ""

foreach($domController in $domControllers)
{
    $dcName = $domController.Name
    $dcShortName = $dcName.Split(".")
    if($dcs -eq ""){$dcs = $dcShortName[0]}
    else{$dcs = $dcs + ", " + $dcShortName[0]}
}

$custNum = Read-Host "Enter the Customer Account Number "
$ticketNum = Read-Host "What is the Install Ticket Number? "

# Open/Create the CORE AD Info file    
$text = "$env:dp0\COREInfo.txt"

"<b>Forest:</b> $forestName" | out-file "$text"
"<b>Domain:</b> $dnsName" | out-file "$text" -Append
"<b>NetBios:</b> $netbios" | out-file "$text" -Append
"<b>Domain Controllers:</b> $dcs" | out-file "$text" -Append
"<b>Restore password:</b> " | out-file "$text" -Append

$loggedOnUser = [Environment]::UserName
$loDomainUser = $netbios + "\" + $loggedOnUser
"<b>Domain Admin Account:</b> $loDomainUser" | out-file "$text" -Append



# Get the Farm Prefix
$FarmPrefix = Read-Host "Enter a Prefix to be used in the Farm (MAX 5 chars - ex. Dev or Prod or Leave Blank for No Prefix) "   
$AutoSPXML.Configuration.Farm.Database.DBPrefix = [string]$FarmPrefix

"<b>SharePoint Farm:</b> $FarmPrefix" | out-file "$text" -Append

# Set the Environment attribute
$AutoSPXML.Configuration.Environment = $custNum + "_" + $FarmPrefix

#Choose the edition of SharePoint you are installing
Write-Host -ForegroundColor Yellow "Choose your Version (Default == SharePoint 2010)"
Write-Host -ForegroundColor Cyan "1. SharePoint 2010"
Write-Host -ForegroundColor Cyan "2. SharePoint 2013"
Write-Host -ForegroundColor Cyan " "
$VerChoice = Read-Host "Select 1-2: "

switch($VerChoice)
{
    1 {$Version = "2010"}
    2 {$Version = "2013"}
    default {$Version = "2010"}
}
Write-Host ""

$AutoSPXML.Configuration.Install.SetAttribute("SPVersion", $Version)

#Choose the edition of SharePoint you are installing
Write-Host -ForegroundColor Yellow "Choose your Edition (Default == Foundation)"
Write-Host -ForegroundColor Cyan "1. Foundation"
Write-Host -ForegroundColor Cyan "2. Standard"
Write-Host -ForegroundColor Cyan "3. Enterprise"
Write-Host -ForegroundColor Cyan " "
$EdChoice = Read-Host "Select 1-3: "

switch($EdChoice)
{
    1 {$Edition = "Foundation"}
    2 {$Edition = "Standard"}
    3 {$Edition = "Enterprise"}
    default {$Edition = "Foundation"}
}
Write-Host ""

$AutoSPXML.Configuration.Install.SKU = [string]$Edition

$spVer = $Version + " " + $Edition
"<b>SharePoint Version:</b> SharePoint $spVer" | out-file "$text" -Append

$custKey = Read-Host "Is this a customer provided license? (Blank/Default = N) "

if($Edition -ne "Foundation"){$ProductKey = Read-Host "Enter the Product Installation Key "}
else{$ProductKey = ""}
$AutoSPXML.Configuration.Install.PIDKey = [string]$ProductKey

if($custKey -eq "y" -or "Y")
{
    "<b>Customer Key:</b> $ProductKey" | out-file "$text" -Append
}

$FarmPass = Read-Host "Enter the Passphrase to use for the Farm (Blank/Default = R@ckSp@ce!sK!ng) "
$FarmPass
if([string]::IsNullOrEmpty($FarmPass))
{
	$FarmPass = "R@ckSp@ce!sK!ng"
}
$AutoSPXML.Configuration.Farm.Passphrase = [string]$FarmPass

"<b>Farm Passphrase:</b> $FarmPass" | out-file "$text" -Append

if($Version -eq "2013")
{
    $AppDomain = Read-Host "What is the App Domain? (Leave blank if unknown...)"
    $AutoSPXML.Configuration.ServiceApps.AppManagementService.AppDomain = [string]$AppDomain

    "<b>App Domain:</b> $AppDomain" | out-file "$text" -Append

    $AppPrefix = Read-Host "What is the App Prefix? (Leave blank if unknown...)"
    $AutoSPXML.Configuration.ServiceApps.SubscriptionSettingsService.AppSiteSubscriptionName = [string]$AppPrefix

    "<b>App Prefix:</b> $AppPrefix" | out-file "$text" -Append
}

"" | out-file "$text" -Append

# Populate Server/Service Architecture
$numServers = Read-Host "How many servers are in this Farm? "

$wfe = ""
$apps = ""

for($i=1; $i -le $numServers; $i++)
{
    $serverName = Read-Host "What is the name of Server $i ? "   
    
    $Choice = ""
    Do
    {
        #Choose the edition of SharePoint 2010 you are installing
        Write-Host -ForegroundColor Yellow "Choose a Role for server $serverName "
        Write-Host -ForegroundColor Cyan "1. Web Front-End" 
        Write-Host -ForegroundColor Cyan "2. Application"
        Write-Host -ForegroundColor Cyan "3. Index"
        Write-Host -ForegroundColor Cyan "4. Query"
        Write-Host -ForegroundColor Cyan "5. Database"
        Write-Host -ForegroundColor Cyan "6. Central Administration (Only Choose this Role for one server)"
        Write-Host -ForegroundColor Cyan "7. Search Administration (Only Choose this Role for one server)"
        Write-Host -ForegroundColor Cyan "8. User Profile Sync (Only Choose this Role for one server)"
        Write-Host -ForegroundColor Cyan "9. Done adding Roles"
        Write-Host -ForegroundColor Cyan " "
        $Choice = Read-Host "Select 1-9: "
        
        switch($Choice)
        {
            1 { 
                    if($wfe -eq ""){$wfe = $serverName}
                    else{$wfe = $wfe + ", " + $serverName}
                    
              }
            2 {
                    if($apps -eq ""){$apps = $serverName}
                    else{$apps = $apps + ", " + $serverName}
                    
                    $CurrBCSServers = $AutoSPXML.Configuration.ServiceApps.BusinessDataConnectivity.Provision
                    if($CurrBCSServers -eq ""){$NewBCSServers = $serverName}
                    else{$NewBCSServers = $CurrBCSServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.BusinessDataConnectivity.SetAttribute("Provision", $NewBCSServers)

                    $CurrMMDataServers = $AutoSPXML.Configuration.ServiceApps.ManagedMetadataServiceApp.Provision
                    if($CurrMMDataServers -eq ""){$NewMMDataServers = $serverName}
                    else{$NewMMDataServers = $CurrMMDataServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.ManagedMetadataServiceApp.SetAttribute("Provision", $NewMMDataServers)
                    
                    $CurrWordServers = $AutoSPXML.Configuration.ServiceApps.WordAutomationService.Provision
                    if($CurrWordServers -eq ""){$NewWordServers = $serverName}
                    else{$NewWordServers = $CurrWordServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.WordAutomationService.SetAttribute("Provision", $NewWordServers)
                    
                    $CurrAppMgmtServers = $AutoSPXML.Configuration.ServiceApps.AppManagementService.Provision
                    if($CurrAppMgmtServers -eq ""){$NewAppMgmtServers = $serverName}
                    else{$NewAppMgmtServers = $CurrAppMgmtServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.AppManagementService.SetAttribute("Provision", $NewAppMgmtServers)

                    $CurrSubscServers = $AutoSPXML.Configuration.ServiceApps.SubscriptionSettingsService.Provision
                    if($CurrSubscServers -eq ""){$NewSubscServers = $serverName}
                    else{$NewSubscServers = $CurrSubscServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.SubscriptionSettingsService.SetAttribute("Provision", $NewSubscServers)

                    $CurrWorkMgmtServers = $AutoSPXML.Configuration.ServiceApps.WorkManagementService.Provision
                    if($CurrWorkMgmtServers -eq ""){$NewWorkMgmtServers = $serverName}
                    else{$NewWorkMgmtServers = $CurrWorkMgmtServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.WorkManagementService.SetAttribute("Provision", $NewWorkMgmtServers)

                    $CurrMTransServers = $AutoSPXML.Configuration.ServiceApps.MachineTranslationService.Provision
                    if($CurrMTransServers -eq ""){$NewMTransServers = $serverName}
                    else{$NewMTransServers = $CurrMTransServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.MachineTranslationService.SetAttribute("Provision", $NewMTransServers)

                    $CurrPPTServers = $AutoSPXML.Configuration.ServiceApps.PowerPointConversionService.Provision
                    if($CurrPPTServers -eq ""){$NewPPTServers = $serverName}
                    else{$NewPPTServers = $CurrPPTServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.PowerPointConversionService.SetAttribute("Provision", $NewPPTServers)

                    $CurrSStoreServers = $AutoSPXML.Configuration.ServiceApps.SecureStoreService.Provision
                    if($CurrSStoreServers -eq ""){$NewSStoreServers = $serverName}
                    else{$NewSStoreServers = $CurrSStoreServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.SecureStoreService.SetAttribute("Provision", $NewSStoreServers)

                    $CurrUsageServers = $AutoSPXML.Configuration.ServiceApps.SPUsageService.Provision
                    if($CurrUsageServers -eq ""){$NewUsageServers = $serverName}
                    else{$NewUsageServers = $CurrUsageServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.SPUsageService.SetAttribute("Provision", $NewUsageServers)

                    $CurrWebAnalyticsServers = $AutoSPXML.Configuration.ServiceApps.WebAnalyticsService.Provision
                    if($CurrWebAnalyticsServers -eq ""){$NewWebAnalyticsServers = $serverName}
                    else{$NewWebAnalyticsServers = $CurrWebAnalyticsServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.WebAnalyticsService.SetAttribute("Provision", $NewWebAnalyticsServers)

                    $CurrStateServers = $AutoSPXML.Configuration.ServiceApps.StateService.Provision
                    if($CurrStateServers -eq ""){$NewStateServers = $serverName}
                    else{$NewStateServers = $CurrStateServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.StateService.SetAttribute("Provision", $NewStateServers)

                    $CurrExcelServers = $AutoSPXML.Configuration.EnterpriseServiceApps.ExcelServices.Provision
                    if($CurrExcelServers -eq ""){$NewExcelServers = $serverName}
                    else{$NewExcelServers = $CurrExcelServers + " " + $serverName}
                    $AutoSPXML.Configuration.EnterpriseServiceApps.ExcelServices.SetAttribute("Provision", $NewExcelServers)

                    $CurrVisioServers = $AutoSPXML.Configuration.EnterpriseServiceApps.VisioService.Provision
                    if($CurrVisioServers -eq ""){$NewVisioServers = $serverName}
                    else{$NewVisioServers = $CurrVisioServers + " " + $serverName}
                    $AutoSPXML.Configuration.EnterpriseServiceApps.VisioService.SetAttribute("Provision", $NewVisioServers)

                    $AccessNode = $AutoSPXML.Configuration.EnterpriseServiceApps.AccessService | ?{$_.Name -eq "Access 2010 Services"}
                    $CurrAccessServers = $AccessNode.Provision
                    if($CurrAccessServers -eq ""){$NewAccessServers = $serverName}
                    else{$NewAccessServers = $CurrAccessServers + " " + $serverName}
                    $AccessNode.SetAttribute("Provision", $NewAccessServers)

                    $CurrPerformancePointServers = $AutoSPXML.Configuration.EnterpriseServiceApps.PerformancePointService.Provision
                    if($CurrPerformancePointServers -eq ""){$NewPerformancePointServers = $serverName}
                    else{$NewPerformancePointServers = $CurrPerformancePointServers + " " + $serverName}
                    $AutoSPXML.Configuration.EnterpriseServiceApps.PerformancePointService.SetAttribute("Provision", $NewPerformancePointServers)
              }
            3 {
                    $CurrCrawlServers = $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.CrawlComponent.Server.Name
                    if($CurrCrawlServers -eq ""){$NewCrawlServers = $serverName}
                    else{$NewCrawlServers = $CurrCrawlServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.CrawlComponent.Server.SetAttribute("Name", $NewCrawlServers)

                    $CurrIndexServers = $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.IndexComponent.Server.Name
                    if($CurrIndexServers -eq ""){$NewIndexServers = $serverName}
                    else{$NewIndexServers = $CurrIndexServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.IndexComponent.Server.SetAttribute("Name", $NewIndexServers)

                    $CurrContentServers = $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.ContentProcessingComponent.Server.Name
                    if($CurrContentServers -eq ""){$NewContentServers = $serverName}
                    else{$NewContentServers = $CurrContentServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.ContentProcessingComponent.Server.SetAttribute("Name", $NewContentServers)

                    $CurrAnalyticsServers = $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.AnalyticsProcessingComponent.Server.Name
                    if($CurrAnalyticsServers -eq ""){$NewAnalyticsServers = $serverName}
                    else{$NewAnalyticsServers = $CurrAnalyticsServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.AnalyticsProcessingComponent.Server.SetAttribute("Name", $NewAnalyticsServers)      
              }
            4 {
                    $CurrQueryServers = $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.QueryComponent.Server.Name
                    if($CurrQueryServers -eq ""){$NewQueryServers = $serverName}
                    else{$NewQueryServers = $CurrQueryServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.QueryComponent.Server.SetAttribute("Name", $NewQueryServers)

                    $CurrSQSSServers = $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.SearchQueryAndSiteSettingsServers.Server.Name
                    if($CurrSQSSServers -eq ""){$NewSQSSServers = $serverName}
                    else{$NewSQSSServers = $CurrSQSSServers + " " + $serverName}
                    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.SearchQueryAndSiteSettingsServers.Server.SetAttribute("Name", $NewSQSSServers)
              }
            5 {
					$FarmDBServerAlias = Read-Host "Enter an Alias for the SQL Server $serverName (Blank/Default = SharePointSQL) "
					if([string]::IsNullOrEmpty($FarmDBServerAlias))
					{
						$FarmDBServerAlias = "SharePointSQL"
					}
					$AutoSPXML.Configuration.Farm.Database.DBAlias.Create = "true"
                    $AutoSPXML.Configuration.Farm.Database.DBAlias.DBInstance = "$serverName"

                    $AutoSPXML.Configuration.Farm.Database.DBServer = "$FarmDBServerAlias"
              } 
            6 {
                    $AutoSPXML.Configuration.Farm.CentralAdmin.SetAttribute("Provision", $serverName)
              } 
            7 {
                    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.AdminComponent.Server.SetAttribute("Name", $serverName)
              } 
            8 {
                    $AutoSPXML.Configuration.ServiceApps.UserProfileServiceApp.SetAttribute("Provision", $serverName)
              }        
        }
        
        
    }
    while($Choice -ne "9")
}

"<b>Sharepoint Topology</b>" | out-file "$text" -Append
"------------------" | out-file "$text" -Append

"<b>WFE:</b> $wfe" | out-file "$text" -Append

"<b>Application:</b> $Apps" | out-file "$text" -Append
    
$ca = $AutoSPXML.Configuration.Farm.CentralAdmin.Provision
"<b>Central Admin:</b> $ca" | out-file "$text" -Append

$indexCrawl = $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.IndexComponent.Server.Name
$indexScrubbed = $indexCrawl.Replace(" ", ", ")
"<b>Index Crawler:</b> $indexScrubbed" | out-file "$text" -Append

$query = $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.QueryComponent.Server.Name
$queryScrubbed = $query.Replace(" ", ", ")
"<b>Query:</b> $queryScrubbed" | out-file "$text" -Append

$dbServer = $AutoSPXML.Configuration.Farm.Database.DBAlias.DBInstance
"<b>Database:</b> $dbServer" | out-file "$text" -Append

$dbAlias = $AutoSPXML.Configuration.Farm.Database.DBServer
"<b>SQL Alias:</b> $dbAlias" | out-file "$text" -Append

"" | out-file "$text" -Append

"<b>Install Ticket:</b> $ticketNum" | out-file "$text" -Append

"" | out-file "$text" -Append

#End Region Get Input Variables 
$AutoSPXML.Save("$env:AutoSPPath\AutoSPInstallerInput.xml")