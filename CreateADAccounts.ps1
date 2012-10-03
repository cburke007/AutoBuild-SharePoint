param([xml]$FarmConfigXML)

Import-Module ./AutoBuild-Module

# Get current script execution path
[string]$curloc = get-location

$netbios = Get-DomainNetBios

# Open/Create the Users.txt file    
$text = "$curloc\ServiceAccounts.txt"
#Get Current Date
$date = Get-Date

#Initiate the Service Account Creation Log
"Service Account Creation Log - $date" | out-file "$text"
 "" | out-file "$text" -append

$FarmConfigXML = [xml](get-content "$curloc\FarmConfig.xml" -EA 0)

$usersNode = $FarmConfigXML.selectSingleNode("//Customer/Farm/FarmAccounts")

foreach($userNode in $usersNode.Account)
{
    New-ADUser $userNode.Name $userNode.Password
    
    $UserLogEntry = $userNode.Type + " = " + $netbios + "\" + $userNode.Name + " " + $userNode.Password
    
    $UserLogEntry | out-file "$text" -append
}
