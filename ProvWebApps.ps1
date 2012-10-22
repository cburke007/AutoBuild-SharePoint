Import-Module ./AutoBuild-Module -force
Import-Module ./ProvSA-Module -force

$acctNode=$FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@Type='Default Site AppPool']")
$siteAppPoolUser = $acctNode.Name
$siteAppPoolPass = $acctNode.Password

$netbios = (Get-LocalLogonInformation).DomainShortName	
$domSiteAppPoolUser = "$netbios\$siteAppPoolUser" 

#Check/Create Managed Account
Set-ManagedAcct $domSiteAppPoolUser $siteAppPoolPass

#$ScriptVarsxml = [xml](get-content "$curloc\ScriptVars.xml" -EA 0)
#
## Are we building the initial Web application sites?
#$buildInitialSites = Read-Host "Build Initial Sites? (Y or N - blank/default=N) "
#if ($buildInitialSites -eq "Y" -or $buildInitialSites -eq "y")
#{
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "BuildInitialSites" $buildInitialSites $ScriptVarsxml)) > $null
#    #Site Variables
#    $PortalName = Read-Host "Enter the name of the first Web Application "
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "PortalName" $PortalName $ScriptVarsxml)) > $null
#    $PortalHostHeader = Read-Host "Enter the Host Header "
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "PortalHostHeader" $PortalHostHeader $ScriptVarsxml)) > $null
#    $PortalPort = Read-Host "Enter the Port "
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "PortalPort" $PortalPort $ScriptVarsxml)) > $null
#    $PUseSSL = Read-Host "Use SSL? (Y or N - blank/default=N)  "
#    if ($PUseSSL -eq "Y" -or $PUseSSL -eq "y")
#    {
#        $PortalUseSSL = $true
#        $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "PortalUseSSL" $PortalUseSSL $ScriptVarsxml)) > $null
#        $PortalPrefix = "https://"
#        $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "PortalPrefix" $PortalPrefix $ScriptVarsxml)) > $null
#    }
#    else{$PortalUseSSL = $false;$ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "PortalUseSSL" $PortalUseSSL $ScriptVarsxml)) > $null;$PortalPrefix = "http://";$ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "PortalPrefix" $PortalPrefix $ScriptVarsxml)) > $null}
#    $PortalLCID = "1033"
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "PortalLCID" $PortalLCID $ScriptVarsxml)) > $null
#    #List Template Names
#    "Name                         Title                                                                                                                          
#    ----                         -----                                                                                                                          
#    GLOBAL#0                     Global template                                                                                                                
#    STS#0                        Team Site                                                                                                                      
#    STS#1                        Blank Site                                                                                                                     
#    STS#2                        Document Workspace                                                                                                             
#    MPS#0                        Basic Meeting Workspace                                                                                                        
#    MPS#1                        Blank Meeting Workspace                                                                                                        
#    MPS#2                        Decision Meeting Workspace                                                                                                     
#    MPS#3                        Social Meeting Workspace                                                                                                       
#    MPS#4                        Multipage Meeting Workspace                                                                                                    
#    CENTRALADMIN#0               Central Admin Site                                                                                                             
#    WIKI#0                       Wiki Site                                                                                                                      
#    BLOG#0                       Blog                                                                                                                           
#    SGS#0                        Group Work Site                                                                                                                
#    TENANTADMIN#0                Tenant Admin Site                                                                                                              
#    ACCSRV#0                     Access Services Site                                                                                                           
#    ACCSRV#1                     Assets Web Database                                                                                                            
#    ACCSRV#3                     Charitable Contributions Web Database                                                                                          
#    ACCSRV#4                     Contacts Web Database                                                                                                          
#    ACCSRV#6                     Issues Web Database                                                                                                            
#    ACCSRV#5                     Projects Web Database                                                                                                          
#    BDR#0                        Document Center                                                                                                                
#    OFFILE#0                     (obsolete) Records Center                                                                                                      
#    OFFILE#1                     Records Center                                                                                                                 
#    OSRV#0                       Shared Services Administration Site                                                                                            
#    PPSMASite#0                  PerformancePoint                                                                                                               
#    BICenterSite#0               Business Intelligence Center                                                                                                   
#    SPS#0                        SharePoint Portal Server Site                                                                                                  
#    SPSPERS#0                    SharePoint Portal Server Personal Space                                                                                        
#    SPSMSITE#0                   Personalization Site                                                                                                           
#    SPSTOC#0                     Contents area Template                                                                                                         
#    SPSTOPIC#0                   Topic area template                                                                                                            
#    SPSNEWS#0                    News Site                                                                                                                      
#    CMSPUBLISHING#0              Publishing Site                                                                                                                
#    BLANKINTERNET#0              Publishing Site                                                                                                                
#    BLANKINTERNET#1              Press Releases Site                                                                                                            
#    BLANKINTERNET#2              Publishing Site with Workflow                                                                                                  
#    SPSNHOME#0                   News Site                                                                                                                      
#    SPSSITES#0                   Site Directory                                                                                                                 
#    SPSCOMMU#0                   Community area template                                                                                                        
#    SPSREPORTCENTER#0            Report Center                                                                                                                  
#    SPSPORTAL#0                  Collaboration Portal                                                                                                           
#    SRCHCEN#0                    Enterprise Search Center                                                                                                       
#    PROFILES#0                   Profiles                                                                                                                       
#    BLANKINTERNETCONTAINER#0     Publishing Portal                                                                                                              
#    SPSMSITEHOST#0               My Site Host                                                                                                                   
#    ENTERWIKI#0                  Enterprise Wiki                                                                                                                
#    SRCHCENTERLITE#0             Basic Search Center                                                                                                            
#    SRCHCENTERLITE#1             Basic Search Center                                                                                                            
#    SRCHCENTERFAST#0             FAST Search Center                                                                                                             
#    visprus#0                    Visio Process Repository"
#
#    $PortalTemplate = Read-Host "Enter the Template Name"
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "PortalTemplate" $PortalTemplate $ScriptVarsxml)) > $null
#    $PortalDB = $FarmPrefix + "SP2010_" + $PortalName + "_Content"
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "PortalDB" $PortalDB $ScriptVarsxml)) > $null
#    $PortalSiteName = "SharePoint - " + $FarmPrefix + $PortalName
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "PortalSiteName" $PortalSiteName $ScriptVarsxml)) > $null
#    $PortalAppPool = "SharePoint - " + $FarmPrefix + $PortalName
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "PortalAppPool" $PortalAppPool $ScriptVarsxml)) > $null
#    $PortalURL = $PortalPrefix + $PortalHostHeader
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "PortalURL" $PortalURL $ScriptVarsxml)) > $null
#    
#    $MySiteName = "MySites"
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "MySiteName" $MySiteName $ScriptVarsxml)) > $null
#    $MySiteHostHeader = Read-Host "Enter the Host Header for the MySites App "
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "MySiteHostHeader" $MySiteHostHeader $ScriptVarsxml)) > $null
#    $MySitePort = Read-Host "Enter the Port "
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "MySitePort" $MySitePort $ScriptVarsxml)) > $null
#    $MUseSSL = Read-Host "Use SSL? (Y or N - blank/default=No)  "    
#    if ($MUseSSL -eq "Y" -or $MUseSSL -eq "y")
#    {
#        $MySiteUseSSL = $true
#        $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "MySiteUseSSL" $MySiteUseSSL))
#        $MySitePrefix = "https://"
#        $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "MySitePrefix" $MySitePrefix))
#    }
#    else{$MySiteUseSSL = $false;$ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "MySiteUseSSL" $MySiteUseSSL $ScriptVarsxml)) > $null;$MySitePrefix = "http://";$ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "MySitePrefix" $MySitePrefix $ScriptVarsxml)) > $null}
#    $MySiteLCID = "1033"
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "MySiteLCID" $MySiteLCID $ScriptVarsxml)) > $null
#    $MySiteTemplate = "SPSMSITEHOST#0"
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "MySiteTemplate" $MySiteTemplate $ScriptVarsxml)) > $null 
#    $MySiteDB = $FarmPrefix + "SP2010_" + $MySiteName + "_Content"
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "MySiteDB" $MySiteDB $ScriptVarsxml)) > $null
#    $MySiteExtendedName = "SharePoint - " + $FarmPrefix + $PortalName
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "MySiteExtendedName" $MySiteExtendedName $ScriptVarsxml)) > $null
#    $MySiteAppPool = "SharePoint - " + $FarmPrefix + $PortalName
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "MySiteAppPool" $MySiteAppPool $ScriptVarsxml)) > $null
#    $MySiteURL = $MySitePrefix + $MySiteHostHeader
#    $ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "MySiteURL" $MySiteURL $ScriptVarsxml)) > $null
#}
#else{$buildInitialSites = "N";$ScriptVarsxml["Variables"].AppendChild((UpdateVarsxml "BuildInitialSites" $buildInitialSites $ScriptVarsxml)) > $null}
#
#
#
#
#
#$Edition = ReadVarsxml "Edition" $ScriptVarsxml
#$IsCA = ReadVarsxml "IsCA" $ScriptVarsxml
#$DBServer = ReadVarsxml "DBServer" $ScriptVarsxml
#$FarmPrefix = ReadVarsxml "FarmPrefix" $ScriptVarsxml
#
##Region Create Content Web Apps
#$PortalName = ReadVarsxml "PortalName" $ScriptVarsxml
#$PortalHostHeader = ReadVarsxml "PortalHostHeader" $ScriptVarsxml
#$PortalPort = ReadVarsxml "PortalPort" $ScriptVarsxml
#$PortalUseSSL = ReadVarsxml "PortalUseSSL" $ScriptVarsxml
#if ($PortalUseSSL -eq "True")
#{
#    $PortalUseSSL = $true
#}
#else
#{
#    $PortalUseSSL = $false
#}
#$PortalPrefix = ReadVarsxml "PortalPrefix" $ScriptVarsxml
#$PortalLCID = ReadVarsxml "PortalLCID" $ScriptVarsxml
#$PortalTemplate = ReadVarsxml "PortalTemplate" $ScriptVarsxml
#$PortalDB = ReadVarsxml "PortalDB" $ScriptVarsxml
#$PortalSiteName = ReadVarsxml "PortalSiteName" $ScriptVarsxml
#$PortalAppPool = ReadVarsxml "PortalAppPool" $ScriptVarsxml
#$PortalURL = ReadVarsxml "PortalURL" $ScriptVarsxml
#
#$MySiteName = ReadVarsxml "MySiteName" $ScriptVarsxml
#$MySiteHostHeader = ReadVarsxml "MySiteHostHeader" $ScriptVarsxml
#$MySitePort = ReadVarsxml "MySitePort" $ScriptVarsxml
#$MySiteUseSSL = ReadVarsxml "MySiteUseSSL" $ScriptVarsxml
#if ($MySiteUseSSL -eq "True")
#{
#    $MySiteUseSSL = $true
#}
#else
#{
#    $MySiteUseSSL = $false
#}
#$MySitePrefix = ReadVarsxml "MySitePrefix" $ScriptVarsxml
#$MySiteLCID = ReadVarsxml "1033" $ScriptVarsxml
#$MySiteTemplate = ReadVarsxml "MySiteTemplate" $ScriptVarsxml
#$MySiteDB = ReadVarsxml "MySiteDB" $ScriptVarsxml
#$MySiteExtendedName = ReadVarsxml "MySiteExtendedName" $ScriptVarsxml
#$MySiteAppPool = ReadVarsxml "MySiteAppPool" $ScriptVarsxml
#$MySiteURL = ReadVarsxml "MySiteURL" $ScriptVarsxml
#
#
#$GetSPWebApplication = Get-SPWebApplication | Where-Object {$_.DisplayName -eq $PortalName}
#If ($GetSPWebApplication -eq $Null)
#{
#    Write-Host -ForegroundColor Cyan "- Creating Web App `"$PortalName`"..."
#	If ($PortalUseClaims -eq "1")
#	{
#		## Configure new web app to use Claims-based authentication
#		$PortalAuthProvider = New-SPAuthenticationProvider -UseWindowsIntegratedAuthentication
#		New-SPWebApplication -Name $PortalSiteName -ApplicationPoolAccount $domSiteAP -ApplicationPool $PortalAppPool -DatabaseName $PortalDB -HostHeader $PortalHostHeader -Url $PortalURL -Port $PortalPort -SecureSocketsLayer:$PortalUseSSL -AuthenticationProvider $PortalAuthProvider | Out-Null
#	}
#	Else
#	{
#		## Create the web app using Classic mode authentication
#		New-SPWebApplication -Name $PortalSiteName -ApplicationPoolAccount $domSiteAP -ApplicationPool $PortalAppPool -DatabaseName $PortalDB -HostHeader $PortalHostHeader -Url $PortalURL -Port $PortalPort -SecureSocketsLayer:$PortalUseSSL | Out-Null
#	}
#	Write-Host -ForegroundColor Cyan "- Creating Site Collection `"$PortalURL`"..."
#	## Verify that the Language we're trying to create the site in is currently installed on the server
#    $PortalCulture = [System.Globalization.CultureInfo]::GetCultureInfo(([convert]::ToInt32($PortalLCID)))
#	$PortalCultureDisplayName = $PortalCulture.DisplayName
#	If (!($InstalledOfficeServerLanguages | Where-Object {$_ -eq $PortalCulture.Name}))
#	{
#	    Write-Warning " - You must install the `"$PortalCulture ($PortalCultureDisplayName)`" Language Pack before you can create a site using LCID $PortalLCID"
#	}
#	Else
#	{
#		New-SPSite -Url $PortalURL -OwnerAlias $domFarmAdmin -SecondaryOwnerAlias $domSiteAdmin -ContentDatabase $PortalDB -Description $PortalName -Name $PortalName -Template $PortalTemplate -Language $PortalLCID | Out-Null    		
#	    Write-Host -ForegroundColor Cyan "- Launching $PortalURL..."
#	    #Start-Process "${env:ProgramFiles(x86)}\Internet Explorer\iexplore.exe" "$PortalUrl" -WindowStyle Minimized
#    }
#}
#Else
#{
#	Write-Host -ForegroundColor Cyan "- Web app $PortalName already exists, continuing..."
#}
##EndRegion
