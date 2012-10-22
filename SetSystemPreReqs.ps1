Import-Module ./AutoBuild-Module

$FarmConfigXML = [xml](get-content "$curloc\FarmConfig.xml" -EA 0)

$netBios = (Get-LocalLogonInformation).DomainShortName

# Get OS Version
$QueryOS = Gwmi Win32_OperatingSystem
$QueryOS = $QueryOS.Version 
If ($QueryOS.contains("6.1")) {$OS = "Win2008R2"}
ElseIf ($QueryOS.contains("6.0")) {$OS = "Win2008"}
Write-Host -ForegroundColor Cyan "- Running on $OS."

# Disable Loopback Check
$LsaPath = "HKLM:\System\CurrentControlSet\Control\Lsa"
$LsaPathValue = Get-ItemProperty -path $LsaPath
If (-not ($LsaPathValue.DisableLoopbackCheck -eq "1"))
{
    New-ItemProperty $LsaPath -Name "DisableLoopbackCheck" -value "1" -PropertyType dword -Force | Out-Null
}

# Create MoM/SCOMM Key
$RackspacePath = "HKLM:\SOFTWARE\RACKSPACE"
$MoMPath = "HKLM:\SOFTWARE\RACKSPACE\MAC"

# Create Rackspace key if it does not exist
if (-not (Test-Path $RackspacePath)){md $RackspacePath > $null}

# Create MAC Key if it does not exist
if (-not (Test-Path $MoMPath)){md $MoMPath > $null}

$MoMPathValue = Get-ItemProperty -path $MoMPath
If (-not ($MoMPathValue.ManagedSharepoint -eq "1"))
{
    New-ItemProperty HKLM:\SOFTWARE\RACKSPACE\MAC -Name "ManagedSharepoint" -value "1" -PropertyType dword -Force | Out-Null
}

# Create SQL Alias
$dbServer = $FarmConfigXML.Customer.Farm.FarmDBServer
$LsaPath = "HKLM:\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo"
$LsaPathValue = Get-ItemProperty -path $LsaPath
If ($LsaPathValue.SharePointSQL -eq $null)
{
    New-ItemProperty $LsaPath -Name "SharePointSQL" -value "DBMSSOCN,$dbServer" -PropertyType String -Force | Out-Null
}

$FarmAcctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type = 'Farm Connect']")
$FarmAcct = $FarmAcctNode.Name

# Add Farm Account as a local admin temporarily
Write-Host -ForegroundColor Cyan "- Adding $FarmAcct to local Administrators (for User Profile Sync)..."

try
{
    ([ADSI]"WinNT://$env:COMPUTERNAME/Administrators,group").Add("WinNT://$netBios/$FarmAcct")
	If (-not $?) {throw}
}
catch {Write-Host -ForegroundColor Cyan " - $FarmAcct is already an Administrator, continuing."}

$FarmAdminNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type = 'Farm Admin']")
$FarmAdmin = $FarmAdminNode.Name

# Add Farm Admin as a local admin
Write-Host -ForegroundColor Cyan "- Adding $FarmAdmin to local Administrators..."

try
{
    ([ADSI]"WinNT://$env:COMPUTERNAME/Administrators,group").Add("WinNT://$netBios/$FarmAdmin")
	If (-not $?) {throw}
}
catch {Write-Host -ForegroundColor Cyan " - $FarmAdmin is already an Administrator, continuing."}
