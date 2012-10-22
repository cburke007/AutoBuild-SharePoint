# Get current script execution path
[string]$curloc = get-location

#Region Global Functions

#Function Suspend-Script
function Suspend-Script
{
	#From http://www.microsoft.com/technet/scriptcenter/resources/pstips/jan08/pstip0118.mspx
	Write-Host -ForegroundColor Cyan "Press any key to exit..."
	$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
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

#Function to start Windows Services
function Start-Service
{
    param([string]$serviceName)
    
    $service = get-service $serviceName
    
    if($service.Status -ne "Running")
    { 
        Write-Host -ForegroundColor Cyan " - Starting $serviceName..."
        Set-Service $service -startuptype automatic
        Start-Service $service        
               
        ## Wait
		Write-Host -ForegroundColor Cyan " - Waiting for $serviceName to start" -NoNewline
		While ($service.Status -ne "Running") 
		{
    		Write-Host -ForegroundColor Cyan "." -NoNewline
    		sleep 1
    		$service = get-service $serviceName
		}
		Write-Host -BackgroundColor Blue -ForegroundColor Black "Started!"
    }
    else
    {
        Write-Host -ForegroundColor Cyan " - $serviceName is already running"
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

function Get-ServerNameByService
{
    param([xml]$FarmConfigXML,[string]$serviceName)
    
	$servers = @()
	
    $serversNode = $FarmConfigXML.Customer.Farm.FarmServers.Server
    foreach($serverNode in $serversNode)
    {
        $servicesNode = $serverNode.Services.Service
        
        foreach($serviceNode in $servicesNode)
        {
            if($serviceNode.Name -eq "$serviceName")
            {
                $servers = $servers + $serverNode.Name
            }
        }
    }
	$servers
}

function New-ADUser
{
	param([string]$AccountName, [string]$Password)
    
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
}


#EndRegion Global Functions

#Export Module Members
Export-ModuleMember Suspend-Script, Get-LocalLogonInformation, Start-Service, Get-RandomPassword, Get-RandomText, Get-ComplexPassword, Set-SQLAccess, New-ADUser, Get-ServerNameByService
