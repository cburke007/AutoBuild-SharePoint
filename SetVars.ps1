Import-Module ./AutoBuild-Module

# Get current script execution path
[string]$curloc = get-location

[xml]$FarmConfigXML = '<?xml version="1.0" encoding="UTF-8"?>
    <Customer>
    <Farm>
    <FarmAccounts></FarmAccounts>
    <WebApplications></WebApplications>
    <FarmSolutions></FarmSolutions>
    <FarmServices></FarmServices>
    <FarmServiceApplications></FarmServiceApplications>
    <FarmServers></FarmServers>
    </Farm>        
    </Customer>    
    '
# Version of SharePoint
Write-Host -ForegroundColor Cyan "What version of SharePoint is being installed? "
Write-Host -ForegroundColor Cyan "1. SharePoint 2010"
Write-Host -ForegroundColor Cyan "2. SharePoint 2013"

$VerChoice = Read-Host "Select 1 or 2: "

switch($VerChoice)
{
    1 {$Version = "14"}
    2 {$Version = "15"}
    default {$Version = "14"}
}

$FarmConfigXML.Customer.Farm.SetAttribute("BuildVersion", $Version)

#Choose the edition of SharePoint 2010 you are installing
Write-Host -ForegroundColor Cyan "Choose your version (Default == Foundation)"
Write-Host -ForegroundColor Cyan "1. Foundation"
Write-Host -ForegroundColor Cyan "2. SearchServer"
Write-Host -ForegroundColor Cyan "3. Standard"
Write-Host -ForegroundColor Cyan "4. Standard + Internet"
Write-Host -ForegroundColor Cyan "5. Enterprise"
Write-Host -ForegroundColor Cyan "6. Enterprise + Internet"
Write-Host -ForegroundColor Cyan " "
$EdChoice = Read-Host "Select 1-6: "

switch($EdChoice)
{
    1 {$Edition = "Foundation"}
    2 {$Edition = "Search Server 2010"}
    3 {$Edition = "Standard"}
    4 {$Edition = "Standard Internet"}
    5 {$Edition = "Enterprise"}
    6 {$Edition = "Enterprise Internet"}
    default {$Edition = "Foundation"}
}

$FarmConfigXML.Customer.Farm.SetAttribute("LicenseLevel", $Edition)

 
$ProductKey = Read-Host "Enter the Product Installation Key (Leave Blank for Foundation/SSExpress)"
$FarmConfigXML.Customer.Farm.SetAttribute("ProductKey", $ProductKey)

$FarmPass = Read-Host "Enter the Passphrase to use for the Farm (Blank/Default = R@ckSp@ce!sK!ng) "
$FarmPass
if([string]::IsNullOrEmpty($FarmPass))
{
	$FarmPass = "R@ckSp@ce!sK!ng"
}
$FarmConfigXML.Customer.Farm.SetAttribute("Passphrase", $FarmPass)

# Populate Server/Service Architecture
$numServers = Read-Host "How many servers are in this Farm? "

for($i=1; $i -le $numServers; $i++)
{
    $serverName = Read-Host "What is the name of Server  $i ? "   
    
	function GetServerNode
	{
		param([string]$serverName, [xml]$FarmConfigXML)
		
		$serverNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmServers/Server[@Name='$serverName']")
	    
	    if($serverNode -eq $null)
	    {    
	        $serversNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmServers")
	        
	        # Create a new WebApplication Element and populate it with WebApplication Settings
	        $newServer = $FarmConfigXML.CreateElement("Server")
	        $newServer.SetAttribute("Name",$serverName)
	        
	        # Populate Web Application sub-elements   
	        $newElement = $FarmConfigXML.CreateElement("Services")
	        $newServer.AppendChild($newElement)
	        
	        
	        $serversNode.AppendChild($newServer)
	    }      		
    }
	
    $Choice = ""
    Do
    {
        #Choose the edition of SharePoint 2010 you are installing
        Write-Host -ForegroundColor Cyan "Choose a Role for server $serverName "
        Write-Host -ForegroundColor Cyan "1. Web Front-End"
        Write-Host -ForegroundColor Cyan "2. Central Administration"
        Write-Host -ForegroundColor Cyan "3. Application Server"
        Write-Host -ForegroundColor Cyan "4. Index Server"
        Write-Host -ForegroundColor Cyan "5. Query Server"
        Write-Host -ForegroundColor Cyan "6. Database"
        Write-Host -ForegroundColor Cyan "7. Done adding Roles"
        Write-Host -ForegroundColor Cyan " "
        $Choice = Read-Host "Select 1-6: "
        
        switch($Choice)
        {
            1 {                    
                    # Create a new Server Service Element and populate it with Name and Status
					$servicesNode = GetServerNode $serverName $FarmConfigXML
					$servicesNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmServers/Server[@Name='$serverName']/Services")
                    $newServiceNode = $FarmConfigXML.CreateElement("Service")
                    $newServiceNode.SetAttribute("Name","Microsoft SharePoint Foundation Incoming E-Mail")
                    $newServiceNode.SetAttribute("Status","Disabled")
                    $servicesNode.AppendChild($newServiceNode)
                    
                    
                    if ($EdChoice -ge 3)
                    {
                        # Create a new Server Service Element and populate it with Name and Status
                        $newServiceNode = $FarmConfigXML.CreateElement("Service")
                        $newServiceNode.SetAttribute("Name","Microsoft SharePoint Foundation Sandboxed Code Service")
                        $newServiceNode.SetAttribute("Status","Online")
                        $servicesNode.AppendChild($newServiceNode)
                        
                    }
              }
            2 {
                    $servicesNode = GetServerNode $serverName $FarmConfigXML
					$servicesNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmServers/Server[@Name='$serverName']/Services")
					# Create a new Server Service Element and populate it with Name and Status
                    $newServiceNode = $FarmConfigXML.CreateElement("Service")
                    $newServiceNode.SetAttribute("Name","Central Administration")
                    $newServiceNode.SetAttribute("Status","Online")
                    $servicesNode.AppendChild($newServiceNode)
                    
            
              }
            3 {
                    $servicesNode = GetServerNode $serverName $FarmConfigXML
					$servicesNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmServers/Server[@Name='$serverName']/Services")
					# Create a new Server Service Element and populate it with Name and Status
                    $newServiceNode = $FarmConfigXML.CreateElement("Service")
                    $newServiceNode.SetAttribute("Name","Business Data Connectivity Service")
                    $newServiceNode.SetAttribute("Status","Online")
                    $servicesNode.AppendChild($newServiceNode)
                    
                    
                    if ($EdChoice -ge 3)
                    {
                        # Create a new Server Service Element and populate it with Name and Status
                        $newServiceNode = $FarmConfigXML.CreateElement("Service")
                        $newServiceNode.SetAttribute("Name","Secure Store Service")
                        $newServiceNode.SetAttribute("Status","Online")
                        $servicesNode.AppendChild($newServiceNode)
                        
                        
                        # Create a new Server Service Element and populate it with Name and Status
                        $newServiceNode = $FarmConfigXML.CreateElement("Service")
                        $newServiceNode.SetAttribute("Name","Managed Metadata Web Service")
                        $newServiceNode.SetAttribute("Status","Online")
                        $servicesNode.AppendChild($newServiceNode)
                        
                        
                        # Create a new Server Service Element and populate it with Name and Status
                        $newServiceNode = $FarmConfigXML.CreateElement("Service")
                        $newServiceNode.SetAttribute("Name","User Profile Service")
                        $newServiceNode.SetAttribute("Status","Online")
                        $servicesNode.AppendChild($newServiceNode)
                        
                        
                        # Create a new Server Service Element and populate it with Name and Status
                        $newServiceNode = $FarmConfigXML.CreateElement("Service")
                        $newServiceNode.SetAttribute("Name","Microsoft SharePoint Foundation Usage")
                        $newServiceNode.SetAttribute("Status","Online")
                        $servicesNode.AppendChild($newServiceNode)
                        
                        
                        # Create a new Server Service Element and populate it with Name and Status
                        $newServiceNode = $FarmConfigXML.CreateElement("Service")
                        $newServiceNode.SetAttribute("Name","Web Analytics Data Processing Service")
                        $newServiceNode.SetAttribute("Status","Online")
                        $servicesNode.AppendChild($newServiceNode)
                        
                        
                        # Create a new Server Service Element and populate it with Name and Status
                        $newServiceNode = $FarmConfigXML.CreateElement("Service")
                        $newServiceNode.SetAttribute("Name","Web Analytics Web Service")
                        $newServiceNode.SetAttribute("Status","Online")
                        $servicesNode.AppendChild($newServiceNode)
                        
                    }
                    
                    if ($EdChoice -ge 5)
                    {
                        # Create a new Server Service Element and populate it with Name and Status
                        $newServiceNode = $FarmConfigXML.CreateElement("Service")
                        $newServiceNode.SetAttribute("Name","Access Database Service")
                        $newServiceNode.SetAttribute("Status","Online")
                        $servicesNode.AppendChild($newServiceNode)
                        
                        
                        # Create a new Server Service Element and populate it with Name and Status
                        $newServiceNode = $FarmConfigXML.CreateElement("Service")
                        $newServiceNode.SetAttribute("Name","Excel Calculation Services")
                        $newServiceNode.SetAttribute("Status","Online")
                        $servicesNode.AppendChild($newServiceNode)
                        
                        
                        # Create a new Server Service Element and populate it with Name and Status
                        $newServiceNode = $FarmConfigXML.CreateElement("Service")
                        $newServiceNode.SetAttribute("Name","PerformancePoint Service")
                        $newServiceNode.SetAttribute("Status","Online")
                        $servicesNode.AppendChild($newServiceNode)
                        
                        
                        # Create a new Server Service Element and populate it with Name and Status
                        $newServiceNode = $FarmConfigXML.CreateElement("Service")
                        $newServiceNode.SetAttribute("Name","Visio Graphics Service")
                        $newServiceNode.SetAttribute("Status","Online")
                        $servicesNode.AppendChild($newServiceNode)
                        
                        
                        # Create a new Server Service Element and populate it with Name and Status
                        $newServiceNode = $FarmConfigXML.CreateElement("Service")
                        $newServiceNode.SetAttribute("Name","Word Automation Services")
                        $newServiceNode.SetAttribute("Status","Online")
                        $servicesNode.AppendChild($newServiceNode)
                        
                    }
              }
            4 {
                    $servicesNode = GetServerNode $serverName $FarmConfigXML
					$servicesNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmServers/Server[@Name='$serverName']/Services")
					# Create a new Server Service Element and populate it with Name and Status
                    $newServiceNode = $FarmConfigXML.CreateElement("Service")
                    $newServiceNode.SetAttribute("Name","SharePoint Server Search")
                    $newServiceNode.SetAttribute("Status","Online")
                    $servicesNode.AppendChild($newServiceNode)
                    
                    
                    # Create a new Server Service Element and populate it with Name and Status
                    $newServiceNode = $FarmConfigXML.CreateElement("Service")
                    $newServiceNode.SetAttribute("Name","Search Administration Web Service")
                    $newServiceNode.SetAttribute("Status","Online")
                    $servicesNode.AppendChild($newServiceNode)
                    
              }
            5 {
                    $servicesNode = GetServerNode $serverName $FarmConfigXML
					$servicesNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmServers/Server[@Name='$serverName']/Services")
					# Create a new Server Service Element and populate it with Name and Status
                    $newServiceNode = $FarmConfigXML.CreateElement("Service")
                    $newServiceNode.SetAttribute("Name","Search Query and Site Settings Service")
                    $newServiceNode.SetAttribute("Status","Online")
                    $servicesNode.AppendChild($newServiceNode)
                    
              }
            6 {
                    $FarmConfigXML.Customer.Farm.SetAttribute("FarmDBServer","$serverName")
					
					$FarmDBServerAlias = Read-Host "Enter an Alias for the SQL Server $serverName (Blank/Default = SharePointSQL) "
					if([string]::IsNullOrEmpty($FarmDBServerAlias))
					{
						$FarmDBServerAlias = "SharePointSQL"
					}
					$FarmConfigXML.Customer.Farm.SetAttribute("FarmDBServerAlias","$FarmDBServerAlias")
					
					$servicesNode = GetServerNode $FarmDBServerAlias $FarmConfigXML
					$servicesNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmServers/Server[@Name='$FarmDBServerAlias']/Services")
					# Create a new Server Service Element and populate it with Name and Status
                    $newServiceNode = $FarmConfigXML.CreateElement("Service")
                    $newServiceNode.SetAttribute("Name","Microsoft SharePoint Foundation Database")
                    $newServiceNode.SetAttribute("Status","Online")
                    $servicesNode.AppendChild($newServiceNode)
              }  
            7 {
              }          
        }
        
        
    }
    while($Choice -ne "7")
}



# Get the Farm Prefix and Service Account Prefix
$FarmPrefix = Read-Host "Enter a Prefix to be used in the Farm (MAX 5 chars - ex. Dev or Prod or Leave Blank for No Prefix) "   
if ([string]::IsNullOrEmpty($FarmPrefix))
{    
    $AcctPrefix = ""
    $DBPrefix = ""
}
else
{
    $PrefixDBs = Read-Host "Use the Farm Prefix for the Database Names? (Y or N - blank/default=Y) "
    $PrefixUsers = Read-Host "Use the Farm Prefix for the Service Accounts? (Y or N - blank/default=Y) "
    
    $FarmPrefix = $FarmPrefix + "_"
    
    if ($PrefixUsers -eq "Y" -or $PrefixUsers -eq "y" -or [string]::IsNullOrEmpty($PrefixUsers))
    {
        $AcctPrefix = $FarmPrefix
    }
    else{$AcctPrefix = ""}
    
    if ($PrefixDBs -eq "Y" -or $PrefixDBs -eq "y" -or [string]::IsNullOrEmpty($PrefixDBs))
    {
        $DBPrefix = $FarmPrefix
    }
    else{$DBPrefix = ""}
        
}
$FarmConfigXML.Customer.Farm.SetAttribute("DBPrefix", $DBPrefix)
$FarmConfigXML.Customer.Farm.SetAttribute("UserPrefix", $AcctPrefix)

$highIsolation = Read-Host "Isolate Service Applications? (Y or N - blank/default=N) "
if($highIsolation -eq "Y" -or $highIsolation -eq "y")
{
    $FarmConfigXML.Customer.Farm.SetAttribute("HighIsolation", "Y")
}
else{$FarmConfigXML.Customer.Farm.SetAttribute("HighIsolation", "N")}

$useCustomAccounts = Read-Host "Customize Default Service Accounts? (Y or N - blank/default=N) "
if($useCustomAccounts -eq "Y" -or $useCustomAccounts -eq "y")
{
    $FarmConfigXML.Customer.Farm.SetAttribute("UseCustomAccounts", "Y")
}
else{$FarmConfigXML.Customer.Farm.SetAttribute("UseCustomAccounts", "N")}

$serviceAcctsNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts")

function ServiceAcctElement
{
    param([string]$uname, [string]$type, [string]$pass)
    
    if($pass)
    {
        # Create a new Service Account Element
        $newServiceAcctNode = $FarmConfigXML.CreateElement("Account")
        $newServiceAcctNode.SetAttribute("Type","$type")
        $newServiceAcctNode.SetAttribute("Name","$uname")
        $newServiceAcctNode.SetAttribute("Password","$pass")
        $serviceAcctsNode.AppendChild($newServiceAcctNode)    
    }
    else
    {
        # Generate Password
        $Password = Get-ComplexPassword
        
        # Create a new Service Account Element
        $newServiceAcctNode = $FarmConfigXML.CreateElement("Account")
        $newServiceAcctNode.SetAttribute("Type","$type")
        $newServiceAcctNode.SetAttribute("Name","$uname")
        $newServiceAcctNode.SetAttribute("Password","$Password")
        $serviceAcctsNode.AppendChild($newServiceAcctNode)
    }
}

function UserExists
{
    param([string]$uname)
    
    $rootAD = New-Object System.DirectoryServices.DirectoryEntry
    
    #Check to see if the user already exists
    $search = [System.DirectoryServices.DirectorySearcher]$rootAD
    $search.Filter = "(sAMAccountName=$uname)"
    $UserExists = $search.FindAll()
    $UserExists
}


#Set Farm Service Account Names
if($FarmConfigXML.Customer.Farm.UseCustomAccounts -eq "Y" -or $FarmConfigXML.Customer.Farm.UseCustomAccounts -eq "y")
{
    $FarmAdmin = Read-Host "What is the Farm Admin (SetUp) Account? "
    $FarmAdmin = $AcctPrefix + $FarmAdmin
    if(UserExists $FarmAdmin){$pass = Read-Host "User $FarmAdmin Exists! Please enter existing Password ";ServiceAcctElement $FarmAdmin "Farm Admin" $pass}
    else{ServiceAcctElement $FarmAdmin "Farm Admin"}
    
    $FarmAcct = Read-Host "What is the Farm Connect Account? "
    $FarmAcct = $AcctPrefix + $FarmAcct
    if(UserExists $FarmAcct){$pass = Read-Host "User $FarmAcct Exists! Please enter existing Password ";ServiceAcctElement $FarmAcct "Farm Connect" $pass}
    else{ServiceAcctElement $FarmAcct "Farm Connect"}
        
    $ServiceAppAP = Read-Host "What is the Default Service App Account? "
    $ServiceAppAP = $AcctPrefix + $ServiceAppAP
    if(UserExists $ServiceAppAP){$pass = Read-Host "User $ServiceAppAP Exists! Please enter existing Password ";ServiceAcctElement $ServiceAppAP "Default SA AppPool" $pass}
    else{ServiceAcctElement $ServiceAppAP "Default SA AppPool"}
    
    $SiteAP = Read-Host "What is the Default Site App Pool Account? "
    $SiteAP = $AcctPrefix + $SiteAP
    if(UserExists $SiteAP){$pass = Read-Host "User $SiteAP Exists! Please enter existing Password ";ServiceAcctElement $SiteAP "Default Site AppPool" $pass}
    else{ServiceAcctElement $SiteAP "Default Site AppPool"}
    
    $SiteAdmin = Read-Host "What is the Default Site Admin Account? "
    $SiteAdmin = $AcctPrefix + $SiteAdmin
    if(UserExists $SiteAdmin){$pass = Read-Host "User $SiteAdmin Exists! Please enter existing Password ";ServiceAcctElement $SiteAdmin "Default Site Admin" $pass}
    else{ServiceAcctElement $SiteAdmin "Default Site Admin"}
    
    if($FarmConfigXML.Customer.Farm.LicenseLevel -eq "Search Server 2010" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard Internet" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise Internet")
    { 
        $SearchAP = Read-Host "What is the Search App Pool Account? "
        $SearchAP = $AcctPrefix + $SearchAP
        if(UserExists $SearchAP){$pass = Read-Host "User $SearchAP Exists! Please enter existing Password ";ServiceAcctElement $SearchAP "Search AppPool" $pass}
        else{ServiceAcctElement $SearchAP "Search AppPool"}
        
        $SearchServ = Read-Host "What is the Search Service Account? "
        $SearchServ = $AcctPrefix + $SearchServ
        if(UserExists $SearchServ){$pass = Read-Host "User $SearchServ Exists! Please enter existing Password ";ServiceAcctElement $SearchServ "Search Service" $pass}
        else{ServiceAcctElement $SearchServ "Search Service"}
        
        $SearchCrawl = Read-Host "What is the Search Crawl Account? "
        $SearchCrawl = $AcctPrefix + $SearchCrawl
        if(UserExists $SearchCrawl){$pass = Read-Host "User $SearchCrawl Exists! Please enter existing Password ";ServiceAcctElement $SearchCrawl "Search Crawl" $pass}
        else{ServiceAcctElement $SearchCrawl "Search Crawl"}
        
        if($FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard Internet" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise Internet")
        {
            $UserProfileImport = Read-Host "What is the UPS Account? "
            $UserProfileImport = $AcctPrefix + $UserProfileImport
            if(UserExists $UserProfileImport){$pass = Read-Host "User $UserProfileImport Exists! Please enter existing Password ";ServiceAcctElement $UserProfileImport "User Profile Import" $pass}
            else{ServiceAcctElement $UserProfileImport "User Profile Import"}
            
            $CacheReader = Read-Host "What is the Cache Reader Account? "
            $CacheReader = $AcctPrefix + $CacheReader
            if(UserExists $CacheReader){$pass = Read-Host "User $CacheReader Exists! Please enter existing Password ";ServiceAcctElement $CacheReader "Cache Reader" $pass}
            else{ServiceAcctElement $CacheReader "Cache Reader"}
            
            $CacheUser = Read-Host "What is the Cache User Account? "
            $CacheUser = $AcctPrefix + $CacheUser
            if(UserExists $CacheUser){$pass = Read-Host "User $CacheUser Exists! Please enter existing Password ";ServiceAcctElement $CacheUser "Cache User" $pass}
            else{ServiceAcctElement $CacheUser "Cache User"}
            
        }
    }
    
    if($FarmConfigXML.Customer.Farm.HighIsolation -eq "Y" -or $FarmConfigXML.Customer.Farm.HighIsolation -eq "y")
    {
        $BCSAppPool = Read-Host "What is the BCS App Pool Account? "
        $BCSAppPool = $AcctPrefix + $BCSAppPool
        if(UserExists $BCSAppPool){$pass = Read-Host "User $BCSAppPool Exists! Please enter existing Password ";ServiceAcctElement $BCSAppPool "BCS AppPool" $pass}
        else{ServiceAcctElement $BCSAppPool "BCS AppPool"}
            
        
        if($FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard Internet" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise Internet")
        {
            $UsageServ = Read-Host "What is the Usage Service Account? "
            $UsageServ = $AcctPrefix + $UsageServ
            if(UserExists $UsageServ){$pass = Read-Host "User $UsageServ Exists! Please enter existing Password ";ServiceAcctElement $UsageServ "Usage AppPool" $pass}
            else{ServiceAcctElement $UsageServ "Usage AppPool"}
            
            $STServ = Read-Host "What is the Secure Token Service Account? " 
            $STServ = $AcctPrefix + $STServ
            if(UserExists $STServ){$pass = Read-Host "User  $STServ Exists! Please enter existing Password ";ServiceAcctElement $STServ "Secure Token Service" $pass}
            else{ServiceAcctElement $STServ "Secure Token Service"}
            
            $C2WTS = Read-Host "What is the Claims to Windows Token Service Account? "
            $C2WTS = $AcctPrefix + $C2WTS
            if(UserExists $C2WTS){$pass = Read-Host "User $C2WTS Exists! Please enter existing Password ";ServiceAcctElement $C2WTS "Claims to Windows Token Service" $pass}
            else{ServiceAcctElement $C2WTS "Claims to Windows Token Service"}
            
            $MMDAppPool = Read-Host "What is the Managed MetaData App Pool Account? "
            $MMDAppPool = $AcctPrefix + $MMDAppPool
            if(UserExists $MMDAppPool){$pass = Read-Host "User $MMDAppPool Exists! Please enter existing Password ";ServiceAcctElement $MMDAppPool "Managed Metadata AppPool" $pass}
            else{ServiceAcctElement $MMDAppPool "Managed Metadata AppPool"}
            
            $UPSAppPool = Read-Host "What is the User Profile Synch Account? "
            $UPSAppPool = $AcctPrefix + $UPSAppPool
            if(UserExists $UPSAppPool){$pass = Read-Host "User $UPSAppPool Exists! Please enter existing Password ";ServiceAcctElement $UPSAppPool "User Profile AppPool" $pass}
            else{ServiceAcctElement $UPSAppPool "User Profile AppPool"}
            
            $SecureStoreAP = Read-Host "What is the Secure Store App Pool Account? "
            $SecureStoreAP = $AcctPrefix + $SecureStoreAP
            if(UserExists $SecureStoreAP){$pass = Read-Host "User $SecureStoreAP Exists! Please enter existing Password ";ServiceAcctElement $SecureStoreAP "Secure Store AppPool" $pass}
            else{ServiceAcctElement $SecureStoreAP "Secure Store AppPool"}
            
            $WebAnalyticsAP = Read-Host "What is the Web Analytics App Pool Account? "
            $WebAnalyticsAP = $AcctPrefix + $WebAnalyticsAP 
            if(UserExists $WebAnalyticsAP){$pass = Read-Host "User $WebAnalyticsAP Exists! Please enter existing Password ";ServiceAcctElement $WebAnalyticsAP "Web Analytics AppPool" $pass}
            else{ServiceAcctElement $WebAnalyticsAP "Web Analytics AppPool"}
            
        }
        if($FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise Internet")
        {
            $VisioAP = Read-Host "What is the Visio App Pool Account? "
            $VisioAP = $AcctPrefix + $VisioAP
            if(UserExists $VisioAP){$pass = Read-Host "User $VisioAP Exists! Please enter existing Password ";ServiceAcctElement $VisioAP "Visio AppPool" $pass}
            else{ServiceAcctElement $VisioAP "Visio AppPool"}
            
            $PerformancePointAP = Read-Host "What is the PerformancePoint App Pool Account? "
            $PerformancePointAP = $AcctPrefix + $PerformancePointAP
            if(UserExists $PerformancePointAP){$pass = Read-Host "User $PerformancePointAP Exists! Please enter existing Password ";ServiceAcctElement $PerformancePointAP "Performance Point AppPool" $pass}
            else{ServiceAcctElement $PerformancePointAP "Performance Point AppPool"}
            
            $AccessAP = Read-Host "What is the Access Services App Pool Account? "
            $AccessAP = $AcctPrefix + $AccessAP
            if(UserExists $AccessAP){$pass = Read-Host "User $AccessAP Exists! Please enter existing Password ";ServiceAcctElement $AccessAP "Access AppPool" $pass}
            else{ServiceAcctElement $AccessAP "Access AppPool"}
            
            $ExcelAP = Read-Host "What is the Excel Services App Pool Account? "
            $ExcelAP = $AcctPrefix + $ExcelAP
            if(UserExists $ExcelAP){$pass = Read-Host "User $ExcelAP Exists! Please enter existing Password ";ServiceAcctElement $ExcelAP "Excel AppPool" $pass}
            else{ServiceAcctElement $ExcelAP "Excel AppPool"}
            
            $WordAP = Read-Host "What is the Word Services App Pool Account? "
            $WordAP = $AcctPrefix + $WordAP
            if(UserExists $WordAP){$pass = Read-Host "User $WordAP Exists! Please enter existing Password ";ServiceAcctElement $WordAP "Word AppPool" $pass}
            else{ServiceAcctElement $WordAP "Word AppPool"}
            
        }
    }
}
else
{
    $FarmAdmin = $AcctPrefix + "SP_Admin"
    if(UserExists $FarmAdmin){$pass = Read-Host "User $FarmAdmin Exists! Please enter existing Password ";ServiceAcctElement $FarmAdmin "Farm Admin" $pass}
    else{ServiceAcctElement $FarmAdmin "Farm Admin"}
            
    $FarmAcct = $AcctPrefix + "SP_Connect"
    if(UserExists $FarmAcct){$pass = Read-Host "User $FarmAcct Exists! Please enter existing Password ";ServiceAcctElement $FarmAcct "Farm Connect" $pass}
    else{ServiceAcctElement $FarmAcct "Farm Connect"}
            
    $ServiceAppAP = $AcctPrefix + "SP_ServApp_AP"
    if(UserExists $ServiceAppAP){$pass = Read-Host "User $ServiceAppAP Exists! Please enter existing Password ";ServiceAcctElement $ServiceAppAP "Default SA AppPool" $pass}
    else{ServiceAcctElement $ServiceAppAP "Default SA AppPool"}
            
    $SiteAP = $AcctPrefix + "SP_Site_AP"
    if(UserExists $SiteAP){$pass = Read-Host "User $SiteAP Exists! Please enter existing Password ";ServiceAcctElement $SiteAP "Default Site AppPool" $pass}
    else{ServiceAcctElement $SiteAP "Default Site AppPool"}
            
    $SiteAdmin = $AcctPrefix + "Site_Admin"
    if(UserExists $SiteAdmin){$pass = Read-Host "User $SiteAdmin Exists! Please enter existing Password ";ServiceAcctElement $SiteAdmin "Default Site Admin" $pass}
    else{ServiceAcctElement $SiteAdmin "Default Site Admin"}
            
    
    
    if($FarmConfigXML.Customer.Farm.LicenseLevel -eq "Search Server 2010" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard Internet" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise Internet")
    {
        $SearchAP = $AcctPrefix + "SP_Search_AP"
        if(UserExists $SearchAP){$pass = Read-Host "User $SearchAP Exists! Please enter existing Password ";ServiceAcctElement $SearchAP "Search AppPool" $pass}
        else{ServiceAcctElement $SearchAP "Search AppPool"}
            
        $SearchServ = $AcctPrefix + "SP_SearchServ"
        if(UserExists $SearchServ){$pass = Read-Host "User $SearchServ Exists! Please enter existing Password ";ServiceAcctElement $SearchServ "Search Service" $pass}
        else{ServiceAcctElement $SearchServ "Search Service"}
            
        $SearchCrawl = $AcctPrefix + "SP_SearchCrawl"
        if(UserExists $SearchCrawl){$pass = Read-Host "User $SearchCrawl Exists! Please enter existing Password ";ServiceAcctElement $SearchCrawl "Search Crawl" $pass}
        else{ServiceAcctElement $SearchCrawl "Search Crawl"}
        
    }
    if($FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard Internet" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise Internet")
    {
        $UserProfileImport = $AcctPrefix + "SP_UPS"
        if(UserExists $UserProfileImport){$pass = Read-Host "User $UserProfileImport Exists! Please enter existing Password ";ServiceAcctElement $UserProfileImport "User Profile Import" $pass}
        else{ServiceAcctElement $UserProfileImport "User Profile Import"}
        
        $CacheReader = $AcctPrefix + "SP_CacheReader"
        if(UserExists $CacheReader){$pass = Read-Host "User $CacheReader Exists! Please enter existing Password ";ServiceAcctElement $CacheReader "Cache Reader" $pass}
        else{ServiceAcctElement $CacheReader "Cache Reader"}
        
        $CacheUser = $AcctPrefix + "SP_CacheUser"
        if(UserExists $CacheUser){$pass = Read-Host "User $CacheUser Exists! Please enter existing Password ";ServiceAcctElement $CacheUser "Cache User" $pass}
        else{ServiceAcctElement $CacheUser "Cache User"}
        
    }
    if($FarmConfigXML.Customer.Farm.HighIsolation -eq "Y" -or $FarmConfigXML.Customer.Farm.HighIsolation -eq "y")
    {
        $BCSAppPool = $AcctPrefix + "SP_BCS_AP"
        if(UserExists $BCSAppPool){$pass = Read-Host "User $BCSAppPool Exists! Please enter existing Password ";ServiceAcctElement $BCSAppPool "BCS AppPool" $pass}
        else{ServiceAcctElement $BCSAppPool "BCS AppPool"}
        
        
        if($FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard Internet" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise Internet")
        {
            $UsageServ = $AcctPrefix + "SP_Usage_AP"
            if(UserExists $UsageServ){$pass = Read-Host "User $UsageServ Exists! Please enter existing Password ";ServiceAcctElement $UsageServ "Usage AppPool" $pass}
            else{ServiceAcctElement $UsageServ "Usage AppPool"}
        
            $STServ = $AcctPrefix + "SP_STS_Serv"
            if(UserExists $STServ){$pass = Read-Host "User $STServ Exists! Please enter existing Password ";ServiceAcctElement $STServ "Secure Token Service" $pass}
            else{ServiceAcctElement $STServ "Secure Token Service"}
        
            $C2WTS = $AcctPrefix + "SP_C2WTS_Serv"
            if(UserExists $C2WTS){$pass = Read-Host "User $C2WTS Exists! Please enter existing Password ";ServiceAcctElement $C2WTS "Claims to Windows Token Service" $pass}
            else{ServiceAcctElement $C2WTS "Claims to Windows Token Service"}
        
            $MMDAppPool = $AcctPrefix + "SP_MMD_AP"
            if(UserExists $MMDAppPool){$pass = Read-Host "User $MMDAppPool Exists! Please enter existing Password ";ServiceAcctElement $MMDAppPool "Managed Metadata AppPool" $pass}
            else{ServiceAcctElement $MMDAppPool "Managed Metadata AppPool"}
        
            $UPSAppPool = $AcctPrefix + "SP_UPS_AP"
            if(UserExists $UPSAppPool){$pass = Read-Host "User $UPSAppPool Exists! Please enter existing Password ";ServiceAcctElement $UPSAppPool "User Profile AppPool" $pass}
            else{ServiceAcctElement $UPSAppPool "User Profile AppPool"}
        
            $SecureStoreAP = $AcctPrefix + "SP_SS_AP"
            if(UserExists $SecureStoreAP){$pass = Read-Host "User $SecureStoreAP Exists! Please enter existing Password ";ServiceAcctElement $SecureStoreAP "Secure Store AppPool" $pass}
            else{ServiceAcctElement $SecureStoreAP "Secure Store AppPool"}
        
            $WebAnalyticsAP = $AcctPrefix + "SP_WA_AP"
            if(UserExists $WebAnalyticsAP){$pass = Read-Host "User $WebAnalyticsAP Exists! Please enter existing Password ";ServiceAcctElement $WebAnalyticsAP "Web Analytics AppPool" $pass}
            else{ServiceAcctElement $WebAnalyticsAP "Web Analytics AppPool"}
        
            
        }
        if($FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise Internet")
        {
            $VisioAP = $AcctPrefix + "SP_Visio_AP"
            if(UserExists $VisioAP){$pass = Read-Host "User $VisioAP Exists! Please enter existing Password ";ServiceAcctElement $VisioAP "Visio AppPool" $pass}
            else{ServiceAcctElement $VisioAP "Visio AppPool"}
        
            $PerformancePointAP = $AcctPrefix + "SP_PerfPoint_AP"
            if(UserExists $PerformancePointAP){$pass = Read-Host "User $PerformancePointAP Exists! Please enter existing Password ";ServiceAcctElement $PerformancePointAP "Performance Point AppPool" $pass}
            else{ServiceAcctElement $PerformancePointAP "Performance Point AppPool"}
        
            $AccessAP = $AcctPrefix + "SP_Access_AP"
            if(UserExists $AccessAP){$pass = Read-Host "User $AccessAP Exists! Please enter existing Password ";ServiceAcctElement $AccessAP "Access AppPool" $pass}
            else{ServiceAcctElement $AccessAP "Access AppPool"}
        
            $ExcelAP = $AcctPrefix + "SP_Excel_AP"
            if(UserExists $ExcelAP){$pass = Read-Host "User $ExcelAP Exists! Please enter existing Password ";ServiceAcctElement $ExcelAP "Excel AppPool" $pass}
            else{ServiceAcctElement $ExcelAP "Excel AppPool"}
        
            $WordAP = $AcctPrefix + "SP_Word_AP"
            if(UserExists $WordAP){$pass = Read-Host "User $WordAP Exists! Please enter existing Password ";ServiceAcctElement $WordAP "Word AppPool" $pass}
            else{ServiceAcctElement $WordAP "Word AppPool"}        
        }
    }
}

function GetAPAcctName
{
	param([string]$acctType, [string]$defSAAppPoolAcctName)
	
	$AppPoolAcctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type='$acctType']")
	if($AppPoolAcctNode -eq $null){$AppPoolAcctName = $defSAAppPoolAcctName}
	else{$AppPoolAcctName = $AppPoolAcctNode.Name}
	
	$AppPoolAcctName
}

function GetAppPoolName
{
	param([string]$appPoolAcct, [string]$customAppPoolName, [string]$defSAAppPoolAcctName)
	
	if($appPoolAcct -eq $defSAAppPoolAcctName)
	{
		$appPoolName = "SharePoint Web Services"	
	}
	else{$appPoolName = "$customAppPoolName"}
	
	$appPoolName
}

function AddServiceAppNode
{
	param([string]$customize, [string]$servAppName, [string]$servAppType, [string]$dbName, [string]$dbServer, [string]$saAppPoolName, [string]$saAppPoolAcct, [string]$partitioning, [string]$proxyGroup)
	
	$serviceAppsNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmServiceApplications")
	
	if($servAppType -eq "Web Analytics Service Application")
	{
		$whDBName = "WarehouseDB"
		$stagingDBName = "StagerDB"
	}
	elseif($servAppType -eq "User Profile Service Application")
	{
		$profileDB = "ProfileDB"
		$syncDB = "SyncDB"
		$socialDB = "SocialDB"
	}
	elseif($servAppType -eq "SharePoint Server Search")
	{
		$searchAdminDB = "SearchDB"
		$crawlStoreDB = "SearchDB_CrawlStore"
				
		$indexServers = Get-ServerNameByService $FarmConfigXML "SharePoint Server Search"				
		$queryServers = Get-ServerNameByService $FarmConfigXML "Search Query and Site Settings Service"
	}
	
	if($customize -eq "y" -or $customize -eq "Y")
	{
		while($answer -ne "Done")
		{
			Write-Host "1. Service Application Name: 	$servAppName"
			Write-Host "2. AppPool Name: 				$saAppPoolName"
			Write-Host "3. AppPool Account: 			$saAppPoolAcct"
			if($dbServer){Write-Host "4. Database Server: 			$dbServer"}
			if($whDBName){Write-Host "5. Warehouse Database Name: 				$whDBName"}
			elseif($profileDB){Write-Host "5. Profile Database Name: 				$profileDB"}
			elseif($searchAdminDB){Write-Host "5. Search Database Name: 				$searchAdminDB"}
			elseif($dbName){Write-Host "5. Database Name: 				$dbName"}
			if($stagingDBName){Write-Host "6. Warehouse Database Name: 				$stagingDBName"}
			elseif($syncDB){Write-Host "6. Sync Database Name: 				$syncDB"}
			elseif($crawlStoreDB){Write-Host "6. CrawlStore Database Name: 				$crawlStoreDB"}
			if($socialDB){Write-Host "7. Social Database Name: 				$socialDB"}
			Write-Host "default. Done"
			$answer = Read-Host "Choose which paramaeter to change for $servAppType: "
			
			if($whDBName)
			{
				switch($answer)
				{
					1 {$servAppName = Read-Host "Enter the new Service Application Name: "}
					2 {$saAppPoolName = Read-Host "Enter the new AppPool Name: "}
					3 {$saAppPoolAcct = Read-Host "Enter the new AppPool Account: "}
					4 {$dbServer = Read-Host "Enter the new Database Server: "}
					5 {$whDBName = Read-Host "Enter the new Warehouse Database Name: "}
					6 {$stagingDBName = Read-Host "Enter the new Staging Database Name: "}					
					default {$answer = "Done"}				
				}
			}
			elseif($profileDB)
			{
				switch($answer)
				{
					1 {$servAppName = Read-Host "Enter the new Service Application Name: "}
					2 {$saAppPoolName = Read-Host "Enter the new AppPool Name: "}
					3 {$saAppPoolAcct = Read-Host "Enter the new AppPool Account: "}
					4 {$dbServer = Read-Host "Enter the new Database Server: "}
					5 {$profileDB = Read-Host "Enter the new Profile Database Name: "}
					6 {$syncDB = Read-Host "Enter the new Sync Database Name: "}
					7 {$socialDB = Read-Host "Enter the new Social Database Name: "}
					default {$answer = "Done"}				
				}
			}
			elseif($searchAdminDB)
			{
				switch($answer)
				{
					1 {$servAppName = Read-Host "Enter the new Service Application Name: "}
					2 {$saAppPoolName = Read-Host "Enter the new AppPool Name: "}
					3 {$saAppPoolAcct = Read-Host "Enter the new AppPool Account: "}
					4 {$dbServer = Read-Host "Enter the new Database Server: "}
					5 {$searchAdminDB = Read-Host "Enter the new Search Database Name: "}
					6 {$crawlStoreDB = Read-Host "Enter the new CrawlStore Database Name: "}					
					default {$answer = "Done"}				
				}
			}
			else
			{
				switch($answer)
				{
					1 {$servAppName = Read-Host "Enter the new Service Application Name: "}
					2 {$saAppPoolName = Read-Host "Enter the new AppPool Name: "}
					3 {$saAppPoolAcct = Read-Host "Enter the new AppPool Account: "}
					4 {$dbServer = Read-Host "Enter the new Database Server: "}
					5 {$dbName = Read-Host "Enter the new Database Name: "}
					default {$answer = "Done"}				
				}
			}
		}
	}
	
	# Create a new Service App Element
    $newServiceAppNode = $FarmConfigXML.CreateElement("ServiceApp")
    $newServiceAppNode.SetAttribute("TypeName","$servAppType")
    $newServiceAppNode.SetAttribute("Status","Online")
    
	$newElement = $FarmConfigXML.CreateElement("DisplayName")
	$newElement.set_InnerText("$servAppName")
	$newServiceAppNode.AppendChild($newElement)
	
	$newElement = $FarmConfigXML.CreateElement("ServiceApplicationPoolName")
	$newElement.set_InnerText("$saAppPoolName")
	$newServiceAppNode.AppendChild($newElement)
	
	$newElement = $FarmConfigXML.CreateElement("ServiceApplicationPoolAcctName")
	$newElement.set_InnerText("$saAppPoolAcct")
	$newServiceAppNode.AppendChild($newElement)
	
	$newElement = $FarmConfigXML.CreateElement("ServiceApplicationProxyGroup")
	$newElement.set_InnerText("$proxyGroup")
	$newServiceAppNode.AppendChild($newElement)
	
	$newElement = $FarmConfigXML.CreateElement("Partitioning")
	$newElement.set_InnerText("$partitioning")
	$newServiceAppNode.AppendChild($newElement)
	
	if($whDBName)
	{
		$newElement = $FarmConfigXML.CreateElement("WarehouseDatabase")
		$newElement.SetAttribute("DBName","$whDBName")
		$newElement.SetAttribute("DBServer","$dbServer")
		$newServiceAppNode.AppendChild($newElement)
		
		$newElement = $FarmConfigXML.CreateElement("StagingDatabase")
		$newElement.SetAttribute("DBName","$stagingDBName")
		$newElement.SetAttribute("DBServer","$dbServer")
		$newServiceAppNode.AppendChild($newElement)
	}
	elseif($profileDB)
	{
		$newElement = $FarmConfigXML.CreateElement("ProfileDatabase")
		$newElement.SetAttribute("DBName","$profileDB")
		$newElement.SetAttribute("DBServer","$dbServer")
		$newServiceAppNode.AppendChild($newElement)
		
		$newElement = $FarmConfigXML.CreateElement("SyncDatabase")
		$newElement.SetAttribute("DBName","$syncDB")
		$newElement.SetAttribute("DBServer","$dbServer")
		$newServiceAppNode.AppendChild($newElement)
		
		$newElement = $FarmConfigXML.CreateElement("SocialDatabase")
		$newElement.SetAttribute("DBName","$socialDB")
		$newElement.SetAttribute("DBServer","$dbServer")
		$newServiceAppNode.AppendChild($newElement)
	}
	elseif($searchAdminDB)
	{
		$newElement = $FarmConfigXML.CreateElement("SearchAdminDatabase")
		$newElement.SetAttribute("DBName","$searchAdminDB")
		$newElement.SetAttribute("DBServer","$dbServer")
		$newServiceAppNode.AppendChild($newElement)
		
		$newElement = $FarmConfigXML.CreateElement("CrawlStores")
		$newCSElement = $FarmConfigXML.CreateElement("CrawlStore")
		$newCSElement.SetAttribute("DBName","$crawlStoreDB")		
		$newElement.AppendChild($newCSElement)
		$newServiceAppNode.AppendChild($newElement)
		
		$newElement = $FarmConfigXML.CreateElement("CrawlTopology")
		foreach($indexServer in $indexServers)
		{
			$newCCElement = $FarmConfigXML.CreateElement("CrawlComponent")
			$newCCElement.SetAttribute("ServerName","$indexServer")		
			$newElement.AppendChild($newCCElement)
		}
		$newServiceAppNode.AppendChild($newElement)
		
		$newElement = $FarmConfigXML.CreateElement("QueryTopology")
		foreach($queryServer in $queryServers)
		{
			$newQCElement = $FarmConfigXML.CreateElement("QueryComponent")
			$newQCElement.SetAttribute("ServerName","$queryServer")		
			$newElement.AppendChild($newQCElement)
		}
		$newServiceAppNode.AppendChild($newElement)
	}
	elseif($dbName)
	{
		$newElement = $FarmConfigXML.CreateElement("Database")
		$newElement.SetAttribute("DBName","$dbName")
		$newElement.SetAttribute("DBServer","$dbServer")
		$newServiceAppNode.AppendChild($newElement)
	}
	$serviceAppsNode.AppendChild($newServiceAppNode)
}

# Generate Foundation Service App Config
$custServiceApps = Read-Host "Customize Default Service App Configs? (Y or N - blank/default=N) "

$defSAAppPoolAcctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type='Default SA AppPool']")
$defSAAppPoolAcctName = $defSAAppPoolAcctNode.Name
$dbServer = Get-ServerNameByService $FarmConfigXML "Microsoft SharePoint Foundation Database"
	
# Build BCS Service App variables
# Get the App Pool Account from XML. Provide the Account Type and the Default SA AppPool Account Name
$appPoolAcct = GetAPAcctName "BCS AppPool" $defSAAppPoolAcctName
# Get the App Pool Name. Provide the AppPool Account, the Standard Custom App Pool Name, and the Default SA AppPool Account Name
$appPoolName = GetAppPoolName "$appPoolAcct" "BCS Web Services" $defSAAppPoolAcctName
# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
AddServiceAppNode "$custServiceApps" "Business Data Connectivity Services" "Business Data Connectivity Service Application" "BCSDB" "$dbServer" "$appPoolName" "$appPoolAcct" "UnPartitioned" "[default]"

# Generate Search Server 2010 Service App Config
if($FarmConfigXML.Customer.Farm.LicenseLevel -eq "Search Server 2010" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard Internet" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise Internet")
{
	# Build Search Admin Service App variables
	# Get the App Pool Account from XML. Provide the Account Type and the Default SA AppPool Account Name
	$appPoolAcct = GetAPAcctName "Search AppPool" $defSAAppPoolAcctName
	# Get the App Pool Name. Provide the AppPool Account, the Standard Custom App Pool Name, and the Default SA AppPool Account Name
	$appPoolName = GetAppPoolName "$appPoolAcct" "Search Web Services" $defSAAppPoolAcctName
	# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
	AddServiceAppNode "$custServiceApps" "Search Administration Services" "Search Administration Web Service for SharePoint Server Search" "" "" "$appPoolName" "$appPoolAcct" "" "[default]"
	
	# Build Search Service App variables
	# Get the App Pool Account from XML. Provide the Account Type and the Default SA AppPool Account Name
	$appPoolAcct = GetAPAcctName "Search AppPool" $defSAAppPoolAcctName
	# Get the App Pool Name. Provide the AppPool Account, the Standard Custom App Pool Name, and the Default SA AppPool Account Name
	$appPoolName = GetAppPoolName "$appPoolAcct" "Search Web Services" $defSAAppPoolAcctName
	# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
	AddServiceAppNode "$custServiceApps" "Search Services" "SharePoint Server Search" "" "$dbServer" "$appPoolName" "$appPoolAcct" "UnPartitioned" "[default]"
}

# Generate Standard Service App Config
if($FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Standard Internet" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise Internet")
{
	# Build Secure Store Service App variables
	# Get the App Pool Account from XML. Provide the Account Type and the Default SA AppPool Account Name
	$appPoolAcct = GetAPAcctName "Secure Store AppPool" $defSAAppPoolAcctName
	# Get the App Pool Name. Provide the AppPool Account, the Standard Custom App Pool Name, and the Default SA AppPool Account Name
	$appPoolName = GetAppPoolName "$appPoolAcct" "Secure Store Web Services" $defSAAppPoolAcctName
	# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
	AddServiceAppNode "$custServiceApps" "Secure Store Services" "Secure Store Service Application" "SecureStoreDB" "$dbServer" "$appPoolName" "$appPoolAcct" "UnPartitioned" "[default]"
	
	# Build State Service App variables
	# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
	AddServiceAppNode "$custServiceApps" "State Services" "State Service" "StateDB" "$dbServer" "" "" "" "[default]"
	
	# Build Managed MetaData Service App variables
	# Get the App Pool Account from XML. Provide the Account Type and the Default SA AppPool Account Name
	$appPoolAcct = GetAPAcctName "Managed Metadata AppPool" $defSAAppPoolAcctName
	# Get the App Pool Name. Provide the AppPool Account, the Standard Custom App Pool Name, and the Default SA AppPool Account Name
	$appPoolName = GetAppPoolName "$appPoolAcct" "Managed MetaData Web Services" $defSAAppPoolAcctName
	# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
	AddServiceAppNode "$custServiceApps" "Managed MetaData Services" "Managed Metadata Service" "MetadataDB" "$dbServer" "$appPoolName" "$appPoolAcct" "UnPartitioned" "[default]"
	
	# Build User Profile Service App variables
	# Get the App Pool Account from XML. Provide the Account Type and the Default SA AppPool Account Name
	$appPoolAcct = GetAPAcctName "User Profile AppPool" $defSAAppPoolAcctName
	# Get the App Pool Name. Provide the AppPool Account, the Standard Custom App Pool Name, and the Default SA AppPool Account Name
	$appPoolName = GetAppPoolName "$appPoolAcct" "User Profile Web Services" $defSAAppPoolAcctName
	# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
	AddServiceAppNode "$custServiceApps" "User Profile Services" "User Profile Service Application" "" "$dbServer" "$appPoolName" "$appPoolAcct" "UnPartitioned" "[default]"
	
	# Build Security Token Service App variables
	# Get the App Pool Account from XML. Provide the Account Type and the Default SA AppPool Account Name
	$appPoolAcct = GetAPAcctName "Secure Token Service" $defSAAppPoolAcctName
	# Get the App Pool Name. Provide the AppPool Account, the Standard Custom App Pool Name, and the Default SA AppPool Account Name
	$appPoolName = GetAppPoolName "$appPoolAcct" "Security Token Web Services" $defSAAppPoolAcctName
	# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
	AddServiceAppNode "$custServiceApps" "Security Token Services" "Security Token Service Application" "" "" "$appPoolName" "$appPoolAcct" "" "[default]"
	
	# Build Usage Service App variables	
	# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
	AddServiceAppNode "$custServiceApps" "Usage and Health Data Collection Services" "Usage and Health Data Collection Service Application" "UsageDB" "$dbServer" "" "" "" "[default]"
	
	# Build Web Analytics Service App variables
	# Get the App Pool Account from XML. Provide the Account Type and the Default SA AppPool Account Name
	$appPoolAcct = GetAPAcctName "Web Analytics AppPool" $defSAAppPoolAcctName
	# Get the App Pool Name. Provide the AppPool Account, the Standard Custom App Pool Name, and the Default SA AppPool Account Name
	$appPoolName = GetAppPoolName "$appPoolAcct" "Web Analytics Web Services" $defSAAppPoolAcctName
	# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
	AddServiceAppNode "$custServiceApps" "Web Analytics Services" "Web Analytics Service Application" "" "$dbServer" "$appPoolName" "$appPoolAcct" "UnPartitioned" "[default]"
}

# Generate Enterprise Service App Config
if($FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise" -or $FarmConfigXML.Customer.Farm.LicenseLevel -eq "Enterprise Internet")
{
	# Build Access Service App variables
	# Get the App Pool Account from XML. Provide the Account Type and the Default SA AppPool Account Name
	$appPoolAcct = GetAPAcctName "Access AppPool" $defSAAppPoolAcctName
	# Get the App Pool Name. Provide the AppPool Account, the Standard Custom App Pool Name, and the Default SA AppPool Account Name
	$appPoolName = GetAppPoolName "$appPoolAcct" "Access Web Services" $defSAAppPoolAcctName
	# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
	AddServiceAppNode "$custServiceApps" "Access Services" "Access Services Application" "" "" "$appPoolName" "$appPoolAcct" "" "[default]"
	
	# Build Visio Service App variables
	# Get the App Pool Account from XML. Provide the Account Type and the Default SA AppPool Account Name
	$appPoolAcct = GetAPAcctName "Visio AppPool" $defSAAppPoolAcctName
	# Get the App Pool Name. Provide the AppPool Account, the Standard Custom App Pool Name, and the Default SA AppPool Account Name
	$appPoolName = GetAppPoolName "$appPoolAcct" "Visio Web Services" $defSAAppPoolAcctName
	# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
	AddServiceAppNode "$custServiceApps" "Visio Graphics Services" "Access Services Application" "" "" "$appPoolName" "$appPoolAcct" "" "[default]"
	
	# Build Excel Service App variables
	# Get the App Pool Account from XML. Provide the Account Type and the Default SA AppPool Account Name
	$appPoolAcct = GetAPAcctName "Excel AppPool" $defSAAppPoolAcctName
	# Get the App Pool Name. Provide the AppPool Account, the Standard Custom App Pool Name, and the Default SA AppPool Account Name
	$appPoolName = GetAppPoolName "$appPoolAcct" "Excel Web Services" $defSAAppPoolAcctName
	# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
	AddServiceAppNode "$custServiceApps" "Excel Services" "Excel Services Application Web Service Application" "" "" "$appPoolName" "$appPoolAcct" "" "[default]"
	
	# Build Word Service App variables
	# Get the App Pool Account from XML. Provide the Account Type and the Default SA AppPool Account Name
	$appPoolAcct = GetAPAcctName "Word AppPool" $defSAAppPoolAcctName
	# Get the App Pool Name. Provide the AppPool Account, the Standard Custom App Pool Name, and the Default SA AppPool Account Name
	$appPoolName = GetAppPoolName "$appPoolAcct" "Word Web Services" $defSAAppPoolAcctName
	# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
	AddServiceAppNode "$custServiceApps" "Word Automation Services" "Word Automation Services" "WordDB" "$dbServer" "$appPoolName" "$appPoolAcct" "UnPartitioned" "[default]"
	
	# Build PerformancePoint Service App variables
	# Get the App Pool Account from XML. Provide the Account Type and the Default SA AppPool Account Name
	$appPoolAcct = GetAPAcctName "Performance Point AppPool" $defSAAppPoolAcctName
	# Get the App Pool Name. Provide the AppPool Account, the Standard Custom App Pool Name, and the Default SA AppPool Account Name
	$appPoolName = GetAppPoolName "$appPoolAcct" "PerfPoint Web Services" $defSAAppPoolAcctName
	# Add the Service App Node to the Farm Config XML. Provide $custServiceApps, Service App Name, Service App Type, Database Name, DB Server, $appPoolName, $appPoolAcct, Partitioning, Proxy Group
	AddServiceAppNode "$custServiceApps" "PerformancePoint Services" "PerformancePoint Service Application" "PerfPointDB" "$dbServer" "$appPoolName" "$appPoolAcct" "UnPartitioned" "[default]"

}

$FarmConfigXML.Customer.Farm.SetAttribute("Transformed","Y")

#End Region Get Input Variables 
$FarmConfigXML.Save("$curloc\FarmConfig.xml")
