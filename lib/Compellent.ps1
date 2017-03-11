
If ( !( Get-PSSnapin | Where-Object { $_.Name -eq "Compellent.StorageCenter.PSSnapin" } ) )
{
	Add-PSSnapin Compellent.StorageCenter.PSSnapin 
}

function GetSCConnection([string]$storageCenter)
{
    ## Connect to the Compellent Storage Center
    Log -message "Connecting to Storage Center: $storageCenter"

    #Check if we are already connected and then return the saved connection (this improves performance)
    $list = Get-SCConnection -List | Where-Object{ $_.Name -eq $storageCenter }
    If($list.length -eq 0) { 
        $scConn = Get-SCConnection -HostName $storageCenter -User $appSettings["AdminUser"] -Password $appSettings["AdminUserPassword"] -Save $storageCenter
    }
    Else {
        $scConn = Get-SCConnection -Name $storageCenter
    }

    return $scConn
}

function GetAllSCConnections {
    
    If($global:scConnectionList -eq $null) {
        $global:scConnectionList = @()
        ForEach($storageCenter in $appSettings["StorageCenterHosts"]) {
            $global:scConnectionList += GetSCConnection -storageCenter $storageCenter | out-null
            Log -message "Conntected to $($storageCenter)"
        }
    }
    return $global:scConnectionList 

}

<#############################################################
Find's volume information based on name search criteria
    * a future improvement would be to allow RegEx searching
#############################################################>
function GetVolumeInfo([string]$searchTerm)
{
    $volInfoList = @();
    foreach($scName in $appSettings["StorageCenterHosts"]) {
        
        $scConn = GetSCConnection($scName);
        $vols = Get-SCVolume -ConnectionName $scName | where { $_.Name -like $searchTerm };
        foreach($vol in $vols) {
            $volInfo = new-Object PSObject;
            $volInfo | Add-Member NoteProperty VolumeName($vol.Name);
            $volInfo | Add-Member NoteProperty LogicalPath($vol.LogicalPath);
            $volInfo | Add-Member NoteProperty StorageCenter($scName);
            $volInfo | add-member Noteproperty Size $("{0:N1}" -f $(ConvertDiskSize($vol.Size)));
            $volInfo | add-member Noteproperty Consumed $("{0:N1}" -f $(ConvertDiskSize($vol.TotalDiskSpaceConsumed)));

            
            $vmaps = Get-SCVolumeMap -ConnectionName $scName -SCVolume $vol;
            if($vmaps) {

                $volInfo | Add-Member NoteProperty Lun($vmaps.Item(0).Lun);             
                
                $maps = ""
                foreach($vmap in $vmaps)
                {
                    if($maps -notmatch $vmap.ServerName) {
                        $maps += $vmap.ServerName + " ";
                    }
                }
                $volInfo | Add-Member NoteProperty Mappings($maps);
            }
            else
            {
                # No mappings found
                $volInfo | Add-Member NoteProperty Mappings("None");
            }
            $volInfoList += $volInfo;
        }
    }

  
    if(!$vm) {
        throw "Volume $volumeName not found!";
    }

    return $volInfoList;
}

<#################################################
Finds a volume based on the lun number
    * A future enhancement would be to also allow search naa id.
####################################################>
function GetVolumeNameFromLun([int]$lun) {

    $volumes = @();
    $volNames = @();
    foreach($scName in $appSettings["StorageCenterHosts"]) {
        
        $scConn = GetSCConnection($scName);
        $vmaps = Get-SCVolumeMap -ConnectionName $scName -LUN $lun;
        if($vmaps) {
            foreach($vmap in $vmaps) {
                
                if($volNames -notcontains $vmap.VolumeName) {
                    $info = new-Object PSObject;
                    $info | Add-Member NoteProperty VolumeName($vmap.VolumeName);
                    $info | Add-Member NoteProperty StorageCenter($scName);
                    $volNames += $vmaps.VolumeName;
                    $volumes += $info;
                }

            }
        }
    }

    return $volumes;

}


<##################################################################
# Gets the most replay of a volume taken by a replay manager
####################################################################>
function GetMostRecentReplay($scConn, [string] $backupSetName, [string] $volName)
{
    #### Finding Snapshot in EM ####
    Log -message "Finding the Snapshot";
    $rdmVol = Get-SCVolume -Connection $scConn -Name $volName;
    $replays = Get-SCReplay -SourceSCVolume $rdmVol -Connection $scConn -Description $backupSetName;
    $mostRecentReplay = $replays[$replays.Length - 1];
    return $mostRecentReplay;
}


<##################################################################
# Gets the most replay of a volume taken by a replay manager
####################################################################>
function FindReplayByName {
    param ([string] $connectionName, 
    [string] $volumeName,     
    [string]$description)


    #### Finding Snapshot in EM ####
    Log -message "Finding the Snapshot";
    $rdmVol = Get-SCVolume -ConnectionName $connectionName -Name $volumeName;
    $replays = Get-SCReplay -SourceSCVolume $rdmVol -ConnectionName $connectionName -Description $description | Where-Object {$_.Description.Contains($searchName)}
    
    #shouldn't happen but in the event that there are more than 1, we will return only the first one.
    $replay = $replays[$replays.Length - 1]; 
    return $replay;
}


<#################################################################
# Create a volume from the replay passed in
##################################################################>
function CreateVolumeFromReplay($scConn, $serverName, $serverMapping, $folderName, $replay, $volName)
{
    Log -message "Cloning Snapshot - $($serverName) | New Volume: $($volName)"
    $volumeFolder = Get-SCVolumeFolder -Name $($folderName) -Connection $scConn
    $newSCVolume = New-SCVolume -SourceReplay $replay -Name $volName -connection $scConn -ParentSCVolumeFolder $volumeFolder
    $volIdentifer1 = $("naa." + $newSCVolume.DeviceId)
    $mapServer = Get-SCServer -connection $scConn -name $serverMapping
    $mapping = New-SCVolumeMap -SCVolume $newSCVolume -SCServer $mapServer -connection $scConn

    if ($server.ServerMapping -eq "DAE VMware Cluster")
    {
        $foundVirtual = $true
    }

}

function GetAsyncReplications {
    
    if($global:asyncReplications -eq $null) {
        $global:asyncReplications = @()

        GetAllSCConnections | ForEach-Object {
            $global:asyncReplications += Get-SCAsyncReplication -ConnectionName $_.Host
        }
    }

    return $global:asyncReplications
}


<#########################################################################
    Utility Functions for Compellent
##########################################################################>
function ConvertDiskSize([string]$size)
{
    if($size -match " TB")
    { $a = ([single]($size -replace " TB", "")) * 1000
    }
    elseif($size -match " GB")
    { $a = ([single]($size -replace " GB", ""))
    }
    elseif($size -match " MB")
    { $a = ([single]($size -replace " MB", "")) / 1000
    }
    return $a
}

function GetCompellentVolume {

    param([string] $volume,
        [string] $volumes)
     $cmlIndex = ([int]$server.Name.Substring($server.Name.Length - 2)) % 2 #which storage center?
}