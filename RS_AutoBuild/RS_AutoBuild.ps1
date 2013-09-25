#* FileName: RS_AutoBuild.ps1
#* Version 5.0
#*=============================================
#* Script Name: [RS_AutoBuild.ps1]
#* Created: [4/2/2013]
#* Author: Corey Burke
#* Company: Rackspace hosting
#* Email: corey.burke@rackspace.co.uk
#* Web: http://blog.sharepoint-voodoo.net
#* Reqrmnts:
#* Keywords:
#*=============================================
#* Purpose: Master Control script for controlling
#* the installation of SharePoint 2010 and 2013
#* via AutoSPInstaller
#*============================================= 


# Get current script execution path and the parent path
$0 = $myInvocation.MyCommand.Definition
$env:dp0 = [System.IO.Path]::GetDirectoryName($0)
$bits = Get-Item $env:dp0 | Split-Path -Parent
$env:AutoSPPath = $bits + "\AutoSPInstaller"

# Get the AutoSPInstaller Config XML file
$AutoSPXML = [xml](get-content "$env:AutoSPPath\AutoSPInstallerInput.xml" -EA 0)

# Create Service Account Config XML if it does not exist and populate Service Accounts
if ($AutoSPXML -eq $null)
{
    
    
    ./RS_AutoBuildSetVars.ps1
    
    # Get a fresh copy of the AutoSPInstaller Config XML file
    $AutoSPXML = [xml](get-content "$env:AutoSPPath\AutoSPInstallerInput.xml" -EA 0)

    ./RS_AutoBuildSetServAccts.ps1
}

#Choose the edition of SharePoint you are installing
Write-Host -ForegroundColor Yellow "How would you like to proceed?"
Write-Host -ForegroundColor Cyan "1. Continue with Build process"
Write-Host -ForegroundColor Cyan "2. Launch AutoSPInstaller GUI"
Write-Host -ForegroundColor Cyan "3. Exit Build Process"
Write-Host -ForegroundColor Cyan " "
$VerChoice = Read-Host "Select 1-3 (Default is 1): "

switch($VerChoice)
{
    1 {
        # Execute AutoSPInstaller Script
        Start-Process -wait "$env:AutoSPPath\AutoSPInstallerLaunch.bat"
    }
    2 {
        # Validate Config through GUI
        Start-Process -wait "$env:AutoSPPath\AutoSPInstallerGUI" "$env:AutoSPPath\AutoSPInstallerInput.xml"

        $launch = Read-Host "Continue with build process? ([Y] or N) "

        if($launch -eq "Y" -or $launch -eq "y")
        {
            # Execute AutoSPInstaller Script
            Start-Process -wait "$env:AutoSPPath\AutoSPInstallerLaunch.bat"
        }
        else{Write-Host "Exiting..."}
    }
    3 {Write-Host "Exiting..."; break}
    default {
                # Execute AutoSPInstaller Script
                Start-Process -wait "$env:AutoSPPath\AutoSPInstallerLaunch.bat"
    }
}

Write-Host ""

Write-Host -ForegroundColor Red "AutoSPInstaller Prep Complete!"