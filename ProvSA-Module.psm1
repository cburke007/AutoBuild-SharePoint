#Region Get NetBios name for current domain
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
#EndRegion

#Region Get PSCred
function GetPSCred
{   
	param([string]$ServiceAcctName, $ServiceAcctPass)
	
	#Get PSCred object for the given Account 	
	$SecurePWD = ConvertTo-SecureString "$ServiceAcctPass" -asplaintext -force
	$cred_ServiceAcct = New-Object System.Management.Automation.PsCredential $ServiceAcctName, $SecurePWD
	$cred_ServiceAcct
}
#EndRegion

#Region Set Managed Accounts
function Set-ManagedAcct
{
	param([string]$appPoolAcct, [string]$appPoolPass)
	
	$credServAcct = GetPSCred $appPoolAcct $appPoolPass

	## Add Managed Account for Services App Pool Account
    $ManagedAccountGen = Get-SPManagedAccount | Where-Object {$_.UserName -eq "$appPoolAcct"}
    If ($ManagedAccountGen -eq $NULL) 
    { 
    	Write-Host -ForegroundColor Cyan "- Registering managed account" $appPoolAcct
    	New-SPManagedAccount -Credential $credServAcct | Out-Null 
    }
    Else {Write-Host -ForegroundColor Cyan "- Managed account "$appPoolAcct" already exists, continuing."}
}
#EndRegion
   
#Region Create App Pool
function CreateSAAppPool
{
	param([string]$appPoolName, [string]$appPoolUser)
	
	#Test/Create Service Application App Pool
	Write-Host -ForegroundColor Cyan "- Getting Hosted Services Application Pool, creating if necessary..."
	$saAppPool = Get-SPServiceApplicationPool "$appPoolName" -ea SilentlyContinue
	if($saAppPool -eq $null)
	{ 
	    $saAppPool = New-SPServiceApplicationPool "$appPoolName" -account $appPoolUser
	    If (-not $?) { throw "Failed to create an application pool" }
	}
	
	$saAppPool
}       
#EndRegion

#Region Create BCS Service App
function New-BCSApp
{
    param([string]$saName, [string]$appPoolName, [string]$dbServer, [string]$dbName, [string]$saAppPoolUser, [string]$saAppPoolPass)
		
	if((Get-SPServiceApplication | ?{$_.Name -eq $saName}) -eq $null)
	{	
		$netbios = (Get-LocalLogonInformation).DomainShortName	
		$domSAAppPoolUser ="$netbios\$saAppPoolUser" 
		#Check/Create Managed Account
		Set-ManagedAcct $domSAAppPoolUser $saAppPoolPass
		#Create SA AppPool
		$saAppPool = CreateSAAppPool $appPoolName $domSAAppPoolUser
	
		Write-Host -ForegroundColor Cyan "Creating BCS Service App and Proxy..."
		
	    New-SPBusinessDataCatalogServiceApplication -Name $saName -ApplicationPool $saAppPool -DatabaseServer $dbServer -DatabaseName "$dbName" > $null
    }
	else{Write-Host -ForegroundColor Cyan "- $saName already exists. Continuing..."}	
}
#EndRegion

#Region Create Metadata Service Application
function New-MMDataApp
{		
	param([string]$saName, [string]$appPoolName, [string]$dbServer, [string]$dbName, [string]$saAppPoolUser, [string]$saAppPoolPass, [string]$farmAcct)
	
	$FarmConfigXML = [xml](get-content "$curloc\FarmConfig.xml" -EA 0)
	
	try
	{ 
		## Create a Metadata Service Application
		If((Get-SPServiceApplication | ?{$_.Name -eq $saName}) -eq $null)
	  	{   		           
			$netbios = (Get-LocalLogonInformation).DomainShortName	
			$domSAAppPoolUser = "$netbios\$saAppPoolUser" 
			$domFarmAcct = "$netbios\$farmAcct"
			#Check/Create Managed Account
			Set-ManagedAcct $domSAAppPoolUser $saAppPoolPass
			#Create SA AppPool
			$saAppPool = CreateSAAppPool $appPoolName $domSAAppPoolUser
			
			## Create Service App
   			Write-Host -ForegroundColor Cyan " - Creating Metadata Service Application..."
            $MetaDataServiceApp  = New-SPMetadataServiceApplication -Name $saName -ApplicationPool $saAppPool -DatabaseServer $dbServer -DatabaseName $dbName -AdministratorAccount $domFarmAcct -FullAccessAccount $domFarmAcct
            If (-not $?) { throw "- Failed to create $saName" }

            ## create proxy
			Write-Host -ForegroundColor Cyan " - Creating Metadata Service Application Proxy..."
            $MetaDataServiceAppProxy  = New-SPMetadataServiceApplicationProxy -Name "$saName Proxy" -ServiceApplication $MetaDataServiceApp -DefaultProxyGroup
            If (-not $?) { throw "- Failed to create $saName" }
            
			
			foreach($spAppPoolAcct in $spAppPoolAccts)
			{
				$apAcctName = $spAppPoolAcct.Name
				$domAPAcct = "$netbios\$apAcctName"
				$spAppPoolAccts = $FarmConfigXML.Customer.Farm.FarmAccounts.Account | ? {$_.Type -like "* Site AppPool"}
				
				#Write-Host -ForegroundColor Cyan " - Granting rights to Metadata Service Application..."
				# Get ID of "Managed Metadata Service"
				$MetadataServiceAppToSecure = Get-SPServiceApplication | ?{$_.Name -eq $saName}
				$MetadataServiceAppIDToSecure = $MetadataServiceAppToSecure.Id
				# Create a variable that contains the list of administrators for the service application 
				$MetadataServiceAppSecurity = Get-SPServiceApplicationSecurity $MetadataServiceAppIDToSecure										
				# Create a variable that contains the claims principal for app pool and farm user accounts
				$FarmSiteAPPrincipal = New-SPClaimsPrincipal -Identity $domAPAcct -IdentityType WindowsSamAccountName
				# Give permissions to the claims principal you just created
				Grant-SPObjectSecurity $MetadataServiceAppSecurity -Principal $FarmSiteAPPrincipal -Rights "Full Access to Term Store"
				# Apply the changes to the Metadata Service application
				Set-SPServiceApplicationSecurity $MetadataServiceAppToSecure -ObjectSecurity $MetadataServiceAppSecurity
			}
            
			Write-Host -ForegroundColor Cyan "- Done creating $saName."
      	}
	  	Else {Write-Host -ForegroundColor Cyan "- $saName already exists. Continuing..."}
	}
	catch
	{
		Write-Output $_ 
	}
}
#EndRegion

#Region Create User Profile Service Application
function New-UserProfileApp
{
	param([string]$saName, [string]$appPoolName, [string]$saAppPoolUser, [string]$saAppPoolPass, [string]$farmAcct, [string]$ProfileDB, [string]$ProfileDBServer, [string]$SyncDB, [string]$SyncDBServer, [string]$SocialDB, [string]$SocialDBServer)
			
	try
	{
		## Create a Profile Service Application
      	If ((Get-SPServiceApplication | ? {$_.GetType().ToString() -eq "Microsoft.Office.Server.Administration.UserProfileApplication"}) -eq $null)
	  	{   
            $netbios = (Get-LocalLogonInformation).DomainShortName	
			$domSAAppPoolUser = "$netbios\$saAppPoolUser"
			$domFarmAcct = "$netbios\$farmAcct"
			#Check/Create Managed Account
			Set-ManagedAcct $domSAAppPoolUser $saAppPoolPass
			#Create SA AppPool
			$saAppPool = CreateSAAppPool $appPoolName $domSAAppPoolUser
						
			## Create Service App
			Write-Host -ForegroundColor Cyan " - Creating $saName..."
            #$ProfileServiceApp  = New-SPProfileServiceApplication -Name "$saName" -ApplicationPool $saAppPool -ProfileDBName $ProfileDB -ProfileSyncDBName $SyncDB -SocialDBName $SocialDB -SyncInstanceMachine $env:COMPUTERNAME -MySiteHostLocation "$MySiteURL`:$MySitePort"
           	$ProfileServiceApp  = New-SPProfileServiceApplication -Name "$saName" -ApplicationPool $saAppPool -ProfileDBServer $ProfileDBServer -ProfileDBName $ProfileDB -ProfileSyncDBServer $SyncDBServer -ProfileSyncDBName $SyncDB -SocialDBServer $SocialDBServer -SocialDBName $SocialDB
           	If (-not $?) { throw " - Failed to create $saName" }
                    
            ## Create Proxy
			Write-Host -ForegroundColor Cyan " - Creating $saName Proxy..."
            $ProfileServiceAppProxy  = New-SPProfileServiceApplicationProxy -Name "$saName Proxy" -ServiceApplication $ProfileServiceApp -DefaultProxyGroup
            If (-not $?) { throw " - Failed to create $saName Proxy" }
			
			## Get ID of $saName
			Write-Host -ForegroundColor Cyan " - Get ID of $saName..."
			$ProfileServiceAppToSecure = Get-SPServiceApplication |?{$_.Name -eq $saName}
			$ProfileServiceAppIDToSecure = $ProfileServiceAppToSecure.Id

			Write-Host -ForegroundColor Cyan " - Granting rights to $saName..."
			## Create a variable that contains the guid for the User Profile service for which you want to delegate Full Control
			$serviceapp = Get-SPServiceApplication $ProfileServiceAppIDToSecure

			## Create a variable that contains the list of administrators for the service application 
			$ProfileServiceAppSecurity = Get-SPServiceApplicationSecurity $serviceapp -Admin

			## Create a variable that contains the claims principal for app pool and farm user accounts
			$FarmSiteAPPrincipal = New-SPClaimsPrincipal -Identity $domSAAppPoolUser -IdentityType WindowsSamAccountName
			$FarmAcctPrincipal =  New-SPClaimsPrincipal -Identity $domFarmAcct -IdentityType WindowsSamAccountName

			## Give Full Control permissions to the claims principal you just created, and the Farm Account
			Grant-SPObjectSecurity $ProfileServiceAppSecurity -Principal $FarmSiteAPPrincipal -Rights "Full Control"
			Grant-SPObjectSecurity $ProfileServiceAppSecurity -Principal $FarmAcctPrincipal -Rights "Full Control"

			## Apply the changes to the User Profile service application
			Set-SPServiceApplicationSecurity $serviceapp -objectSecurity $ProfileServiceAppSecurity -Admin
						
			Write-Host -ForegroundColor Cyan "- Done creating $saName."
			
			$ProfileServiceApp = Get-SPServiceApplication |?{$_.Name -eq $saName}
			If ($ProfileServiceApp)
			{
				Write-Host -ForegroundColor Cyan "- Fixing SQL ownership for profile database: $DBServer\$ProfileDB..."
  		        $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
            	$sqlCmd.CommandType = "Text"
            	#$sqlCmd.CommandText = "ALTER USER [$domFarmAcct]  WITH DEFAULT_SCHEMA=dbo;"
				$SqlCmd.CommandText = "exec sp_dropuser `'$domFarmAcct`'; exec sp_changedbowner `'$domFarmAcct`';"
            	$connString = "Integrated Security=SSPI;Persist Security Info=False;Data Source=$dbServer;Initial Catalog=$ProfileDB;"
            	$connection = New-Object System.Data.SqlClient.SqlConnection($connString)
            	try 
				{
                   	$connection.Open()
                   	$sqlCmd.Connection = $connection
                  	$sqlCmd.ExecuteNonQuery()
            	}                         
            	catch 
				{
            			Write-Output $_
            	}
            	finally 
				{
                   $connection.Dispose()
            	}
			}      		
      	}
	  	Else {Write-Host -ForegroundColor Cyan "- $saName already exists. Continuing..."}		
	}
	catch
    {
        Write-Output $_ 
    }
	 
}
#EndRegion

#Region Create State Service App
function New-StateServiceApp
{
	param([string]$saName, [string]$dbName)
	
	try
	{
		$GetSPStateServiceApplication = Get-SPStateServiceApplication
		If ($GetSPStateServiceApplication -eq $Null)
		{			
			Write-Host -ForegroundColor Cyan "- Creating $saName..."
			New-SPStateServiceDatabase -Name $dbName | Out-Null
			New-SPStateServiceApplication -Name $saName -Database $dbName | Out-Null
			Get-SPStateServiceDatabase | Initialize-SPStateServiceDatabase | Out-Null
			Write-Host -ForegroundColor Cyan " - Creating $saName Proxy..."
			Get-SPStateServiceApplication | New-SPStateServiceApplicationProxy -Name "$saName Proxy" -DefaultProxyGroup | Out-Null
			Write-Host -ForegroundColor Cyan "- Done creating $saName."
		}
		Else {Write-Host -ForegroundColor Cyan "- $saName exists, continuing..."}
	}
catch
	{
		Write-Output $_
	}
}
#EndRegion

#Region Create WSS Usage Application
function New-UsageApp
{
	param([string]$saName, [string]$dbServer, [string]$dbName)
	
	try
	{		
		If ((Get-SPServiceApplication | ?{$_.Name -eq $saName}) -eq $null)
		{
			Write-Host -ForegroundColor Cyan "- Creating $saName..."
			New-SPUsageApplication -Name $saName -DatabaseServer $dbServer -DatabaseName $dbName > $null
            $up = get-spserviceapplicationproxy | where {$_.DisplayName -eq "$saName"}
            $up.provision()
			Write-Host -ForegroundColor Cyan "- Done Creating WSS Usage Application."
		}
		Else {Write-Host -ForegroundColor Cyan "- $saName exists, continuing..."}
	}
	catch
	{
		Write-Output $_
	}
}
#EndRegion

#Region Create Secure Store Service Application
function New-SecureStoreApp
{
	param([string]$saName, [string]$appPoolName, [string]$dbServer, [string]$dbName, [string]$saAppPoolUser, [string]$saAppPoolPass, [string]$farmPassPhrase)
	
	try
	{
        $netbios = (Get-LocalLogonInformation).DomainShortName	
		$domSAAppPoolUser = "$netbios\$saAppPoolUser" 
		$domFarmAcct = "$netbios\$farmAcct"
		#Check/Create Managed Account
		Set-ManagedAcct $domSAAppPoolUser $saAppPoolPass
		#Create SA AppPool
		$saAppPool = CreateSAAppPool $appPoolName $domSAAppPoolUser
		
		$GetSPSecureStoreServiceApplication = Get-SPServiceApplication | ?{$_.Name -eq $saName}
		If ($GetSPSecureStoreServiceApplication -eq $Null)
		{
			Write-Host -ForegroundColor Cyan " - $saName..."
			New-SPSecureStoreServiceApplication -Name "$saName" -PartitionMode:$false -Sharing:$false -DatabaseName $dbName -ApplicationPool $saAppPool -AuditingEnabled:$true -AuditLogMaxSize 30 | Out-Null
			Write-Host -ForegroundColor Cyan " - $saName Proxy..."
			Get-SPServiceApplication | ?{$_.Name -eq $saName} | New-SPSecureStoreServiceApplicationProxy -Name "$saName Proxy" -DefaultProxyGroup | Out-Null
			Write-Host -ForegroundColor Cyan " - Done creating $saName."			
			
			#Create Secure Store Master Key
			$secureStore = Get-SPServiceApplicationProxy | ?{$_.Name -eq "$saName Proxy"} 
			Write-Host -ForegroundColor Cyan " - Creating the Master Key..."
			Update-SPSecureStoreMasterKey -ServiceApplicationProxy $secureStore.Id -Passphrase "$farmPassPhrase"
			Start-Sleep -s 5
			Write-Host -ForegroundColor Cyan " - Creating the Application Key..."
			Update-SPSecureStoreApplicationServerKey -ServiceApplicationProxy $secureStore.Id -Passphrase "$farmPassPhrase" -ErrorAction SilentlyContinue
			If (!$?)
			{
				## Try again...
			    Start-Sleep -s 5
				Write-Host -ForegroundColor Cyan " - Creating the Application Key (2nd attempt)..."
				Update-SPSecureStoreApplicationServerKey -ServiceApplicationProxy $secureStore.Id -Passphrase "$farmPassPhrase"
			}
			
		}
		Else {Write-Host -ForegroundColor Cyan " - $saName exists, continuing..."}
	}
catch
	{
		Write-Output $_
	}
	Write-Host -ForegroundColor Cyan "- Done creating/configuring Secure Store Service."    
}
#EndRegion

#Region WebAnalytics
function New-WebAnalyticsApp
{
	param([string]$saName, [string]$appPoolName, [string]$whdbServer, [string]$whdbName, [string]$stagedbServer, [string]$stagedbName, [string]$saAppPoolUser, [string]$saAppPoolPass)
	
	$netbios = (Get-LocalLogonInformation).DomainShortName	
	$domSAAppPoolUser = "$netbios\$saAppPoolUser" 
	$domFarmAcct = "$netbios\$farmAcct"
	#Check/Create Managed Account
	Set-ManagedAcct $domSAAppPoolUser $saAppPoolPass
	#Create SA AppPool
	$saAppPool = CreateSAAppPool $appPoolName $domSAAppPoolUser
	
	$GetSPSecureStoreServiceApplication = Get-SPServiceApplication | ?{$_.Name -eq $saName}
	If ($GetSPSecureStoreServiceApplication -eq $Null)
	{
		Write-Host -ForegroundColor Cyan "Creating $saName and Proxy..."
		$stagerSubscription = "<StagingDatabases><StagingDatabase ServerName='$stagedbServer' DatabaseName='$stagedbName'/></StagingDatabases>"
	    $reportingSubscription = "<ReportingDatabases><ReportingDatabase ServerName='$whdbServer' DatabaseName='$whdbName'/></ReportingDatabases>"
	    New-SPWebAnalyticsServiceApplication -Name $saName -ApplicationPool $saAppPool -ReportingDataRetention 20 -SamplingRate 100 -ListOfReportingDatabases $reportingSubscription -ListOfStagingDatabases $stagerSubscription > $null 
		New-SPWebAnalyticsServiceApplicationProxy -Name "$saName Proxy" -ServiceApplication $saName > $null	 
	}
	else{Write-Host -ForegroundColor Cyan "- $saName already exists. Continuing..."}
}
#EndRegion

#Region Visio
function New-VisioApp
{               
    param([string]$saName, [string]$appPoolName, [string]$saAppPoolUser, [string]$saAppPoolPass)
	
	$netbios = (Get-LocalLogonInformation).DomainShortName	
	$domSAAppPoolUser = "$netbios\$saAppPoolUser" 
	$domFarmAcct = "$netbios\$farmAcct"
	#Check/Create Managed Account
	Set-ManagedAcct $domSAAppPoolUser $saAppPoolPass
	#Create SA AppPool
	$saAppPool = CreateSAAppPool $appPoolName $domSAAppPoolUser
	
	$GetSPSecureStoreServiceApplication = Get-SPServiceApplication | ?{$_.Name -eq $saName}
	If ($GetSPSecureStoreServiceApplication -eq $Null)
	{
		Write-Host -ForegroundColor Cyan "Creating $saName and Proxy..."
	    New-SPVisioServiceApplication -Name $saName -ApplicationPool $saAppPool -AddToDefaultGroup > $null
	    New-SPVisioServiceApplicationProxy -Name "$saName Proxy" -ServiceApplication $saName > $null
	}
	else{Write-Host -ForegroundColor Cyan "- $saName already exists. Continuing..."}
}
#EndRegion

#Region PerfPoint
function New-PerfPointApp
{  
    param([string]$saName, [string]$appPoolName, [string]$saAppPoolUser, [string]$saAppPoolPass)
	
	$netbios = (Get-LocalLogonInformation).DomainShortName	
	$domSAAppPoolUser = "$netbios\$saAppPoolUser" 
	$domFarmAcct = "$netbios\$farmAcct"
	#Check/Create Managed Account
	Set-ManagedAcct $domSAAppPoolUser $saAppPoolPass
	#Create SA AppPool
	$saAppPool = CreateSAAppPool $appPoolName $domSAAppPoolUser
	
	$GetSPSecureStoreServiceApplication = Get-SPServiceApplication | ?{$_.Name -eq $saName}
	If ($GetSPSecureStoreServiceApplication -eq $Null)
	{
		Write-Host -ForegroundColor Cyan "Creating Performance Point Service and Proxy..."
	    New-SPPerformancePointServiceApplication -Name $saName -ApplicationPool $saAppPool > $null
	    New-SPPerformancePointServiceApplicationProxy -Default -Name "$saName Proxy" -ServiceApplication $saName > $null
	}
	else{Write-Host -ForegroundColor Cyan "- $saName already exists. Continuing..."}
}
#EndRegion

#Region Access
function New-AccessApp
{
	param([string]$saName, [string]$appPoolName, [string]$saAppPoolUser, [string]$saAppPoolPass)
	
	$netbios = (Get-LocalLogonInformation).DomainShortName	
	$domSAAppPoolUser = "$netbios\$saAppPoolUser" 
	$domFarmAcct = "$netbios\$farmAcct"
	#Check/Create Managed Account
	Set-ManagedAcct $domSAAppPoolUser $saAppPoolPass
	#Create SA AppPool
	$saAppPool = CreateSAAppPool $appPoolName $domSAAppPoolUser
	
	$GetSPSecureStoreServiceApplication = Get-SPServiceApplication | ?{$_.Name -eq $saName}
	If ($GetSPSecureStoreServiceApplication -eq $Null)
	{
		Write-Host -ForegroundColor Cyan "Creating $saName and Proxy..."
	    New-SPAccessServiceApplication -Name $saName -ApplicationPool $saAppPool -Default > $null
	}
	else{Write-Host -ForegroundColor Cyan "- $saName already exists. Continuing..."}
}
#EndRegion

#Region Excel
function New-ExcelApp
{
	param([string]$saName, [string]$appPoolName, [string]$saAppPoolUser, [string]$saAppPoolPass)
	
	$netbios = (Get-LocalLogonInformation).DomainShortName	
	$domSAAppPoolUser = "$netbios\$saAppPoolUser" 
	$domFarmAcct = "$netbios\$farmAcct"
	#Check/Create Managed Account
	Set-ManagedAcct $domSAAppPoolUser $saAppPoolPass
	#Create SA AppPool
	$saAppPool = CreateSAAppPool $appPoolName $domSAAppPoolUser
	
	$GetSPSecureStoreServiceApplication = Get-SPServiceApplication | ?{$_.Name -eq $saName}
	If ($GetSPSecureStoreServiceApplication -eq $Null)
	{
		Write-Host -ForegroundColor Cyan "Creating $saName and Proxy..."
	    New-SPExcelServiceApplication -name $saName –ApplicationPool $saAppPool -Default > $null
	    Set-SPExcelFileLocation -Identity "http://" -ExcelServiceApplication $saName -ExternalDataAllowed 2 -WorkbookSizeMax 10 -WarnOnDataRefresh:$true
	}
	else{Write-Host -ForegroundColor Cyan "- $saName already exists. Continuing..."}
}
#EndRegion

#Region Word
function New-WordApp
{
	param([string]$saName, [string]$appPoolName, [string]$dbServer, [string]$dbName, [string]$saAppPoolUser, [string]$saAppPoolPass)
	
	$netbios = (Get-LocalLogonInformation).DomainShortName	
	$domSAAppPoolUser = "$netbios\$saAppPoolUser" 
	$domFarmAcct = "$netbios\$farmAcct"
	#Check/Create Managed Account
	Set-ManagedAcct $domSAAppPoolUser $saAppPoolPass
	#Create SA AppPool
	$saAppPool = CreateSAAppPool $appPoolName $domSAAppPoolUser
	
	$GetSPSecureStoreServiceApplication = Get-SPServiceApplication | ?{$_.Name -eq $saName}
	If ($GetSPSecureStoreServiceApplication -eq $Null)
	{
		Write-Host -ForegroundColor Cyan "Creating $saName and Proxy..."
	    New-SPWordConversionServiceApplication -Name $saName -ApplicationPool $saAppPool -DatabaseServer $dbServer -DatabaseName "$dbName" -Default > $null
	}
	else{Write-Host -ForegroundColor Cyan "- $saName already exists. Continuing..."}
}
#EndRegion

#Region Setup Enterprise Search
function New-EnterpriseSearchApp
{ 
	param([string]$saName, [string]$appPoolName, [string]$dbServer, [string]$dbName, [string]$saAppPoolUser, [string]$saAppPoolPass, [string]$searchServer)
		
	if((Get-SPServiceApplication | ?{$_.Name -eq $saName}) -eq $null)
	{
		$netbios = (Get-LocalLogonInformation).DomainShortName	
		$domSAAppPoolUser = "$netbios\$saAppPoolUser" 
		$domFarmAcct = "$netbios\$farmAcct"
		#Check/Create Managed Account
		Set-ManagedAcct $domSAAppPoolUser $saAppPoolPass
		#Create SA AppPool
		$saAppPool = CreateSAAppPool $appPoolName $domSAAppPoolUser
		
		Write-Host -ForegroundColor Cyan "Creating $saName and Proxy..."
	    
	    Start-SPEnterpriseSearchServiceInstance $searchServer
	    Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance $searchServer
	     
	    Write-Host -ForegroundColor Cyan "  Creating Search Application..."
	    $searchApp = New-SPEnterpriseSearchServiceApplication -Name $saName -ApplicationPool $saAppPool -DatabaseServer $dbServer -DatabaseName "$dbName"
	    $searchInstance = Get-SPEnterpriseSearchServiceInstance $searchServer
	     
	    Write-Host -ForegroundColor Cyan "  Creating Administration Component..."
	    $searchApp | Get-SPEnterpriseSearchAdministrationComponent | Set-SPEnterpriseSearchAdministrationComponent -SearchServiceInstance $searchInstance     
	    
		##Crawl
		Write-Host -ForegroundColor Cyan "  Creating Crawl Component..."
		$InitialCrawlTopology = $searchApp | Get-SPEnterpriseSearchCrawlTopology -Active
		$CrawlTopology = $searchApp | New-SPEnterpriseSearchCrawlTopology
		$CrawlDatabase = ([array]($searchApp | Get-SPEnterpriseSearchCrawlDatabase))[0]
		$CrawlComponent = New-SPEnterpriseSearchCrawlComponent -CrawlTopology $CrawlTopology -CrawlDatabase $CrawlDatabase -SearchServiceInstance $searchInstance
		$CrawlTopology | Set-SPEnterpriseSearchCrawlTopology -Active
		 
		Write-Host -ForegroundColor Cyan "  Waiting for the old crawl topology to become inactive" -NoNewline
		do {write-host -NoNewline .;Start-Sleep 6;} while ($InitialCrawlTopology.State -ne "Inactive")
		$InitialCrawlTopology | Remove-SPEnterpriseSearchCrawlTopology -Confirm:$false
		Write-Host
				  
		##Query
		Write-Host -ForegroundColor Cyan "  Creating Query Component..."
		$InitialQueryTopology = $searchApp | Get-SPEnterpriseSearchQueryTopology -Active
		$QueryTopology = $searchApp | New-SPEnterpriseSearchQueryTopology -Partitions 1
		$IndexPartition= (Get-SPEnterpriseSearchIndexPartition -QueryTopology $QueryTopology)
		$QueryComponent = New-SPEnterpriseSearchQuerycomponent -QueryTopology $QueryTopology -IndexPartition $IndexPartition -SearchServiceInstance $searchInstance
		$PropertyDatabase = ([array]($searchApp | Get-SPEnterpriseSearchPropertyDatabase))[0]
		$IndexPartition | Set-SPEnterpriseSearchIndexPartition -PropertyDatabase $PropertyDatabase
		$QueryTopology | Set-SPEnterpriseSearchQueryTopology -Active
		
	    Write-Host -ForegroundColor Cyan "  Creating Proxy..."
	    $searchAppProxy = New-SPEnterpriseSearchServiceApplicationProxy -Name "$saName Proxy" -SearchApplication $saName > $null	    		
	}
}
#EndRegion
          

#Export Module Members
Export-ModuleMember New-BCSApp,New-MMDataApp,New-UserProfileApp,New-StateServiceApp,New-UsageApp,New-SecureStoreApp,New-WebAnalyticsApp,New-VisioApp,New-PerfPointApp,New-AccessApp,New-ExcelApp,New-WordApp,New-EnterpriseSearchApp,Set-ManagedAcct
