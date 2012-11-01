Remove-PSSnapin microsoft.SharePoint.PowerShell -EA 0
Add-PSSnapin microsoft.SharePoint.PowerShell -EA 0
Import-Module ./AutoBuild-Module -force
Import-Module ./ProvSA-Module -force

$serverName = hostname

Write-Host -ForegroundColor Yellow "Building Service Applications"

$FarmConfigXML = [xml](get-content "$curloc\FarmConfig.xml" -EA 0)     
$serviceApps = $FarmConfigXML.Customer.Farm.FarmServiceApplications.ServiceApp
$DBPrefix = $FarmConfigXML.Customer.Farm.DBPrefix
$buildVer = (Get-PSSnapin Microsoft.SharePoint.PowerShell).version.major

foreach($serviceApp in $serviceApps)
{	
	switch($serviceApp.TypeName)
	{		
		"Business Data Connectivity Service Application" 	{						
																$appPoolAcctName = $serviceApp.ServiceApplicationPoolAcctName
																$acctNode=$FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Name='$appPoolAcctName']")
																$prefixedDBName = $DBPrefix + $serviceApp.Database.DBName
																New-BCSApp $serviceApp.DisplayName $serviceApp.ServiceApplicationPoolName $serviceApp.Database.DBServer $prefixedDBName $serviceApp.ServiceApplicationPoolAcctName $acctNode.Password
															}
															
		"Managed Metadata Service" 		{
											$appPoolAcctName = $serviceApp.ServiceApplicationPoolAcctName
											$acctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Name='$appPoolAcctName']")
											$farmAcctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type='Farm Connect']")
											$prefixedDBName = $DBPrefix + $serviceApp.Database.DBName
											New-MMDataApp $serviceApp.DisplayName $serviceApp.ServiceApplicationPoolName $serviceApp.Database.DBServer $prefixedDBName $serviceApp.ServiceApplicationPoolAcctName $acctNode.Password $farmAcctNode.Name								
										}
										
		"User Profile Service Application" 	{
												$appPoolAcctName = $serviceApp.ServiceApplicationPoolAcctName
												$acctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Name='$appPoolAcctName']")
												$farmAcctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type='Farm Connect']")
												$prefixedProfileDB = $DBPrefix + "ProfileDB"
												$prefixedSyncDB = $DBPrefix + "SyncDB"
												$prefixedSocialDB = $DBPrefix + "SocialDB"
												New-UserProfileApp $serviceApp.DisplayName $serviceApp.ServiceApplicationPoolName $serviceApp.ServiceApplicationPoolAcctName $acctNode.Password $farmAcctNode.Name $prefixedProfileDB $serviceApp.ProfileDatabase.DBServer $prefixedSyncDB $serviceApp.SyncDatabase.DBServer $prefixedSocialDB $serviceApp.SocialDatabase.DBServer								
											}	
											
		"State Service" {$prefixedDBName = $DBPrefix + $serviceApp.Database.DBName; New-StateServiceApp $serviceApp.DisplayName $prefixedDBName}
		
		"Usage and Health Data Collection Service Application" {$prefixedDBName = $DBPrefix + $serviceApp.Database.DBName; New-UsageApp $serviceApp.DisplayName $serviceApp.Database.DBServer $prefixedDBName}
		
		"Secure Store Service Application" 	{
												$appPoolAcctName = $serviceApp.ServiceApplicationPoolAcctName
												$acctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Name='$appPoolAcctName']")
												$prefixedDBName = $DBPrefix + $serviceApp.Database.DBName
												New-SecureStoreApp $serviceApp.DisplayName $serviceApp.ServiceApplicationPoolName $serviceApp.Database.DBServer $prefixedDBName $serviceApp.ServiceApplicationPoolAcctName $acctNode.Password $FarmConfigXML.Customer.Farm.PassPhrase								
											}
											
		"Web Analytics Service Application" {
												if($FarmConfigXML.Customer.Farm.BuildVersion -like "14*")
                                                {
                                                    $appPoolAcctName = $serviceApp.ServiceApplicationPoolAcctName
												    $acctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Name='$appPoolAcctName']")
												    $prefixedWHDBName = $DBPrefix + $serviceApp.WarehouseDatabase.DBName
												    $prefixedStagingDBName = $DBPrefix + $serviceApp.StagingDatabase.DBName
												    New-WebAnalyticsApp $serviceApp.DisplayName $serviceApp.ServiceApplicationPoolName $serviceApp.WarehouseDatabase.DBServer $prefixedWHDBName $serviceApp.StagingDatabase.DBServer $prefixedStagingDBName $serviceApp.ServiceApplicationPoolAcctName $acctNode.Password								
											    }
                                                elseif($FarmConfigXML.Customer.Farm.BuildVersion -like "15*")
                                                {
                                                    Write-Host "Web Analytics Provisioning has not been implemented yet"
                                                
                                                
                                                }
                                            }
		"Visio Graphics Service Application" 	{
													$appPoolAcctName = $serviceApp.ServiceApplicationPoolAcctName
													$acctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Name='$appPoolAcctName']")												
													New-VisioApp $serviceApp.DisplayName $serviceApp.ServiceApplicationPoolName $serviceApp.ServiceApplicationPoolAcctName $acctNode.Password								
												}
		"PerformancePoint Service Application" 	{
													$appPoolAcctName = $serviceApp.ServiceApplicationPoolAcctName
													$acctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Name='$appPoolAcctName']")												
													New-PerfPointApp $serviceApp.DisplayName $serviceApp.ServiceApplicationPoolName $serviceApp.ServiceApplicationPoolAcctName $acctNode.Password								
												}
		"Access Services Application" 	{
											$appPoolAcctName = $serviceApp.ServiceApplicationPoolAcctName
											$acctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Name='$appPoolAcctName']")
                                            $sqlAlias = $FarmConfigXML.Customer.Farm.FarmDBServerAlias											
											$SQLVersion = Get-SQLVer $sqlAlias
                                            
                                            if($buildVer -eq "14")
                                            {
                                                New-2010AccessApp $serviceApp.DisplayName $serviceApp.ServiceApplicationPoolName $serviceApp.ServiceApplicationPoolAcctName $acctNode.Password
                                            }
                                            elseif($buildVer -eq "15")
                                            {
                                                if($SQLVersion -like "11*")
                                                {
                                                    New-2013AccessApp $serviceApp.DisplayName $serviceApp.ServiceApplicationPoolName $serviceApp.ServiceApplicationPoolAcctName $acctNode.Password
                                                }
                                                else
                                                {
                                                    New-2010AccessApp $serviceApp.DisplayName $serviceApp.ServiceApplicationPoolName $serviceApp.ServiceApplicationPoolAcctName $acctNode.Password
                                                }
                                            }
										}
		"Excel Services Application Web Service Application" 	{
																	$appPoolAcctName = $serviceApp.ServiceApplicationPoolAcctName
																	$acctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Name='$appPoolAcctName']")												
																	New-ExcelApp $serviceApp.DisplayName $serviceApp.ServiceApplicationPoolName $serviceApp.ServiceApplicationPoolAcctName $acctNode.Password								
																}
		"Word Automation Services" 	{						
										$appPoolAcctName = $serviceApp.ServiceApplicationPoolAcctName
										$acctNode=$FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Name='$appPoolAcctName']")
										$prefixedDBName = $DBPrefix + $serviceApp.Database.DBName
										New-WordApp $serviceApp.DisplayName $serviceApp.ServiceApplicationPoolName $serviceApp.Database.DBServer $prefixedDBName $serviceApp.ServiceApplicationPoolAcctName $acctNode.Password
									}
		
		"SharePoint Server Search" 	{						
										$searchServer = Get-ServerNameByService $FarmConfigXML "SharePoint Server Search"
										if($searchServer -eq $serverName)
										{
                                            $appPoolAcctName = $serviceApp.ServiceApplicationPoolAcctName
											$acctNode=$FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Name='$appPoolAcctName']")
											$prefixedDBName = $DBPrefix + $serviceApp.SearchAdminDatabase.DBName
                                            
                                            #Get Crawl Account Creds
                                            $crawlAcctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type='Search Crawl']")
                                            $crawlAcct = $crawlAcctNode.Name
                                            $crawlPass = $crawlAcctNode.Password

                                            #Get Search Service Creds
                                            $searchAcctNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type='Search Service']")
                                            $searchServAcct = $searchAcctNode.Name
                                            $searchServPass = $searchAcctNode.Password
											    
                                            if($buildVer -eq "14")
                                            {
                                                New-2010EnterpriseSearchApp $serviceApp.DisplayName $serviceApp.ServiceApplicationPoolName $serviceApp.SearchAdminDatabase.DBServer $prefixedDBName $serviceApp.ServiceApplicationPoolAcctName $acctNode.Password $searchServer	$crawlAcct $crawlPass $searchServAcct $searchServPass								
										    }
                                            elseif($buildVer -eq "15")
                                            {
                                                New-2013EnterpriseSearchApp $serviceApp.DisplayName $serviceApp.ServiceApplicationPoolName $serviceApp.SearchAdminDatabase.DBServer $prefixedDBName $serviceApp.ServiceApplicationPoolAcctName $acctNode.Password $searchServer	$crawlAcct $crawlPass $searchServAcct $searchServPass							
                                            }
                                            
                                        }
                                        
									}
	}
}	


  
#EndRegion
