#Set PerformancePoint SSID
Write-Host -ForegroundColor Cyan " - Setting the unattended account for Performance Point Services..."
Get-SPPerformancePointServiceApplication | Set-SPPerformancePointSecureDataValues -DataSourceUnattendedServiceAccount $cred_farm

#Set Excel Services SSID

#Set Access SSID

#Set Visio SSID
