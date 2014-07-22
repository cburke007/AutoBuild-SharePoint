# Disable IPv6
Write-Host -ForegroundColor Yellow "Disabling IPv6..."

$lsaPath = "HKLM:\SYSTEM\CurrentControlSet\Services\TCPIP6\Parameters"
$lsaPathValue = Get-ItemProperty -path $lsaPath
If (-not ($lsaPathValue.DisabledComponents -eq  0xffffffff))
{
    Try{
        New-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\TCPIP6\Parameters -Name "DisabledComponents" -Value  0xffffffff -PropertyType DWORD -Force | Out-Null
        Write-Host -ForegroundColor Green "IPv6 Disabled!"
    }
    Catch{
        Write-Host -ForegroundColor Red "Failed to Disable IPv6. Check Registry Permissions, or Disable IPv6 Manually..."
        Write-Host "Press any key when ready to continue with the build process..."
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")    
    }
}
