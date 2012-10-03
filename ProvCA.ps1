#Region Configure Central Admin
$CentralAdminPort = "5000"

Write-Host -ForegroundColor Cyan "- Creating and configuring Central Administration..."
try
{
    ## Install Help Files
	Write-Host -ForegroundColor Cyan " - Installing Help Collection..."
	Install-SPHelpCollection -All	
	## Install (all) features
	Write-Host -ForegroundColor Cyan " - Installing Features..."
	$Features = Install-SPFeature –AllExistingFeatures -Force
	## Create Central Admin
	Write-Host -ForegroundColor Cyan " - Creating Central Admin site..."
	$NewCentralAdmin = New-SPCentralAdministration -Port $CentralAdminPort -WindowsAuthProvider "NTLM" -ErrorVariable err
	If (-not $?) {throw}
	Write-Host -ForegroundColor Cyan " - Waiting for Central Admin site to provision..." -NoNewline
	sleep 5
	Write-Host -BackgroundColor Blue -ForegroundColor Black "Done!"
	Write-Host -ForegroundColor Cyan " - Installing Application Content..."
	Install-SPApplicationContent
}
catch	
{
    If ($err -like "*update conflict*")
	{
		Write-Warning " - A concurrency error occured, trying again."
		CreateCentralAdmin
	}
	Else 
	{
		Write-Output $_
		Suspend-Script
		break
	}
}
Write-Host -ForegroundColor Cyan "- Done creating Central Administration."
#End Region Configure Central Admin
