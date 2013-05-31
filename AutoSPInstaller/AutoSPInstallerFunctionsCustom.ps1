# ===================================================================================
# CUSTOM FUNCTIONS - Put your new or overriding functions here
# ===================================================================================

#Function to start Windows Services
function Start-WinService
{
    param([string]$serviceName)
    
    $service = get-service $serviceName
    
    if($service.Status -ne "Running")
    { 
        Write-Host -ForegroundColor Cyan " - Starting $serviceName..."
        Set-Service $service -startuptype automatic
        Start-WinService $service        
               
        ## Wait
		Write-Host -ForegroundColor Cyan " - Waiting for $serviceName to start" -NoNewline
		While ($service.Status -ne "Running") 
		{
    		Write-Host -ForegroundColor Cyan "." -NoNewline
    		sleep 1
    		$service = get-service $serviceName
		}
		Write-Host -BackgroundColor Blue -ForegroundColor Black "Started!"
    }
    else
    {
        Write-Host -ForegroundColor Cyan " - $serviceName is already running"
    }
    
}

function Set-RSPreReqs
{
    Import-Module ServerManager

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

    # Copy SharePoint Tools folder to C:\rs-pkgs
    if(-not (Get-Item "C:\rs-pkgs\SharePoint Tools" -EA SilentlyContinue))
    {
        Copy-Item "$bits\Sharepoint Tools" "C:\rs-pkgs\Sharepoint Tools" -recurse
    }

    Write-Host -Foreground Yellow "Checking Server Role Pre-Requisites..." 
    # Check that pre-requisite Roles have been installed into Windows
    Add-WindowsFeature "Web-Default-Doc", "Web-Dir-Browsing", "Web-Dir-Browsing", "Web-Static-Content", "Web-Http-Redirect", "Web-Http-Logging", "Web-Log-Libraries", "Web-Request-Monitor", "Web-Http-Tracing", "Web-Stat-Compression", "Web-Dyn-Compression", "Web-Filtering", "Web-Basic-Auth", "Web-Client-Auth", "Web-Digest-Auth", "Web-Cert-Auth", "Web-IP-Security", "Web-Url-Auth", "Web-Windows-Auth", "Web-Asp-Net", "Web-ISAPI-Ext", "Web-ISAPI-Filter", "Web-Net-Ext", "Web-Mgmt-Console", "Web-Metabase", "Web-Lgcy-Scripting", "Web-WMI", "Web-Scripting-Tools", "SMTP-Server", "PowerShell-ISE", "NET-Framework-Core"
    Write-Host ""

    Write-Host -Foreground Yellow "Checking Status of Windows Services Pre-Requisites..."
    # Ensure necessary Windows Services are started
    $servicesToStart = "W3SVC", "IISADMIN"

    # Make sure necessary windows services are started and set to Automatic
    foreach ($serviceToStart in $servicesToStart)
    {
        Start-WinService "$serviceToStart"
    }
    Write-Host ""

}

