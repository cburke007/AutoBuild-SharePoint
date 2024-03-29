#* FileName: RS_AutoBuild.ps1
#* Version 6.5 BETA
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
$env:RSScriptPath = $env:dp0
$bits = Get-Item $env:dp0 | Split-Path -Parent
$env:AutoSPPath = $bits + "\AutoSPInstaller"

Start-Transcript -Path $env:RSScriptPath\ScriptPrep.log -Append -Force

Import-Module ServerManager
Add-WindowsFeature -Name Telnet-Client | Out-Null

# Get the AutoSPInstaller Config XML file
$AutoSPXML = [xml](get-content "$env:AutoSPPath\AutoSPInstallerInput.xml" -EA 0)

Write-Host -ForegroundColor Yellow "Gathering Data Input for AutoSPInstallerInput.xml..."
# Create Service Account Config XML if it does not exist and populate Service Accounts
if ([string]::IsNullOrEmpty($AutoSPXML))
{
    .$env:RSScriptPath\RS_AutoBuildSetVars.ps1
    
    Write-Host -ForegroundColor Green "AutoSPInstallerInput.xml has been created successfully!"
    # Get a fresh copy of the AutoSPInstaller Config XML file
    $AutoSPXML = [xml](get-content "$env:AutoSPPath\AutoSPInstallerInput.xml" -EA 0)
}
else{Write-Host -ForegroundColor Green "AutoSPInstallerInput.xml Exists! - Skipping data input process..."}

# Check SQL Connectivity
Write-Host -ForegroundColor Yellow "Checking SQL Connectivity..."
$dbInstance = $AutoSPXML.Configuration.Farm.Database.DBAlias.DBInstance
if([string]::IsNullOrEmpty($AutoSPXML.Configuration.Farm.Database.DBAlias.DBPort))
{
    $dbPort = "1433"
}
else{$dbPort = $AutoSPXML.Configuration.Farm.Database.DBAlias.DBPort}

$sqlTest = New-Object System.Net.Sockets.TcpClient
Try
{
    Write-Host -ForegroundColor Cyan " - Connecting to "$dbInstance":"$dbPort" (TCP).."
    $sqlTest.Connect($dbInstance, $dbPort)
    Write-Host -ForegroundColor Green "SQL Connection successful!"
}
Catch
{
    Write-Host -ForegroundColor Red "SQL Connection failed! Fix the issue and run the script again..."
    break
}
Finally
{
    if ((Get-WmiObject Win32_OperatingSystem).Version -gt 6.2)
    {
        $sqlTest.Dispose()
    }
}

$cInfo = (get-content "$env:RSScriptPath\COREInfo.txt" -EA 0)
if([string]::IsNullOrEmpty(($cInfo | Select-String -pattern "<b>Sharepoint Products/Add-ons installed:</b> ")))
{
    $continue = Read-Host "Continue with User Creation? (Y/n) "
    if($continue -eq 'Y' -or $continue -eq 'y')
    {
        .$env:RSScriptPath\RS_AutoBuildSetServAccts.ps1
    }
    else{break}
}
else{Write-Host -ForegroundColor Green "Service Accounts already logged in COREInfo.txt - Skipping User creation..."}

.$env:RSScriptPath\RS_AutoBuildPrep.ps1
Write-Host -ForegroundColor Green "AutoSPInstaller Prep Complete!"

Stop-Transcript

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
        #Start-Process -wait "$env:AutoSPPath\AutoSPInstallerLaunch.bat"
        .$env:AutoSPPath\AutoSPInstallerMain.ps1 "$env:AutoSPPath\AutoSPInstallerInput.xml"
        
        Start-Transcript -Path $env:RSScriptPath\ScriptPost.log -Append -Force
        # Post Install Configuration
        .$env:RSScriptPath\RS_AutoBuildPost.ps1
        Stop-Transcript
    }
    2 {
        # Validate Config through GUI
        .$env:AutoSPPath\AutoSPInstallerGUI.exe "$env:AutoSPPath\AutoSPInstallerInput.xml"

        $launch = Read-Host "Continue with build process? ([Y] or N) "

        if($launch -eq "Y" -or $launch -eq "y")
        {
            # Execute AutoSPInstaller Script
            #Start-Process -wait "$env:AutoSPPath\AutoSPInstallerLaunch.bat"
            .$env:AutoSPPath\AutoSPInstallerMain.ps1 "$env:AutoSPPath\AutoSPInstallerInput.xml"
            
            Start-Transcript -Path $env:RSScriptPath\ScriptPost.log -Append -Force
            # Post Install Configuration
            .$env:RSScriptPath\RS_AutoBuildPost.ps1
            Stop-Transcript
        }
        else{Write-Host -ForegroundColor Red "Exiting..."; break}
    }
    3 {Write-Host -ForegroundColor Red "Exiting..."; break}
    default {
                # Execute AutoSPInstaller Script
                #Start-Process -wait "$env:AutoSPPath\AutoSPInstallerLaunch.bat"
                .$env:AutoSPPath\AutoSPInstallerMain.ps1 "$env:AutoSPPath\AutoSPInstallerInput.xml"
                
                Start-Transcript -Path $env:RSScriptPath\ScriptPost.log -Append -Force
                # Post Install Configuration
                .$env:RSScriptPath\RS_AutoBuildPost.ps1
                Stop-Transcript
    }
}

Write-Host -ForegroundColor Green "Build Process Complete!"

