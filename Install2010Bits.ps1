Import-Module ./AutoBuild-Module

# Get the path to the SharePoint bits root path
$bits = Get-Item $curloc | Split-Path -Parent

#Install Pre-requisites
Write-Host -ForegroundColor Cyan "- Installing SharePoint Pre-Requisites..."
If (Test-Path "$env:CommonProgramFiles\Microsoft Shared\Web Server Extensions\14\BIN\stsadm.exe") #Crude way of checking if SP2010 is already installed
{
	Write-Host -ForegroundColor Cyan "- SP2010 prerequisites appear be already installed - skipping installation."
}
Else
{
    Try 
	{
        Start-Process "$bits\PrerequisiteInstaller.exe" -Wait -ArgumentList "/unattended" -WindowStyle Minimized
	    If (-not $?) {throw}
    }
    catch
    {
		Write-Host -ForegroundColor Red "- Error: $LastExitCode"
		If ($LastExitCode -eq "1") {throw "- Another instance of this application is already running"}
		ElseIf ($LastExitCode -eq "2") {throw "- Invalid command line parameter(s)"}
		ElseIf ($LastExitCode -eq "1001") {throw "- A pending restart blocks installation"}
		ElseIf ($LastExitCode -eq "3010") {throw "- A restart is needed"}
		Else {throw "- An unknown error occurred installing prerequisites"}
	}
    
    	## Parsing most recent PreRequisiteInstaller log for errors or restart requirements, since $LastExitCode doesn't seem to work...
	$PreReqLog = get-childitem $env:TEMP | ? {$_.Name -like "PrerequisiteInstaller.*"} | Sort-Object -Descending -Property "LastWriteTime" | Select-Object -first 1
	If ($PreReqLog -eq $null) 
	{
		Write-Warning " - Could not find PrerequisiteInstaller log file"
	}
	Else 
	{
		## Get error(s) from log
		$PreReqLastError = $PreReqLog | select-string -SimpleMatch -Pattern "Error" -Encoding Unicode | ? {$_.Line  -notlike "*Startup task*"}
		If ($PreReqLastError)
		{
			Write-Warning $PreReqLastError.Line
			$PreReqLastReturncode = $PreReqLog | select-string -SimpleMatch -Pattern "Last return code" -Encoding Unicode | Select-Object -Last 1
			If ($PreReqLastReturnCode) {Write-Warning $PreReqLastReturncode.Line}
			Write-Host -ForegroundColor Cyan " - Review the log file and try to correct any error conditions."
			Suspend-Script
			Invoke-Item $env:TEMP\$PreReqLog
			break
		}
        
		## Look for restart requirement in log
		$PreReqRestartNeeded = $PreReqLog | select-string -SimpleMatch -Pattern "0XBC2=3010" -Encoding Unicode
		If ($PreReqRestartNeeded)
		{
			Write-Warning " - One or more of the prerequisites requires a restart."
			Write-Host -ForegroundColor Cyan " - Run the script again after restarting to continue."
			Suspend-Script
			break
		}
	}
	
	Write-Progress -Activity "Installing Prerequisite Software" -Status "Done." -Completed
	Write-Host -ForegroundColor Cyan "- All Prerequisite Software installed successfully."
}
#End Region Configure Pre-Requisites

#Region Install SharePoint Bits
Function InstallSharePoint
{
If  (Test-Path "$env:CommonProgramFiles\Microsoft Shared\Web Server Extensions\14\BIN\stsadm.exe") #Crude way of checking if SP2010 is already installed
{
	Write-Host -ForegroundColor Cyan "- SP2010 binaries appear to be already installed - skipping installation."
}
Else
{
	## Install SharePoint Binaries
	If (Test-Path "$bits\setup.exe")
	{  		
		Write-Host -ForegroundColor Cyan "- Installing SharePoint binaries..."
  		try
		{
			Start-Process "$bits\setup.exe" -ArgumentList "/config `"$curloc\$ConfigFile`"" -WindowStyle Minimized -Wait
			If (-not $?) {throw}
		}
		catch 
		{
			Write-Warning "- Error $LastExitCode occurred running $bits\setup.exe"
			break
		}
		
		## Parsing most recent SharePoint Server Setup log for errors or restart requirements, since $LastExitCode doesn't seem to work...
		$SetupLog = get-childitem $env:TEMP | ? {$_.Name -like "SharePoint Server Setup*"} | Sort-Object -Descending -Property "LastWriteTime" | Select-Object -first 1
		If ($SetupLog -eq $null) 
		{
			Write-Warning " - Could not find SharePoint Server Setup log file!"
			Suspend-Script
			break
		}
		Else 
		{
			## Get error(s) from log
			$SetupLastError = $SetupLog | select-string -SimpleMatch -Pattern "Error:" | Select-Object -Last 1 #| ? {$_.Line  -notlike "*Startup task*"}
			If ($SetupLastError)
			{
				Write-Warning $SetupLastError.Line
				#$SetupLastReturncode = $SetupLog | select-string -SimpleMatch -Pattern "Last return code" | Select-Object -Last 1
				#If ($SetupLastReturnCode) {Write-Warning $SetupLastReturncode.Line}
				Write-Host -ForegroundColor Cyan " - Review the log file and try to correct any error conditions."
				Suspend-Script
				Invoke-Item $env:TEMP\$SetupLog
				break
			}
			## Look for restart requirement in log
			$SetupRestartNotNeeded = $SetupLog | select-string -SimpleMatch -Pattern "System reboot is not pending."
			If (!($SetupRestartNotNeeded))
			{
				Write-Host -ForegroundColor Cyan " - SharePoint setup requires a restart."
				Write-Host -ForegroundColor Cyan " - Run the script again after restarting to continue."
				Suspend-Script
				break
			}
		}		
	}
	Else
	{
	  	Write-Host -ForegroundColor Red "- Install path $bits Not found!!"
	  	Suspend-Script
		break
	}
}
}
InstallSharepoint
#End Region Install SharePoint Bits

#Region Install Language Packs
## Detects any language packs in $bits\LanguagePacks folder and installs them.

## Look for Server language packs
$ServerLanguagePacks = (Get-ChildItem "$bits\LanguagePacks" -Name -Include ServerLanguagePack*.exe -ErrorAction SilentlyContinue)
If ($ServerLanguagePacks)
{
	Write-Host -ForegroundColor Cyan "- Installing SharePoint (Server) Language Packs:"
	## Get installed languages from registry (HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office Server\15.0\InstalledLanguages)
    $InstalledOfficeServerLanguages = (Get-Item "HKLM:\Software\Microsoft\Office Server\14.0\InstalledLanguages").GetValueNames() | ? {$_ -ne ""}

	ForEach ($LanguagePack in $ServerLanguagePacks)
	{
        ## Slightly convoluted check to see if language pack is already installed, based on name of language pack file.
        ## This only works if you've renamed your language pack(s) to follow the convention "ServerLanguagePack_XX-XX.exe" where <XX-XX> is a culture such as <en-us>.
		$Language = $InstalledOfficeServerLanguages | ? {$_ -eq (($LanguagePack -replace "ServerLanguagePack_","") -replace ".exe","")}
        If (!$Language)
        {
	        Write-Host -ForegroundColor Cyan " - Installing $LanguagePack..." -NoNewline
	        Start-Process -FilePath "$bits\LanguagePacks\$LanguagePack" -ArgumentList "/quiet /norestart"
	        While (Get-Process -Name ($LanguagePack -replace ".exe", "") -ErrorAction SilentlyContinue)
	        {
	        	Write-Host -ForegroundColor Cyan "." -NoNewline
	        	sleep 5
	        }
   		    Write-Host -BackgroundColor Blue -ForegroundColor Black "Done."
        }
        Else
        {
            Write-Host -ForegroundColor Cyan " - Language $Language already appears to be installed, skipping."
        }
	}
	Write-Host -ForegroundColor Cyan " - Language Pack installation complete."
}
Else {Write-Host -ForegroundColor Cyan " - No language packs found in $bits\LanguagePacks, skipping."}

#Get Installed Languages
$InstalledOfficeServerLanguages = (Get-Item "HKLM:\Software\Microsoft\Office Server\14.0\InstalledLanguages").GetValueNames() | ? {$_ -ne ""}

#List each installed Language
Write-Host -ForegroundColor Cyan " - Currently installed languages:" 
ForEach ($Language in $InstalledOfficeServerLanguages)
{
	#Write-Host -ForegroundColor Cyan "  -"$Language.DisplayName
	Write-Host -ForegroundColor Cyan "  -" ([System.Globalization.CultureInfo]::GetCultureInfo($Language).DisplayName)
}
#End Region Install Language Packs
