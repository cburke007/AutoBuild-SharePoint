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
		
		"User Profile Synchronization Service" {if($serviceNode.Status -eq "Online"){Start-UPSynchService}}
		
		"Secure Store Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}		
		
		"Web Analytics Web Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Web Analytics Data Processing Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Visio Graphics Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"PerformancePoint Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Access Database Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Excel Calculation Services" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Word Automation Services" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
		
		"Search Query and Site Settings Service" {if($serviceNode.Status -eq "Online"){Start-Service $serviceNode.Name}}
	}
}	  
#EndRegion
