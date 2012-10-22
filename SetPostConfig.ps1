﻿#Region HealthRules
function Disable2010HealthRule
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

If((Get-PSSnapin Microsoft.SharePoint.PowerShell).version.major -eq "14")
{
    # Get and Disable the Farm Account Rule
    Disable2010HealthRule "The server farm account should not be used for other services."

    # Get and Disable the Paging File Size Rule
    Disable2010HealthRule "The paging file size should exceed the amount of physical RAM in the system."

    # Get and Disable the Built-in accounts Rule
    Disable2010HealthRule "Built-in accounts are used as application pool or service identities."

    # Get and Disable the Drive Space Rule
    Disable2010HealthRule "Drives are running out of free space."

    # Get and Disable the Drive Space Rule
    Disable2010HealthRule "Trial period for this product is about to expire."

    # Get and Disable the UPS MySite Rule
    Disable2010HealthRule "Verify each User Profile Service Application has a My Site Host configured"	

    #Fix TaxonomyPicker Code
    $farmRoot = "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\14"
    $taxpick = Get-Content "$farmRoot\TEMPLATE\CONTROLTEMPLATES\TaxonomyPicker.ascx"
    $taxpick[0] = $taxpick[0].replace("&#44;",", ")
    Set-Content "$farmRoot\TEMPLATE\CONTROLTEMPLATES\TaxonomyPicker.ascx" -Value $taxpick
}
ElseIf((Get-PSSnapin Microsoft.SharePoint.PowerShell).version.major -eq "15")
{

}