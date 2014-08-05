﻿# Get current script execution path and the parent path
$0 = $myInvocation.MyCommand.Definition
$env:dp0 = [System.IO.Path]::GetDirectoryName($0)
$bits = Get-Item $env:dp0 | Split-Path -Parent
$env:SPTools = $bits + "\SharePoint Tools"

# Install AppFabric 1.1 CU5 for Distributed Cache
Write-Host -ForegroundColor Yellow "Installing AppFabric 1.1 CU5..."
Try{
    Write-Host -ForegroundColor Yellow "Installing AppFabric 1.1 CU5..."
    Start-Process -wait "$env:SPTools\Updates\AppFabric1.1-KB2932678-x64-ENU.exe" -ArgumentList "/quiet /norestart"
    Write-Host -ForegroundColor Green "App Fabric 1.1 CU5 installed successfully!"
}
Catch{Write-Host -ForegroundColor Red "App Fabric 1.1 CU5 failed to install. Please update manually..."}

# Disable Certain Health Analyzer Rules
function DisableHARule($ruleName)
{
    Try{
        Write-Host -ForegroundColor Yellow "Disabling $ruleName Health Analyzer Rule..."
        Disable-SPHealthAnalysisRule $ruleName  -Confirm:$false
        Write-Host -ForegroundColor Green "$ruleName Health Analyzer Rule disabled successfully!"
    }
    Catch{Write-Host -ForegroundColor Red "Failed to disable the $ruleName Health Analyzer Rule. Please disable manually..."}

}

DisableHARule "PagingFileSizeShouldExceedRam"
DisableHARule "AppServerDrivesAreNearlyFullWarning"