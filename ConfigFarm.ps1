Import-Module ./AutoBuild-Module -force

$FarmConfigXML = [xml](get-content "$curloc\FarmConfig.xml" -EA 0)

# Get the DB Server Name
$dbServer = Get-ServerNameByService $FarmConfigXML "Microsoft SharePoint Foundation Database"

# Set common variables for install
$FarmAcctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type='Farm Connect']")
$FarmAcct = $FarmAcctNode.Name
$netBios = (Get-LocalLogonInformation).DomainShortName
$domFarmAcct = "$netBios\$FarmAcct"
$txtFarmAcctPWD = $FarmAcctNode.Password
$FarmAcctPWD = ConvertTo-SecureString "$txtFarmAcctPWD" -asplaintext -force
$Cred_Farm = New-Object System.Management.Automation.PsCredential $domFarmAcct,$FarmAcctPWD
$DBPrefix = $FarmConfigXML.Customer.Farm.DBPrefix
$ConfigDB = $DBPrefix + "SharePoint_Config"
$CentralAdminContentDB = $DBPrefix + "SharePoint_AdminContent"
$FarmPassPhrase = $FarmConfigXML.Customer.Farm.Passphrase
$SecPhrase = ConvertTo-SecureString "$FarmPassPhrase" -asplaintext -force

#Region Configure First Farm or Join an Existing one
Write-Host -ForegroundColor Cyan "- Creating & configuring (or joining) farm:"
Write-Host -ForegroundColor Cyan " - Enabling SP PowerShell cmdlets..."

If ((Get-PsSnapin |?{$_.Name -eq "Microsoft.SharePoint.PowerShell"})-eq $null)
{
   	$PSSnapin = Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue | Out-Null
}

Start-SPAssignment -Global | Out-Null

## Look for an existing farm and join the farm if not already joined, or create a new farm
try
{
	Write-Host -ForegroundColor Cyan " - Checking farm membership for $env:COMPUTERNAME in `"$ConfigDB`"..."
	$SPFarm = Get-SPFarm | Where-Object {$_.Name -eq $ConfigDB} -ErrorAction SilentlyContinue
}
catch {""}
If ($SPFarm -eq $null)
{
	try
	{
		Write-Host -ForegroundColor Cyan " - Attempting to join farm on `"$ConfigDB`"..."
		$ConnectFarm = Connect-SPConfigurationDatabase -DatabaseName "$ConfigDB" -Passphrase $SecPhrase -DatabaseServer "$dbServer" -ErrorAction SilentlyContinue
		If (-not $?)
		{
			Write-Host -ForegroundColor Cyan " - No existing farm found.`n - Creating config database `"$ConfigDB`"..."
			## Waiting a few seconds seems to help with the Connect-SPConfigurationDatabase barging in on the New-SPConfigurationDatabase command; not sure why...
			sleep 5
			New-SPConfigurationDatabase –DatabaseName "$ConfigDB" –DatabaseServer "$dbServer" –AdministrationContentDatabaseName "$CentralAdminContentDB" –Passphrase $SecPhrase –FarmCredentials $Cred_Farm
			If (-not $?) {throw}
			Else {$FarmMessage = "- Done creating configuration database for farm."}
		}
		Else {$FarmMessage = "- Done joining farm."}
	#Write-Host -ForegroundColor Cyan " - Creating Version registry value (workaround for apparent bug in PS-based install)"
	#New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\14.0\' -Name Version -Value '14.0.0.5114' -ErrorAction SilentlyContinue | Out-Null
	}
	catch 
	{
		Write-Output $_
		Suspend-Script
		break
	}
}
Else {$FarmMessage = "- $env:COMPUTERNAME is already joined to farm on `"$ConfigDB`"."}
Write-Host -ForegroundColor Cyan $FarmMessage
#END Region Configure First Farm or Join an Existing one
