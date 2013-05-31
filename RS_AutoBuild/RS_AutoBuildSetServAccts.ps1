#########################################################################################################
# BEGIN FUNCTIONS
#########################################################################################################

function New-ADUser
{
	param([string]$AccountName, [string]$Password, [string]$type)
    
    #Region Create AD Service Accounts
    #Get AD Information
    #Connect to current domain
    $dom = [System.DirectoryServices.ActiveDirectory.Domain]::getcurrentdomain()
    #Construct a valid UPN
    $UPN = "@" + $dom.Name

    #Construct connection strings to AD
    $rootDSE = [ADSI]'LDAP://RootDSE'
    $strdomain = "LDAP://OU=SharePoint,OU=Service Accounts," + $rootDSE.defaultNamingContext
    $domain = [ADSI]$strdomain
   

    #Check to see if the Service Accounts OU already exists
    $rootAD = New-Object System.DirectoryServices.DirectoryEntry
    $search = [System.DirectoryServices.DirectorySearcher]$rootAD
    $search.Filter = "(&(name=Service Accounts)(objectCategory=organizationalunit))"
    $OUSAExists = $search.FindOne()

    #If the Service Accounts OU exists, Check for the SharePoint OU
    if ($OUSAExists -ne $null)
    {
        $strSAOU = "LDAP://OU=Service Accounts," + $rootDSE.defaultNamingContext
        $SAOU = [ADSI]$strSAOU
        
        #Check to see if the SharePoint OU already exists
        $search = [System.DirectoryServices.DirectorySearcher]$rootAD
        $search.Filter = "(&(name=SharePoint)(objectCategory=organizationalunit))"
        $OUSPExists = $search.FindOne()
        
        #If the SharePoint OU does not exist, Create it
        if ($OUSPExists -eq $null)
        {
            $ou = $SAOU.Create("organizationalunit", "ou=SharePoint")
            $ou.SetInfo()
        }    
    }
    #Otherwise create both the Service Accounts and SharePoint OUs
    else
    {
        $ou = $rootAD.Create("organizationalunit", "ou=Service Accounts")
        $ou.SetInfo()
        
        $strSAOU = "LDAP://OU=Service Accounts," + $rootDSE.defaultNamingContext
        $SAOU = [ADSI]$strSAOU
        
        $ou = $SAOU.Create("organizationalunit", "ou=SharePoint")
        $ou.SetInfo()
    }
    
    #Check to see if the user already exists
    $search = [System.DirectoryServices.DirectorySearcher]$rootAD
    $search.Filter = "(sAMAccountName=$AccountName)"
    $UserExists = $search.FindAll()  
    
    #If the user exists do nothing otherwise create the new user account
    if($UserExists -ne $null)
    {        
        Write-Output "User $AccountName exists! Skipping..."        
    }
    else
    {                     
        # User Creation
        $newuser = $domain.create("user","cn=" + $AccountName)
        $newuser.setinfo()
        $newuser.samaccountname = $AccountName
        $newuser.setinfo()
        $newuser.givenname = $AccountName
        $newuser.displayname = $AccountName
        $newuser.userprincipalname = $AccountName + $UPN
        $newuser.setinfo()
        $newuser.SetPassword($Password)
        $newuser.setinfo()
        $newuser.userAccountControl = 66048
        $newuser.setinfo()
    }

    if($type -eq "Farm Admin")
    {
        $groupPath = "LDAP://CN=Domain Admins, CN=Users," + $rootDSE.defaultNamingContext
        $group = [ADSI]$groupPath
        $members = $group.member
        $group.member = $members+$newuser.distinguishedName
        $group.setinfo()
    }
}

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

#Generate a new random password
function Get-RandomPassword {
    param($length = 10,$characters = 'abcdefghkmnprstuvwxyzABCDEFGHKLMNPRSTUVWXYZ123456789!"§$%&/()=?*+#_')

    # select random characters
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }

    # output random pwd
    $private:ofs=""

    [String]$characters[$random]
}

function Get-RandomText {
    param($text)

    $anzahl = $text.length -1
    $indizes = Get-Random -InputObject (0..$anzahl) -Count $anzahl

    $private:ofs=''
    [String]$text[$indizes]
}

function Get-ComplexPassword {
    $password = Get-RandomPassword -length 3 -characters 'abcdefghiklmnprstuvwxyz'
    #$password += Get-RandomPassword -length 2 -characters '#*+)'
    $password += Get-RandomPassword -length 3 -characters '123456789'
    $password += Get-RandomPassword -length 3 -characters 'ABCDEFGHKLMNPRSTUVWXYZ'

    Get-RandomText $password
}

#Set SQL Access for Farm Admin and Farm Connect
Function Set-SQLAccess
{
    param([string]$acctName, [string]$role, [string]$DBServer)
    
	#Write-Host -ForegroundColor Cyan "- Checking access to SQL server (or instance) `"$DBServer`"..."	
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlConnection.ConnectionString = "Server=$DBServer;Database=master;Integrated Security=True"
	$SqlCmd.CommandText = "exec sp_addsrvrolemember @loginame=N'$acctName', @rolename=N'$role';"
	$SqlCmd.Connection = $SqlConnection
	$SqlCmd.CommandTimeout = 10
	Try
	{
		$SqlCmd.Connection.Open()
		$SqlCmd.ExecuteNonQuery() | Out-Null
	}
	Catch
	{
		Write-Error $_
		Write-Warning " - Connection failed to SQL server or instance `"$DBServer`"!"
		Write-Warning " - Check the server (or instance) name, or verify rights for the Current Logged on User."
		$SqlCmd.Connection.Close()
		Suspend-Script
		break
	}	
	$SqlCmd.Connection.Close()
}
#EndRegion

function CreateServAcct
{
    param([string]$uname, [string]$type, [string]$pass)
    
    New-ADUser $uname $pass $type   
    $UserLogEntry = $type + " = " + $netbios + "\" + $uname + " " + $pass    
    $UserLogEntry | out-file "$text" -append
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

###################################################################################################################
# END FUNCTIONS
###################################################################################################################

# Get current script execution path and the parent path
$0 = $myInvocation.MyCommand.Definition
$env:dp0 = [System.IO.Path]::GetDirectoryName($0)
$bits = Get-Item $env:dp0 | Split-Path -Parent
$env:AutoSPPath = $bits + "\AutoSPInstaller"

$netbios = (Get-LocalLogonInformation).DomainShortName

# Open/Create the Users.txt file    
$text = "$env:dp0\ServiceAccounts.txt"
#Get Current Date
$date = Get-Date

#Initiate the Service Account Creation Log
"Service Account Creation Log - $date" | out-file "$text"
 "" | out-file "$text" -append

$AutoSPXML = [xml](get-content "$env:AutoSPPath\AutoSPInstallerInput.xml" -EA 0)

$prefix = $AutoSPXML.Configuration.Farm.Database.DBPrefix
if($prefix -eq $null -or $prefix -eq "")
{
    $AcctPrefix = ""
}
else{$AcctPrefix = $prefix + "_"}

# Set Farm Service Account Names
$FarmAdmin = $AcctPrefix + "SP_Admin"
if(UserExists $FarmAdmin){$pass = Read-Host "User $FarmAdmin Exists! Please enter existing Password ";CreateServAcct $FarmAdmin "Farm Admin" $pass}
else{$pass = Get-ComplexPassword; CreateServAcct $FarmAdmin "Farm Admin" $pass}
$FarmAdminPass = $pass

$AutoSPXML.Configuration.Install.AutoAdminLogon.Enable = "true"
$AutoSPXML.Configuration.Install.AutoAdminLogon.Password = "$pass"

# Add SQL Permissions for Farm Admin
Set-SQLAccess "$netBios\$FarmAdmin" "SysAdmin" $dbServer
            
$FarmAcct = $AcctPrefix + "SP_Connect"
if(UserExists $FarmAcct){$pass = Read-Host "User $FarmAcct Exists! Please enter existing Password ";CreateServAcct $FarmAcct "Farm Connect" $pass}
else{$pass = Get-ComplexPassword; CreateServAcct $FarmAcct "Farm Connect" $pass}

$AutoSPXML.Configuration.Farm.Account.Username = $netbios + "\" + $FarmAcct
$AutoSPXML.Configuration.Farm.Account.Password = "$pass"

#Add SQL Permissions for Farm Connect Account
Set-SQLAccess "$netBios\$FarmAcct" "SecurityAdmin" $dbServer
Set-SQLAccess "$netBios\$FarmAcct" "DBCreator" $dbServer
            
$ServiceAppAP = $AcctPrefix + "SP_ServApp_AP"
if(UserExists $ServiceAppAP){$pass = Read-Host "User $ServiceAppAP Exists! Please enter existing Password ";CreateServAcct $ServiceAppAP "Default SA AppPool" $pass}
else{$pass = Get-ComplexPassword; CreateServAcct $ServiceAppAP "Default SA AppPool" $pass}

$mgdAcctNode = $AutoSPXML.SelectSingleNode("//Configuration/Farm/ManagedAccounts/ManagedAccount[@CommonName = 'spservice']")
$mgdAcctNode.Username = $netbios + "\" + $ServiceAppAP
$mgdAcctNode.Password = "$pass" 

$SiteAdmin = $AcctPrefix + "Site_Admin"
if(UserExists $SiteAdmin){$pass = Read-Host "User $SiteAdmin Exists! Please enter existing Password ";CreateServAcct $SiteAdmin "Default Site Admin" $pass}
else{$pass = Get-ComplexPassword; CreateServAcct $SiteAdmin "Default Site Admin" $pass}
            
$SiteAP = $AcctPrefix + "SP_Site_AP"
if(UserExists $SiteAP){$pass = Read-Host "User $SiteAP Exists! Please enter existing Password ";CreateServAcct $SiteAP "Default Site AppPool" $pass}
else{$pass = Get-ComplexPassword; CreateServAcct $SiteAP "Default Site AppPool" $pass}


    
if($AutoSPXML.Configuration.Install.SKU -eq "Standard" -or $AutoSPXML.Configuration.Install.SKU -eq "Enterprise")
{
    $mgdAcctNode = $AutoSPXML.SelectSingleNode("//Configuration/Farm/ManagedAccounts/ManagedAccount[@CommonName = 'portalapppool']")
    $mgdAcctNode.Username = $netbios + "\" + $SiteAP
    $mgdAcctNode.Password = "$pass"

    $portalAppNode = $AutoSPXML.Configuration.WebApplications.WebApplication | ?{$_.Type -eq "Portal"}
    $portalAppNode.applicationPoolAccount = $netbios + "\" + $SiteAP

    $mgdAcctNode = $AutoSPXML.SelectSingleNode("//Configuration/Farm/ManagedAccounts/ManagedAccount[@CommonName = 'mysiteapppool']")
    $mgdAcctNode.Username = $netbios + "\" + $SiteAP
    $mgdAcctNode.Password = "$pass"
         
    $mySiteAppNode = $AutoSPXML.Configuration.WebApplications.WebApplication | ?{$_.Type -eq "MySiteHost"}
    $mySiteAppNode.applicationPoolAccount = $netbios + "\" + $SiteAP
   
    $portalAppNode.SiteCollections.SiteCollection.Owner = $netbios + "\" + $SiteAdmin
    $mySiteAppNode.SiteCollections.SiteCollection.Owner = $netbios + "\" + $SiteAdmin
    
    $SearchAP = $AcctPrefix + "SP_Search_AP"
    if(UserExists $SearchAP){$pass = Read-Host "User $SearchAP Exists! Please enter existing Password ";CreateServAcct $SearchAP "Search AppPool" $pass}
    else{$pass = Get-ComplexPassword; CreateServAcct $SearchAP "Search AppPool" $pass}
    
    $mgdAcctNode = $AutoSPXML.SelectSingleNode("//Configuration/Farm/ManagedAccounts/ManagedAccount[@CommonName = 'searchapppool']")
    $mgdAcctNode.Username = $netbios + "\" + $SearchAP
    $mgdAcctNode.Password = "$pass"

    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.ApplicationPool.Account = $netbios + "\" + $SearchAP
    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.ApplicationPool.Password = "$pass"
    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.AdminComponent.ApplicationPool.Account = $netbios + "\" + $SearchAP
            
    $SearchServ = $AcctPrefix + "SP_SearchServ"
    if(UserExists $SearchServ){$pass = Read-Host "User $SearchServ Exists! Please enter existing Password ";CreateServAcct $SearchServ "Search Service" $pass}
    else{$pass = Get-ComplexPassword; CreateServAcct $SearchServ "Search Service" $pass}

    $mgdAcctNode = $AutoSPXML.SelectSingleNode("//Configuration/Farm/ManagedAccounts/ManagedAccount[@CommonName = 'searchservice']")
    $mgdAcctNode.Username = $netbios + "\" + $SearchServ
    $mgdAcctNode.Password = "$pass"

    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.Account = $netbios + "\" + $SearchServ
    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.Password = "$pass"
            
    $SearchCrawl = $AcctPrefix + "SP_SearchCrawl"
    if(UserExists $SearchCrawl){$pass = Read-Host "User $SearchCrawl Exists! Please enter existing Password ";CreateServAcct $SearchCrawl "Search Crawl" $pass}
    else{$pass = Get-ComplexPassword; CreateServAcct $SearchCrawl "Search Crawl" $pass}

    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.ContentAccessAccount = $netbios + "\" + $SearchCrawl
    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.ContentAccessAccountPassword = "$pass"
    
    $UserProfileImport = $AcctPrefix + "SP_UPS"
    if(UserExists $UserProfileImport){$pass = Read-Host "User $UserProfileImport Exists! Please enter existing Password ";CreateServAcct $UserProfileImport "User Profile Import" $pass}
    else{$pass = Get-ComplexPassword; CreateServAcct $UserProfileImport "User Profile Import" $pass}
    
    $AutoSPXML.Configuration.ServiceApps.UserProfileServiceApp.SyncConnectionAccount = $netbios + "\" + $UserProfileImport
    $AutoSPXML.Configuration.ServiceApps.UserProfileServiceApp.SyncConnectionAccountPassword = "$pass"
        
    $CacheReader = $AcctPrefix + "SP_CacheReader"
    if(UserExists $CacheReader){$pass = Read-Host "User $CacheReader Exists! Please enter existing Password ";CreateServAcct $CacheReader "Cache Reader" $pass}
    else{$pass = Get-ComplexPassword; CreateServAcct $CacheReader "Cache Reader" $pass}
    
    $AutoSPXML.Configuration.Farm.ObjectCacheAccounts.SuperReader = $netbios + "\" + $CacheReader
    
    $CacheUser = $AcctPrefix + "SP_CacheUser"
    if(UserExists $CacheUser){$pass = Read-Host "User $CacheUser Exists! Please enter existing Password ";CreateServAcct $CacheUser "Cache User" $pass}
    else{$pass = Get-ComplexPassword; CreateServAcct $CacheUser "Cache User" $pass}     
    
    $AutoSPXML.Configuration.Farm.ObjectCacheAccounts.SuperUser = $netbios + "\" + $CacheUser    
}
if($AutoSPXML.Configuration.Install.SKU -eq "Enterprise")
{
    $ExcelUser = $AcctPrefix + "SP_ExcelUser"
    if(UserExists $ExcelUser){$pass = Read-Host "User $ExcelUser Exists! Please enter existing Password ";CreateServAcct $ExcelUser "Excel User" $pass}
    else{$pass = Get-ComplexPassword; CreateServAcct $ExcelUser "Excel User" $pass}

    $AutoSPXML.Configuration.EnterpriseServiceApps.ExcelServices.UnattendedIDUser = $netbios + "\" + $ExcelUser
    $AutoSPXML.Configuration.EnterpriseServiceApps.ExcelServices.UnattendedIDPassword = $pass

    $VisioUser = $AcctPrefix + "SP_VisioUser"
    if(UserExists $VisioUser){$pass = Read-Host "User $VisioUser Exists! Please enter existing Password ";CreateServAcct $VisioUser "Visio User" $pass}
    else{$pass = Get-ComplexPassword; CreateServAcct $VisioUser "Visio User" $pass}

    $AutoSPXML.Configuration.EnterpriseServiceApps.VisioService.UnattendedIDUser = $netbios + "\" + $VisioUser
    $AutoSPXML.Configuration.EnterpriseServiceApps.VisioService.UnattendedIDPassword = $pass

    $PerfPointUser = $AcctPrefix + "SP_PerfPtUser"
    if(UserExists $PerfPointUser){$pass = Read-Host "User $PerfPointUser Exists! Please enter existing Password ";CreateServAcct $PerfPointUser "PerfPoint User" $pass}
    else{$pass = Get-ComplexPassword; CreateServAcct $PerfPointUser "PerfPoint User" $pass}

    $AutoSPXML.Configuration.EnterpriseServiceApps.PerformancePointService.UnattendedIDUser = $netbios + "\" + $PerfPointUser
    $AutoSPXML.Configuration.EnterpriseServiceApps.PerformancePointService.UnattendedIDPassword = $pass
}

$AutoSPXML.Save("$env:AutoSPPath\AutoSPInstallerInput.xml")

Write-Host -ForegroundColor Yellow "Service Accounts have been created. Please log in as "$netbios\$FarmAdmin" $FarmAdminPass"

break