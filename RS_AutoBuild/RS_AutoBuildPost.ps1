# Get current script execution path and the parent path
$0 = $myInvocation.MyCommand.Definition
$env:dp0 = [System.IO.Path]::GetDirectoryName($0)
$bits = Get-Item $env:dp0 | Split-Path -Parent
$env:SPTools = $bits + "\SharePoint Tools"
$env:AutoSPPath = $bits + "\AutoSPInstaller"

$AutoSPXML = [xml](get-content "$env:AutoSPPath\AutoSPInstallerInput.xml" -EA 0)

# Install AppFabric 1.1 CU5 for Distributed Cache
If($AutoSPXML.Configuration.Install.SPVersion -eq "2014")
{
    Write-Host -ForegroundColor Yellow "Installing AppFabric 1.1 CU5..."
    Try{
        Write-Host -ForegroundColor Yellow "Installing AppFabric 1.1 CU5..."
        Start-Process -wait "$env:SPTools\Updates\AppFabric1.1-KB2932678-x64-ENU.exe" -ArgumentList "/quiet /norestart"
        Write-Host -ForegroundColor Green "App Fabric 1.1 CU5 installed successfully!"
    }
    Catch{Write-Host -ForegroundColor Red "App Fabric 1.1 CU5 failed to install. Please update manually..."}
}

# Disable Certain Health Analyzer Rules
function DisableHARule($ruleName)
{
    Try{
        Write-Host -ForegroundColor Yellow "Querying status of $ruleName Health Analyzer Rule..."
        $harStatus = Get-SPHealthAnalysisRule $ruleName
        
        if($harStatus.Enabled -eq $true)
        {
            Try{
                Write-Host -ForegroundColor Yellow "$ruleName Health Analyzer Rule is currently enabled. Disabling..."
                Disable-SPHealthAnalysisRule $ruleName  -Confirm:$false
                Write-Host -ForegroundColor Green "$ruleName Health Analyzer Rule disabled successfully!"
            }
            Catch{Write-Host -ForegroundColor Red "Failed to disable the $ruleName Health Analyzer Rule. Please disable manually..."}
        }
    }
    Catch{Write-Host -ForegroundColor Red "Failed to get the status of the $ruleName Health Analyzer Rule. Please check that the rule exists and is functional..."}
}
DisableHARule "PagingFileSizeShouldExceedRam"
DisableHARule "AppServerDrivesAreNearlyFullWarning"

$distCacheServersXML = $AutoSPXML.Configuration.Farm.Services.DistributedCache.Start
$distCacheServers = $distCacheServersXML.Split(" ")

$entSearchServers = $AutoSPXML.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication.IndexComponent.Server

$reduce = $false
foreach($server in $entSearchServers)
{
    if($distCacheServers -contains $server.Name){$reduce = $true}
}

If($reduce)
{
    Try{
        Write-Host -ForegroundColor Yellow "Checking Search Service Performance Level..."
        $searchsvc = Get-SPEnterpriseSearchService
        if($searchsvc.PerformanceLevel -eq "Maximum")
        {
            Try{
                Write-Host -ForegroundColor Yellow "Search Service Performance Level is currently set to Maximum. Changing to Partly Reduced..."
                Set-SPEnterpriseSearchService –PerformanceLevel PartlyReduced
                Write-Host -ForegroundColor Green "Search Service Performance Level successfully set to Partly Reduced..."
            }
            Catch{Write-Host -ForegroundColor Red "Failed to set the Search Service Performance Level to Partly Reduced! Please check the state of the Search Service and set the Performance Level manually..."}
        }
        elseif($searchsvc.PerformanceLevel -eq "PartlyReduced"){Write-Host -ForegroundColor Green "Search Service Performance Level is already set to Partly Reduced..."}
    }
    Catch{Write-Host -ForegroundColor Red "Failed to query the Search Service! Please check the state of the Search Service and set the Performance Level manually..."}
}
else{Write-Host -ForegroundColor Green "Index Component appears to be appropriately isolated. Leaving Performance Level set to Maximum..."}