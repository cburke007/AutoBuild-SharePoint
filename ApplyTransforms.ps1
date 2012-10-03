# Define  any transforms to the existing Config XML
#$ApplyPrefix = Read-Host "Specify additional Transforms to this Pre-Defined build? (Y or N - blank/default=N) "
if($ApplyPrefix -eq "Y" -or $ApplyPrefix -eq "y")
{
    # Get the Farm Prefix and Service Account Prefix
    $FarmPrefix = Read-Host "Enter a Prefix for to be used in the Farm (MAX 5 chars - ex. Dev or Prod) "   
    $FarmPrefix = $FarmPrefix + "_"
    
    $PrefixDBs = Read-Host "Use the Farm Prefix for the Database Names? (Y or N - blank/default=Y) "
    $PrefixUsers = Read-Host "Use the Farm Prefix for the Service Accounts? (Y or N - blank/default=Y) "
            
    if ($PrefixUsers -eq "Y" -or $PrefixUsers -eq "y" -or $PrefixUsers -eq "")
    {
        $AcctPrefix = $FarmPrefix
    }
    else{$AcctPrefix = ""}
    
    if ($PrefixDBs -eq "Y" -or $PrefixDBs -eq "y" -or $PrefixDBs -eq "")
    {
        $DBPrefix = $FarmPrefix
    }
    else{$DBPrefix = ""}
            
    
    $FarmConfigXML.Customer.Farm.SetAttribute("DBPrefix", $DBPrefix)
    $FarmConfigXML.Customer.Farm.SetAttribute("UserPrefix", $AcctPrefix)
}
