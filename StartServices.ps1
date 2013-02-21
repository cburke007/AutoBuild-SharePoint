Import-Module ./StartServices-Module -force

$serverName = hostname  
Write-Host -ForegroundColor Yellow "Starting Services on $serverName"

$FarmConfigXML = [xml](get-content "$curloc\FarmConfig.xml" -EA 0)
   
$serverNode=$FarmConfigXML.selectSingleNode("//Customer/Farm/FarmServers/Server[@Name='$serverName']")
$servicesNode = $serverNode.Services

foreach($serviceNode in $servicesNode.Service)
{	
	switch($serviceNode.Name)
	{
		"Microsoft SharePoint Foundation Incoming E-Mail" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Microsoft SharePoint Foundation Sandboxed Code Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Business Data Connectivity Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
											
		"Managed Metadata Web Service" 	{if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Application Registry Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Claims to Windows Token Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Microsoft SharePoint Foundation Subscription Settings Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"User Profile Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"User Profile Synchronization Service" 
        {
            If ((Get-SPServiceApplication | ? {$_.GetType().ToString() -eq "Microsoft.Office.Server.Administration.UserProfileApplication"}) -ne $null)
            {
                if($serviceNode.Status -eq "Online")
                {
                    $serviceApp = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmServiceApplications/ServiceApp[@TypeName='User Profile Service Application']")
                    $saName = $serviceApp.DisplayName
                    $farmAcctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type='Farm Connect']")
                
                    Start-UPSynchService $saName $farmAcctNode.Name $farmAcctNode.Password
                }
            }
        }
		
		"Secure Store Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}		
		
		"Web Analytics Web Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Web Analytics Data Processing Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Visio Graphics Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"PerformancePoint Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Access Database Service" 
        {
            if($serviceNode.Status -eq "Online")
            {
                if ((Get-PSSnapin Microsoft.SharePoint.PowerShell).version.major -eq "14")
                {
                    $serviceName = "Access Database Service"
                }
                elseif((Get-PSSnapin Microsoft.SharePoint.PowerShell).version.major -eq "15")
                {
                    $serviceName = "Access Database Service 2010"
                }
                Start-Service $serviceName
            }
        }
		
		"Excel Calculation Services" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Word Automation Services" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Search Query and Site Settings Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
        
        "Machine Translation Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}

        "App Management Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}

        "Microsoft SharePoint Foundation Subscription Settings Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
	}
}	  
#EndRegion
