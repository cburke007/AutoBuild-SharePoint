#########################################################################################################
# BEGIN FUNCTIONS
#########################################################################################################

function CreateADUser
{
	param([string]$AccountName, [string]$type, [string]$Password)
    
    #Region Create AD Service Accounts
    #Get AD Information
    #Connect to current domain
    $dom = Get-ADDomain
    #Construct a valid UPN
    $UPN = "@" + $dom.DNSRoot
   
    #Check to see if the Service Accounts OU already exists
    $ouSA = "OU=Service Accounts," + $dom.DistinguishedName
    $ouSP = "OU=SharePoint," + $ouSA
    $ouSAExists = Get-ADOrganizationalUnit -Filter {distinguishedname -eq $ouSA}

    #If the Service Accounts does not exist, create both OU's
    if ([string]::IsNullOrEmpty($ouSAExists))
    {
        New-ADOrganizationalUnit -Name "Service Accounts" -Path $dom.DistinguishedName | Out-Null
        
        New-ADOrganizationalUnit -Name "SharePoint" -Path $ouSA | Out-Null
    }
    #Otherwise create just the SharePoint OU
    else
    {
        #Check to see if the SharePoint OU already exists
        $ouSP = "OU=SharePoint,OU=Service Accounts," + $dom.DistinguishedName
        $ouSPExists = Get-ADOrganizationalUnit -Filter {distinguishedname -eq $ouSP}

        #If the SharePoint OU does not exist, Create it
        if ([string]::IsNullOrEmpty($ouSPExists))
        {
            New-ADOrganizationalUnit -Name "SharePoint" -Path $ouSA | Out-Null
        }  
    }
    
    #Check to see if the user already exists
    $UserExists = Get-ADUser -filter {SamAccountName -eq $AccountName}
      
    
    #If the user exists do nothing otherwise create the new user account
    if(![string]::IsNullOrEmpty($UserExists))
    {        
        Write-Output "User $AccountName exists! Skipping..."      
    }
    else
    {                     
        $userPrincipalName = $AccountName + $UPN
        # User Creation
        $newUser = New-ADUser $AccountName -PassThru -Path $ouSP -SamAccountName $AccountName -UserPrincipalName $userPrincipalName -DisplayName $AccountName -GivenName $AccountName -Enabled $True -PasswordNeverExpires $True -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force)

        if($type -eq "Farm Admin")
        {
            Add-ADGroupMember -Identity "Domain Admins" -Member $newUser
        }
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
    param($passLength)

    $segLength = [System.Math]::Floor($passLength / 4)
    $remainder = $passLength % 4 + $segLength + 1

    $password = Get-RandomPassword -length $segLength -characters 'abcdefghiklmnprstuvwxyz'
    $password += Get-RandomPassword -length $segLength -characters '123456789'
    $password += Get-RandomPassword -length $segLength -characters 'ABCDEFGHKLMNPRSTUVWXYZ'
    $password += Get-RandomPassword -length $remainder -characters '#*+()$!?'

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
		break
	}	
	$SqlCmd.Connection.Close()
}
#EndRegion

function UserExists
{
    param([string]$uname)
    
    $UserExists = Get-ADUser -filter {SamAccountName -eq $uname}
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

$RootDSE = Get-ADRootDSE
$PasswordPolicy = Get-ADObject $RootDSE.defaultNamingContext -Property minPwdAge, maxPwdAge, minPwdLength, pwdHistoryLength, pwdProperties
if($PasswordPolicy.minPwdLength -lt 12){$passlength = 12}
else{$passLength = $PasswordPolicy.minPwdLength}

$netbios = (Get-ADDomain).NetBiosName

$text = "$env:dp0\COREInfo.txt"

"<b>Sharepoint Credentials:</b>" | out-file "$text" -Append

$AutoSPXML = [xml](get-content "$env:AutoSPPath\AutoSPInstallerInput.xml" -EA 0)

if([string]::IsNullOrEmpty($AutoSPXML.Configuration.Farm.Database.DBAlias.DBPort))
{
    $dbServer = $AutoSPXML.Configuration.Farm.Database.DBAlias.DBInstance
}
else{$dbServer = [string]$AutoSPXML.Configuration.Farm.Database.DBAlias.DBInstance + "," + [string]$AutoSPXML.Configuration.Farm.Database.DBAlias.DBPort}

$prefix = $AutoSPXML.Configuration.SAPrefix
if($prefix -eq $null -or $prefix -eq "")
{
    $AcctPrefix = ""
}
else{$AcctPrefix = $prefix + "-"}

# Set Farm Service Account Names
Write-Host -ForegroundColor Yellow "Creating Service Accounts..."

$customSA = Read-Host "Do you wish to use custom service accounts (y/N - Default = N)? "
$customPWLength = Read-Host "Do you wish to use a custom password length (y/N - Default = $passLength)? "

if($customPWLength -eq "Y" -or $customPWLength -eq "y")
{
    $input = Read-Host "Please enter the password length "
    $passLength = $input
}

if($customSA -eq "Y" -or $customSA -eq "y")
{
    $input = Read-Host "Please enter the Farm Admin Account "
    $FarmAdmin = $AcctPrefix + $input
}
else{$FarmAdmin = $AcctPrefix + "SP_Admin"}
if(UserExists $FarmAdmin){$pass = Read-Host "User $FarmAdmin Exists! Please enter existing Password "}
else{$pass = Get-ComplexPassword $passLength; CreateADUser $FarmAdmin "Farm Admin" $pass}
$FarmAdminPass = $pass
   
$UserLogEntry = "Farm Admin" + " = " + $netbios + "\" + $FarmAdmin + " " + $pass    
$UserLogEntry | out-file "$text" -append

$AutoSPXML.Configuration.Install.AutoAdminLogon.Enable = "true"
$AutoSPXML.Configuration.Install.AutoAdminLogon.Password = "$pass"

if($AutoSPXML.Configuration.Install.SKU -eq "Foundation")
{    
    $AutoSPXML.Configuration.Farm.ObjectCacheAccounts.SuperReader = $netbios + "\" + $FarmAdmin
    
    $AutoSPXML.Configuration.Farm.ObjectCacheAccounts.SuperUser = $netbios + "\" + $FarmAdmin
}

# Add SQL Permissions for Farm Admin
Set-SQLAccess "$netBios\$FarmAdmin" "SysAdmin" $dbServer
            
if($customSA -eq "Y" -or $customSA -eq "y")
{
    $input = Read-Host "Please enter the Farm Connect Account "
    $FarmAcct = $AcctPrefix + $input
}
else{$FarmAcct = $AcctPrefix + "SP_Connect"}
if(UserExists $FarmAcct){$pass = Read-Host "User $FarmAcct Exists! Please enter existing Password "}
else{$pass = Get-ComplexPassword $passLength; CreateADUser $FarmAcct "Farm Connect" $pass}
   
$UserLogEntry = "Farm Account" + " = " + $netbios + "\" + $FarmAcct + " " + $pass    
$UserLogEntry | out-file "$text" -append

if($AutoSPXML.Configuration.Install.SKU -eq "Foundation")
{
    $mgdAcctNode = $AutoSPXML.SelectSingleNode("//Configuration/Farm/ManagedAccounts/ManagedAccount[@CommonName = 'searchservice']")
    $mgdAcctNode.Username = $netbios + "\" + $FarmAcct
    $mgdAcctNode.Password = "$pass"

    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.Account = $netbios + "\" + $FarmAcct
    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.Password = "$pass"
}

$AutoSPXML.Configuration.Farm.Account.Username = $netbios + "\" + $FarmAcct
$AutoSPXML.Configuration.Farm.Account.Password = "$pass"

#Add SQL Permissions for Farm Connect Account
Set-SQLAccess "$netBios\$FarmAcct" "SecurityAdmin" $dbServer
Set-SQLAccess "$netBios\$FarmAcct" "DBCreator" $dbServer
            
if($customSA -eq "Y" -or $customSA -eq "y")
{
    $input = Read-Host "Please enter the Service App Pool Account "
    $ServiceAppAP = $AcctPrefix + $input
}
else{$ServiceAppAP = $AcctPrefix + "SP_SA_AP"}
if(UserExists $ServiceAppAP){$pass = Read-Host "User $ServiceAppAP Exists! Please enter existing Password "}
else{$pass = Get-ComplexPassword $passLength; CreateADUser $ServiceAppAP "Default SA AppPool" $pass}
   
$UserLogEntry = "Default SA AppPool" + " = " + $netbios + "\" + $ServiceAppAP + " " + $pass    
$UserLogEntry | out-file "$text" -append

$mgdAcctNode = $AutoSPXML.SelectSingleNode("//Configuration/Farm/ManagedAccounts/ManagedAccount[@CommonName = 'spservice']")
$mgdAcctNode.Username = $netbios + "\" + $ServiceAppAP
$mgdAcctNode.Password = "$pass" 

if($customSA -eq "Y" -or $customSA -eq "y")
{
    $input = Read-Host "Please enter the Site Admin Account "
    $SiteAdmin = $AcctPrefix + $input
}
else{$SiteAdmin = $AcctPrefix + "Site_Admin"}
if(UserExists $SiteAdmin){$pass = Read-Host "User $SiteAdmin Exists! Please enter existing Password "}
else{$pass = Get-ComplexPassword $passLength; CreateADUser $SiteAdmin "Default Site Admin" $pass}

$UserLogEntry = "Default Site Admin" + " = " + $netbios + "\" + $SiteAdmin + " " + $pass    
$UserLogEntry | out-file "$text" -append
            
if($customSA -eq "Y" -or $customSA -eq "y")
{
    $input = Read-Host "Please enter the Site App Pool Account "
    $SiteAP = $AcctPrefix + $input
}
else{$SiteAP = $AcctPrefix + "SP_Site_AP"}
if(UserExists $SiteAP){$pass = Read-Host "User $SiteAP Exists! Please enter existing Password "}
else{$pass = Get-ComplexPassword $passLength; CreateADUser $SiteAP "Default Site AppPool" $pass}

$UserLogEntry = "Default Site AppPool" + " = " + $netbios + "\" + $SiteAP + " " + $pass    
$UserLogEntry | out-file "$text" -append
 
$mgdAcctNode = $AutoSPXML.SelectSingleNode("//Configuration/Farm/ManagedAccounts/ManagedAccount[@CommonName = 'Portal']")
$mgdAcctNode.Username = $netbios + "\" + $SiteAP
$mgdAcctNode.Password = "$pass"

$portalAppNode = $AutoSPXML.Configuration.WebApplications.WebApplication | ?{$_.Type -eq "Portal"}
$portalAppNode.SiteCollections.SiteCollection.Owner = $netbios + "\" + $SiteAdmin

if($AutoSPXML.Configuration.Install.SKU -eq "Foundation")
{
    $mySiteNode = $AutoSPXML.Configuration.WebApplications.WebApplication | ?{$_.Type -eq "MySiteHost"}
	[Void]$mySiteNode.ParentNode.RemoveChild($mySiteNode)

    $mgdAcctNode = $AutoSPXML.Configuration.Farm.ManagedAccounts.ManagedAccount | ?{$_.CommonName -eq "MySiteHost"}
	[Void]$mgdAcctNode.ParentNode.RemoveChild($mgdAcctNode)

    $mgdAcctNode = $AutoSPXML.Configuration.Farm.ManagedAccounts.ManagedAccount | ?{$_.CommonName -eq "searchapppool"}
	[Void]$mgdAcctNode.ParentNode.RemoveChild($mgdAcctNode)
}
 
    
if($AutoSPXML.Configuration.Install.SKU -eq "Standard" -or $AutoSPXML.Configuration.Install.SKU -eq "Enterprise")
{
    $mgdAcctNode = $AutoSPXML.SelectSingleNode("//Configuration/Farm/ManagedAccounts/ManagedAccount[@CommonName = 'MySiteHost']")
    $mgdAcctNode.Username = $netbios + "\" + $SiteAP
    $mgdAcctNode.Password = "$pass"
         
    $mySiteAppNode = $AutoSPXML.Configuration.WebApplications.WebApplication | ?{$_.Type -eq "MySiteHost"}
    $mySiteAppNode.SiteCollections.SiteCollection.Owner = $netbios + "\" + $SiteAdmin
    
    if($customSA -eq "Y" -or $customSA -eq "y")
    {
        $input = Read-Host "Please enter the Search Service Account "
        $SearchServ = $AcctPrefix + $input
    }
    else{$SearchServ = $AcctPrefix + "SP_SearchSvc"}
    if(UserExists $SearchServ){$pass = Read-Host "User $SearchServ Exists! Please enter existing Password "}
    else{$pass = Get-ComplexPassword $passLength; CreateADUser $SearchServ "Search Service" $pass}
    
    $UserLogEntry = "Search Service" + " = " + $netbios + "\" + $SearchServ + " " + $pass    
    $UserLogEntry | out-file "$text" -append
 
    $mgdAcctNode = $AutoSPXML.SelectSingleNode("//Configuration/Farm/ManagedAccounts/ManagedAccount[@CommonName = 'SearchService']")
    $mgdAcctNode.Username = $netbios + "\" + $SearchServ
    $mgdAcctNode.Password = "$pass"
        
    if($customSA -eq "Y" -or $customSA -eq "y")
    {
        $input = Read-Host "Please enter the Search Crawl Account "
        $SearchCrawl = $AcctPrefix + $input
    }
    else{$SearchCrawl = $AcctPrefix + "SP_Crawl"}
    if(UserExists $SearchCrawl){$pass = Read-Host "User $SearchCrawl Exists! Please enter existing Password "}
    else{$pass = Get-ComplexPassword $passLength; CreateADUser $SearchCrawl "Search Crawl" $pass}
    
    $UserLogEntry = "Search Crawl" + " = " + $netbios + "\" + $SearchCrawl + " " + $pass    
    $UserLogEntry | out-file "$text" -append
 
    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.ContentAccessAccount = $netbios + "\" + $SearchCrawl
    $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.ContentAccessAccountPassword = "$pass"
    
    if($customSA -eq "Y" -or $customSA -eq "y")
    {
        $input = Read-Host "Please enter the UPS Sync Connection Account "
        $UserProfileImport = $AcctPrefix + $input
    }
    else{$UserProfileImport = $AcctPrefix + "SP_UPS"}
    if(UserExists $UserProfileImport){$pass = Read-Host "User $UserProfileImport Exists! Please enter existing Password "}
    else{$pass = Get-ComplexPassword $passLength; CreateADUser $UserProfileImport "User Profile Import" $pass}
    
    $UserLogEntry = "User Profile Import" + " = " + $netbios + "\" + $UserProfileImport + " " + $pass    
    $UserLogEntry | out-file "$text" -append
 
    $AutoSPXML.Configuration.ServiceApps.UserProfileServiceApp.SyncConnectionAccount = $netbios + "\" + $UserProfileImport
    $AutoSPXML.Configuration.ServiceApps.UserProfileServiceApp.SyncConnectionAccountPassword = "$pass"
        
    if($customSA -eq "Y" -or $customSA -eq "y")
    {
        $input = Read-Host "Please enter the Cache Reader Account "
        $CacheReader = $AcctPrefix + $input
    }
    else{$CacheReader = $AcctPrefix + "SP_CacheRead"}
    if(UserExists $CacheReader){$pass = Read-Host "User $CacheReader Exists! Please enter existing Password "}
    else{$pass = Get-ComplexPassword $passLength; CreateADUser $CacheReader "Cache Reader" $pass}
    
    $UserLogEntry = "Cache Reader" + " = " + $netbios + "\" + $CacheReader + " " + $pass    
    $UserLogEntry | out-file "$text" -append
 
    $AutoSPXML.Configuration.Farm.ObjectCacheAccounts.SuperReader = $netbios + "\" + $CacheReader
    
    if($customSA -eq "Y" -or $customSA -eq "y")
    {
        $input = Read-Host "Please enter the Cache User Account "
        $CacheUser = $AcctPrefix + $input
    }
    else{$CacheUser = $AcctPrefix + "SP_CacheUser"}
    if(UserExists $CacheUser){$pass = Read-Host "User $CacheUser Exists! Please enter existing Password "}
    else{$pass = Get-ComplexPassword $passLength; CreateADUser $CacheUser "Cache User" $pass}     
    
    $UserLogEntry = "Cache User" + " = " + $netbios + "\" + $CacheUser + " " + $pass    
    $UserLogEntry | out-file "$text" -append
 
    $AutoSPXML.Configuration.Farm.ObjectCacheAccounts.SuperUser = $netbios + "\" + $CacheUser    
}
if($AutoSPXML.Configuration.Install.SKU -eq "Enterprise")
    {
        if($customSA -eq "Y" -or $customSA -eq "y")
    {
        $input = Read-Host "Please enter the Excel Unattended ID Account "
        $ExcelUser = $AcctPrefix + $input
    }
    else{$ExcelUser = $AcctPrefix + "SP_ExcelID"}
    if(UserExists $ExcelUser){$pass = Read-Host "User $ExcelUser Exists! Please enter existing Password "}
    else{$pass = Get-ComplexPassword $passLength; CreateADUser $ExcelUser "Excel User" $pass}
    
    $UserLogEntry = "Excel ID" + " = " + $netbios + "\" + $ExcelUser + " " + $pass    
    $UserLogEntry | out-file "$text" -append
 
    $uid = $netbios + "\" + $ExcelUser

    $AutoSPXML.Configuration.EnterpriseServiceApps.ExcelServices.UnattendedIDUser = [string]$uid
    $AutoSPXML.Configuration.EnterpriseServiceApps.ExcelServices.UnattendedIDPassword = [string]$pass

    if($customSA -eq "Y" -or $customSA -eq "y")
    {
        $input = Read-Host "Please enter the Visio Unattended ID Account "
        $VisioUser = $AcctPrefix + $input
    }
    else{$VisioUser = $AcctPrefix + "SP_VisioID"}
    if(UserExists $VisioUser){$pass = Read-Host "User $VisioUser Exists! Please enter existing Password "}
    else{$pass = Get-ComplexPassword $passLength; CreateADUser $VisioUser "Visio User" $pass}
    
    $UserLogEntry = "Visio ID" + " = " + $netbios + "\" + $VisioUser + " " + $pass    
    $UserLogEntry | out-file "$text" -append
 
    $uid = $netbios + "\" + $VisioUser

    $AutoSPXML.Configuration.EnterpriseServiceApps.VisioService.UnattendedIDUser = [string]$uid
    $AutoSPXML.Configuration.EnterpriseServiceApps.VisioService.UnattendedIDPassword = [string]$pass

    if($customSA -eq "Y" -or $customSA -eq "y")
    {
        $input = Read-Host "Please enter the PerformancePoint Unattended ID Account "
        $PerfPointUser = $AcctPrefix + $input
    }
    else{$PerfPointUser = $AcctPrefix + "SP_PerfPtID"}
    if(UserExists $PerfPointUser){$pass = Read-Host "User $PerfPointUser Exists! Please enter existing Password "}
    else{$pass = Get-ComplexPassword $passLength; CreateADUser $PerfPointUser "PerfPoint User" $pass}
    
    $UserLogEntry = "PerfPoint ID" + " = " + $netbios + "\" + $PerfPointUser + " " + $pass    
    $UserLogEntry | out-file "$text" -append
 
    $uid = $netbios + "\" + $PerfPointUser

    $AutoSPXML.Configuration.EnterpriseServiceApps.PerformancePointService.UnattendedIDUser = [string]$uid
    $AutoSPXML.Configuration.EnterpriseServiceApps.PerformancePointService.UnattendedIDPassword = [string]$pass
}

# Complete CORE AD logging file
"" | out-file "$text" -Append
"<b>Site URLs:</b> " | out-file "$text" -Append
"" | out-file "$text" -Append
"Content Database Names: " | out-file "$text" -Append
"SSRS Integration? " | out-file "$text" -Append
"<b>Sharepoint Products/Add-ons installed:</b> " | out-file "$text" -Append

$AutoSPXML.Save("$env:AutoSPPath\AutoSPInstallerInput.xml")

Write-Host -ForegroundColor Yellow "Service Accounts have been created. Please log in as "$netbios\$FarmAdmin" $FarmAdminPass"

break