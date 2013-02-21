#Region Start Standard Services
function Start-Service
{
	param ([string]$serviceName)
	
	$service = Get-SPServiceInstance | ? {$_.TypeName -eq "$serviceName"} 
	If ($service.Status -eq "Disabled") 
	{
	    try
		{
			Write-Host -ForegroundColor Cyan "- Starting $serviceName..."
			$service | Start-SPServiceInstance | Out-Null
			If (-not $?) {throw "- Failed to start $serviceName"}
		}
		catch {"- An error occurred starting the $serviceName"}
		#Wait
				Write-Host -ForegroundColor Cyan " - Waiting for $serviceName to start" -NoNewline
				While ($service.Status -ne "Online") 
				{
					Write-Host -ForegroundColor Cyan "." -NoNewline
					sleep 1
					$service = Get-SPServiceInstance | ? {$_.TypeName -eq "$serviceName"}
				}
				Write-Host -ForegroundColor Cyan "Started!"
	} 
}
#EndRegion

#Region Start User Profile Synch Service
function Start-UPSynchService
{
	param([string]$saName, [string]$farmAcct, [string]$farmPass)

    $netbios = (Get-LocalLogonInformation).DomainShortName	
	$domFarmAcct = "$netbios\$farmAcct"

    ## Start User Profile Synchronization Service
	## Get User Profile Service
	$ProfileServiceApp = Get-SPServiceApplication |?{$_.Name -eq $saName}
	If ($ProfileServiceApp)
	{
		## Get User Profile Synchronization Service
		Write-Host -ForegroundColor Cyan "- Checking User Profile Synchronization Service..." -NoNewline
		$ProfileSyncService = Get-SPServiceInstance | ? {$_.GetType().ToString() -eq "Microsoft.Office.Server.Administration.ProfileSynchronizationServiceInstance"}
		If ($ProfileSyncService.Status -ne "Online")
		{    				
			Write-Host -ForegroundColor Cyan "`n"
			Write-Host -ForegroundColor Cyan " - Starting User Profile Synchronization Service..." -NoNewline
			$ProfileServiceApp.SetSynchronizationMachine($env:COMPUTERNAME, $ProfileSyncService.Id, $domFarmAcct, $farmPass)
			
            If (($ProfileSyncService.Status -ne "Provisioning") -and ($ProfileSyncService.Status -ne "Online")) {Write-Host -ForegroundColor Cyan " - Waiting for User Profile Synchronization Service to be started..." -NoNewline}
			Else ## Monitor User Profile Sync service status
			{
			While ($ProfileSyncService.Status -ne "Online")
			{
				While ($ProfileSyncService.Status -ne "Provisioning")
				{
					Write-Host -ForegroundColor Cyan ".`a" -NoNewline
					Sleep 1
					$ProfileSyncService = Get-SPServiceInstance | ? {$_.GetType().ToString() -eq "Microsoft.Office.Server.Administration.ProfileSynchronizationServiceInstance"}
				}
				If ($ProfileSyncService.Status -eq "Provisioning")
				{
					Write-Host -BackgroundColor Blue -ForegroundColor Black "Started!`a`a"
        			Write-Host -ForegroundColor Cyan " - Provisioning User Profile Sync Service, please wait (up to 15 minutes)..." -NoNewline
				}
				While($ProfileSyncService.Status -eq "Provisioning" -and $ProfileSyncService.Status -ne "Disabled")
				{
					Write-Host -ForegroundColor Cyan ".`a" -NoNewline
					sleep 1
					$ProfileSyncService = Get-SPServiceInstance | ? {$_.GetType().ToString() -eq "Microsoft.Office.Server.Administration.ProfileSynchronizationServiceInstance"}
				}
				If ($ProfileSyncService.Status -ne "Online")
				{
					Write-Host -ForegroundColor Red ".`a`a`a`a`a`a`a`a" 
					Write-Host -BackgroundColor Red -ForegroundColor Black "- User Profile Synchronization Service could not be started!"
					break
				}
				Else
				{
					Write-Host -BackgroundColor Blue -ForegroundColor Black "Started!`a`a"
					## Need to restart IIS before we can do anything with the User Profile Sync Service
					Write-Host -ForegroundColor Cyan " - Restarting IIS..."
					Start-Process -FilePath iisreset.exe -ArgumentList "-noforce" -Wait -NoNewWindow
				}
			}
			}
		}
		Else {Write-Host -ForegroundColor Cyan "Already started."}
	}
	Else 
	{
		Write-Host -ForegroundColor Cyan "`n"
		Write-Host -ForegroundColor Red "- Could not get User Profile Service"
	}
}
#EndRegion





Export-ModuleMember Start-Service, Start-UPSynchService
