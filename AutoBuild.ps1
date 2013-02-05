#* FileName: AutoBuild.ps1
#* Version 3.0
#*=============================================
#* Script Name: [AutoBuild.ps1]
#* Created: [6/2/2011]
#* Author: Corey Burke
#* Company: Rackspace hosting
#* Email: corey.burke@rackspace.com
#* Web: http://blog.sharepoint-voodoo.net
#* Reqrmnts:
#* Keywords:
#*=============================================
#* Purpose: Master Control script for controlling
#* the installation of SharePoint 2010 and 2013
#*
#*============================================= 

Import-Module ./AutoBuild-Module -force
Import-Module ServerManager

# Get current script execution path
[string]$curloc = get-location

# Check that pre-requisite Roles have been installed into Windows
Add-WindowsFeature "Web-Default-Doc", "Web-Dir-Browsing", "Web-Dir-Browsing", "Web-Static-Content", "Web-Http-Redirect", "Web-Http-Logging", "Web-Log-Libraries", "Web-Request-Monitor", "Web-Http-Tracing", "Web-Stat-Compression", "Web-Dyn-Compression", "Web-Filtering", "Web-Basic-Auth", "Web-Client-Auth", "Web-Digest-Auth", "Web-Cert-Auth", "Web-IP-Security", "Web-Url-Auth", "Web-Windows-Auth", "Web-Asp-Net", "Web-ISAPI-Ext", "Web-ISAPI-Filter", "Web-Net-Ext", "Web-Mgmt-Console", "Web-Metabase", "Web-Lgcy-Scripting", "Web-WMI", "Web-Scripting-Tools", "SMTP-Server", "PowerShell-ISE"

# Ensure necessary Windows Services are started
$servicesToStart = "World Wide Web Publishing Service", "IIS Admin Service"

# Make sure necessary windows services are started and set to Automatic
foreach ($serviceToStart in $servicesToStart)
{
    Start-Service $serviceToStart
}

# Get the Farm Config XML file
$FarmConfigXML = [xml](get-content "$curloc\FarmConfig.xml" -EA 0)

# Create Farm Config XML if it does not exist
if ($FarmConfigXML -eq $null)
{
    ./SetVars.ps1    
}
else
{
    # Check/Set the Installation Key
    if($FarmConfigXML.Customer.Farm.ProductKey -eq $null)
    {   
        $ProductKey = Read-Host "Enter the Product Installation Key "
        $FarmConfigXML.Customer.Farm.SetAttribute("ProductKey", $ProductKey)
    }
    else
    {
        $ProductKey = $FarmConfigXML.Customer.Farm.ProductKey
    }

    if($FarmConfigXML.Customer.Farm.Transformed -eq $null)
	{
		# If the Farm config is from an audit of another Farm it needs to be converted to match the new farm's topology
        ./ApplyTransforms.ps1
	}
	
    #Save the Farm Config
    $FarmConfigXML.Save("$curloc\FarmConfig.xml")
}
# Get a fresh copy of the Farm config XML file
$FarmConfigXML = [xml](get-content "$curloc\FarmConfig.xml" -EA 0)

#Get the Product Key from the Farm Config XML file and set the PID value in the config.cml in the root of the installation media
$ProductKey = $FarmConfigXML.Customer.Farm.ProductKey
$ConfigFile = "config.xml"
$configxml = [xml](get-content "$curloc\$ConfigFile")
$PKeyNode=$configxml.selectSingleNode("//Configuration/PIDKEY")
if($ProductKey -eq $null)
{	
	[Void]$PKeyNode.ParentNode.RemoveChild($PKeyNode)
}
else
{
	$PKeyNode.SetAttribute('Value',$ProductKey)
}

#Save the config.xml changes
$configxml.Save("$curloc\$ConfigFile")

# Set System PreReqs
./SetSystemPreReqs.ps1

# Region Create AD Service Accounts
$serviceAcctLog = get-content "$curloc\ServiceAccounts.txt" -EA 0
if($serviceAcctLog -eq $null)
{
    #Launch AD Account Creation Script
    ./CreateADAccounts.ps1 $FarmConfigXML

    #Refresh the FarmConfigXML variable
    $FarmConfigXML = [xml](get-content "$curloc\FarmConfig.xml" -EA 0)

    #Get Farm Admin Creds from XML
    $FarmAdminNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type = 'Farm Admin']")
    $FarmAdmin = $FarmAdminNode.Name
    $FarmAdminPass = $FarmAdminNode.Password
	
    #Get Farm Connect Creds from XML
	$FarmAcctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type = 'Farm Connect']")
	$FarmAcct = $FarmAcctNode.Name
	
    #Get netbios for current domain
	$netBios = (Get-LocalLogonInformation).DomainShortName
	
	# Get the DB Server Name
	$dbServer = Get-ServerNameByService $FarmConfigXML "Microsoft SharePoint Foundation Database"

	# Add SQL Permissions for Farm Admin
	Set-SQLAccess "$netBios\$FarmAdmin" "SysAdmin" $dbServer

	#Add SQL Permissions for Farm Connect Account
	Set-SQLAccess "$netBios\$FarmAcct" "SecurityAdmin" $dbServer
	Set-SQLAccess "$netBios\$FarmAcct" "DBCreator" $dbServer
	
    Write-Host -ForegroundColor Yellow "Service Accounts have been created. Please log in as $FarmAdmin $FarmAdminPass"

    break    
}
# End Region Create AD Service Accounts


# Region Install SharePoint binaries
./InstallSPBits.ps1
# End Region

# Create or Join Existing Farm
./ConfigFarm.ps1

#Prep the SharePoint Server by Securing Resources and Installing Services
## Secure resources
Write-Host -ForegroundColor Cyan " - Securing Resources..."
Initialize-SPResourceSecurity
## Install Services
Write-Host -ForegroundColor Cyan " - Installing Services..."
Install-SPService
	
# Get the Central Admin Server Name from the FarmConfigXML
$caServer = Get-ServerNameByService $FarmConfigXML "Central Administration"
	
$hostName = $env:COMPUTERNAME
if($caServer -eq $hostName)    
{
    
    if(-not (Get-SPServiceInstance | ?{$_.TypeName -eq "Central Administration" -and $_.Status -eq "Online"}))
	{
		# Provision Central Admin
	    ./ProvCA.ps1
    }
}  

#Start SharePoint Services for the current server
./StartServices.ps1

#Provision Service Applications
./ProvSA.ps1

# Provision Web Applications
./ProvWebApps.ps1

#Set Post-Configuration Settings
./SetPostConfig.ps1

Write-Host -ForegroundColor Red "Build Complete!"
