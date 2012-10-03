#* FileName: AutoBuild.ps1
#* Version 1.0
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
#* the installation of SharePoint 2010
#*
#*============================================= 

Import-Module ./AutoBuild-Module -force

# Get current script execution path
[string]$curloc = get-location

$servicesToStart = "World Wide Web Publishing Service", "IIS Admin Service"

$FarmConfigXML = [xml](get-content "$curloc\FarmConfig.xml" -EA 0)

# Create Farm Config XML
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
		./ApplyTransforms.ps1
	}
	
    $FarmConfigXML.Save("$curloc\FarmConfig.xml")
}
$FarmConfigXML = [xml](get-content "$curloc\FarmConfig.xml" -EA 0)

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

$configxml.Save("$curloc\$ConfigFile")

# Set System PreReqs
./SetSystemPreReqs.ps1

# Region Create AD Service Accounts
$serviceAcctLog = get-content "$curloc\ServiceAccounts.txt" -EA 0
if($serviceAcctLog -eq $null)
{
    ./CreateADAccounts.ps1 $FarmConfigXML
    $FarmConfigXML = [xml](get-content "$curloc\FarmConfig.xml" -EA 0)

    $FarmAdminNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type = 'Farm Admin']")
    $FarmAdmin = $FarmAdminNode.Name
    $FarmAdminPass = $FarmAdminNode.Password
	
	$FarmAcctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type = 'Farm Connect']")
	$FarmAcct = $FarmAcctNode.Name
	
	$netBios = Get-DomainNetBios
	
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

if($FarmConfigXML.Customer.Farm.BuildVersion -like "14*")
{
    # Install 2010 Bits
    ./Install2010Bits.ps1
}
elseif($FarmConfigXML.Customer.Farm.BuildVersion -like "15*")
{
     # Install 2013 Bits
    ./Install2013Bits.ps1
}

# Make sure necessary windows services are started and set to Automatic
foreach ($serviceToStart in $servicesToStart)
{
    Start-Service $serviceToStart
}

# Create or Join Existing Farm
./ConfigFarm.ps1

#Prep the SharePoint Server by Securing Resources and Installing Services
## Secure resources
Write-Host -ForegroundColor Cyan " - Securing Resources..."
Initialize-SPResourceSecurity
## Install Services
Write-Host -ForegroundColor Cyan " - Installing Services..."
Install-SPService
	
# Get the Central Admin Server Name
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
