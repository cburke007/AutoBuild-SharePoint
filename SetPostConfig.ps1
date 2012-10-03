#Region HealthRules
function DisableHealthRule
{
	param([string]$title)
	
	# Get the List of Health Analyzer Rules
	$haRulesList = [Microsoft.SharePoint.Administration.Health.SPHealthRulesList]::Local.Items

	# Get and Disable the Server Farm Account Rule
	$haRule = $haRulesList | ? {$_.Title -eq $title}
	if($haRule["HealthRuleCheckEnabled"] -eq $true)
	{
			$haRule["HealthRuleCheckEnabled"] = $false
			$haRule.Update()			
	}	
}	

# Get and Disable the Farm Account Rule
DisableHealthRule "The server farm account should not be used for other services."

# Get and Disable the Paging File Size Rule
DisableHealthRule "The paging file size should exceed the amount of physical RAM in the system."

# Get and Disable the Built-in accounts Rule
DisableHealthRule "Built-in accounts are used as application pool or service identities."

# Get and Disable the Drive Space Rule
DisableHealthRule "Drives are running out of free space."

# Get and Disable the Drive Space Rule
DisableHealthRule "Trial period for this product is about to expire."

# Get and Disable the UPS MySite Rule
DisableHealthRule "Verify each User Profile Service Application has a My Site Host configured"	
#EndRegion

#Region Set NTFS Perms for Network Service
#$MSOServerRoot = "C:\Program Files\Microsoft Office Servers\14.0"
#$username = "Network Service"
#$acl = Get-Acl $MSOServerRoot
#$accessrule = New-Object system.security.AccessControl.FileSystemAccessRule($username, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
#$acl.AddAccessRule($accessrule)
#set-acl -aclobject $acl $MSOServerRoot
#EndRegion

#Region Fix TaxonomyPicker Code
$farmRoot = "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\14"
$taxpick = Get-Content "$farmRoot\TEMPLATE\CONTROLTEMPLATES\TaxonomyPicker.ascx"
$taxpick[0] = $taxpick[0].replace("&#44;",", ")
Set-Content "$farmRoot\TEMPLATE\CONTROLTEMPLATES\TaxonomyPicker.ascx" -Value $taxpick
#EndRegion
