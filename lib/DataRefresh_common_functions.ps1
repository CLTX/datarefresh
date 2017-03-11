 function GetSCVolumeInfo {
    param(
        [Parameter(Mandatory=$True)]
        [string] $serverName,
        [Parameter(Mandatory=$True)]
        [string] $diskSerialNumber
    )

        $srvIndex = [int]$serverName.Substring($serverName.Length - 2)
        $cmlIndex = ($srvIndex) % 2 #which storage center?
        $scVol = Get-SCVolume -ConnectionName $appSettings["StorageCenterHosts"][$cmlIndex] -SerialNumber $diskSerialNumber -ErrorAction SilentlyContinue
        
        if(($scVol -eq $null) -or ($scVol -eq "") -or ($scVol -eq "0")) {
            Log-Warning -message "Volume for $serverName not found on correct SAN host."

            $cmlIndex = ($srvIndex + 1) % 2 #which storage center?  Based on Odd/Even
            $scVol = Get-SCVolume -ConnectionName $appSettings["StorageCenterHosts"][$cmlIndex] -SerialNumber $diskSerialNumber -ErrorAction SilentlyContinue
        }

        $rtnObj =  New-Object PSObject
        $rtnObj | Add-Member -MemberType NoteProperty StorageCenter $appSettings["StorageCenterHosts"][$cmlIndex]
        $rtnObj | Add-Member -MemberType NoteProperty SCVolume $scVol

        return $rtnObj

}

  function Get-SCVolumeInfoFromIndex {
    param([Parameter(Mandatory=$True)]
        [Int[]] $cmlIndexes,
        [String] $StorageCenterName
    )

        $scVolInfoList = @()
        foreach($cmlIndex in $cmlIndexes) {
            $scVol = Get-SCVolume -ConnectionName $StorageCenterName -Index $cmlIndex
            if($scVol -ne $null) {
                    
                $scVolInfo =  New-Object PSObject
                $scVolInfo | Add-Member -MemberType NoteProperty StorageCenter $StorageCenterName
                $scVolInfo | Add-Member -MemberType NoteProperty SCVolume $scVol

                $scVolInfoList += $scVolInfo
            }
        }
        
        return $scVolInfoList
  }

  function RenameOldVolume {

    param(
       [VolumeInformation] $volumeInfo 
    )
    #Rename Old Volume
    Log -message "Rename the Old Volume $($volumeInfo.Name)"

    $oldSCVolume = $volumeInfo.SCVolumeInfo.SCVolume 
    $oldVolumeName = "{0}_OLD" -f $oldSCVolume.Name 
    Log -message "Rename Old Drive $($oldSCVolume.Name) to $($oldVolumeName)"
    Set-SCVolume -SCVolume $oldSCVolume -Name $oldVolumeName -ConnectionName $volumeInfo.StorageCenterName     

    return $oldSCVolume
  }

  function Create-NewVolume {
     param(
           [VolumeInformation] $volumeInfo,
           [VolumeInformation] $srcVolumeInfo,
           [System.Object[]] $replayInfoList 
        )
        Log -message "Create New Volume $($volumeInfo.GenerateVolumeName())"
        If($volumeInfo.StorageCenterName -eq $srcVolumeInfo.StorageCenterName) {
            $vIndex = $srcVolumeInfo.Index
        }
        Else {
            $vIndex = $srcVolumeInfo.RemoteVolumeIndex
        }

        #create new Volume
        # NOTE:  As [0] refers to the first element of a PS array, [-1] object in an array points to the last object on it. 
        $volumeFolder = Get-SCVolumeFolder -Name $volumeInfo.Folder -ConnectionName $volumeInfo.StorageCenterName
        $replayInfo = $replayInfoList | Where-Object { $_.VolumeIndex -eq $vIndex }
        $newSCVolume = New-SCVolume -SourceSCReplay $replayInfo.replay[-1] -Name $volumeInfo.GenerateVolumeName() -ConnectionName $replayInfo.StorageCenterName -ParentSCVolumeFolder $volumeFolder
        $volumeInfo | Add-Member -MemberType NoteProperty NewVolume $newSCVolume
  }


  function Get-ReplayInformationList {
    param(
        [VolumeInformation[]] $srvVolumes
    )

    $replayInfoList = @()
    ForEach ($srcVolume in $srvVolumes) {
        Log -message "Get Source Replay for $($srcVolume.Name)"
        $replayInfo = New-Object PSCustomObject
        $tempReplay = Get-SCReplay -ConnectionName $srcVolume.StorageCenterName -SourceVolumeIndex $srcVolume.Index  -description $replayDescription
        if($tempReplay -eq $null) {
            throw "Replay for Source Volume Does Not Exist."
        }
        $replayInfo | Add-Member NoteProperty replay $tempReplay
        $replayInfo | Add-Member NoteProperty StorageCenterName $srcVolume.StorageCenterName
        $replayInfo | Add-Member NoteProperty VolumeIndex $srcVolume.Index
        $replayInfoList += $replayInfo
        $replayFreezeTime = $tempReplay.FreezeTime

        Log -message "Get Source Replicated Replay for $($srcVolume.Name)"
        $replayInfo = New-Object PSCustomObject
        if($srcVolume.RemoteStorageCenterName -ne $null) {
            $tempReplay = Get-SCReplay -ConnectionName $srcVolume.RemoteStorageCenterName -SourceVolumeIndex $srcVolume.RemoteVolumeIndex -FreezeTime $replayFreezeTime
            if($tempReplay -eq $null) {
                throw "Replication Replay for Source Volume Does Not Exist."
            }
        }
        $replayInfo | Add-Member NoteProperty replay $tempReplay
        $replayInfo | Add-Member NoteProperty StorageCenterName $srcVolume.RemoteStorageCenterName
        $replayInfo | Add-Member NoteProperty VolumeIndex $srcVolume.RemoteVolumeIndex
        $replayInfoList += $replayInfo
    }

    return $replayInfoList
  }

<#################################################
    Removes the volumes from each index in the array
    * Requires the Storage Center Name to be passed in
    * future enhancement to be able to removed indexes that span different vmware clusters
####################################################>
  function Remove-Volumes {
    param([Int[]] $CMLIndexes,
    [string] $StorageCenterName,
    [bool] $isSameCluster = $true)


    GetAllSCConnections 
    OpenVCenter

    Log -message "Get Volumes from Indexes"
    $scVolInfoList = Get-SCVolumeInfoFromIndex -cmlIndexes $CMLIndexes -StorageCenterName $StorageCenterName

    $cluster = $null 
    $vmHosts = $null 

    Log -message "Get VMWare Cluster and Host Information"
    if(!$isSameCluster -or $vmHosts -eq $null) {
        $scVolInfo = $scVolInfoList[0]
        $scVMHostMap = $(Get-SCVolumeMap -ConnectionName $scVolInfo.StorageCenter -VolumeIndex $scVolInfo.SCVolume.Index)[0] #Get the first host in the old Volume Mapping
        $scVMHost = Get-SCServer -ConnectionName $scVolInfo.StorageCenter -Name $scVMHostMap.ServerName #Use the host to get the cluster
        $scVMCluster = Get-SCServer -ConnectionName $scVolInfo.StorageCenter -Name $scVMHost.ParentServer #Use the host to get the cluster
        
        $cluster = Get-Cluster -Name $scVMCluster.Name
        $vmHosts = Get-VMHost -Location $cluster
        $esxClis = Get-EsxCli -VMHost $vmHosts
    }
    else {
        throw "Feature not yet supported!" 
    }

    Log -message "Generating Canonical Name Information"   
    $canonicalNames = @()
    $volumeIndexes = @()
    foreach($scVolInfo in $scVolInfoList)
    {
        $canonicalNames = $scVolInfoList.SCVolume.DeviceId | ForEach-Object { return "naa.$_" }
        $volumeIndexes = $scVolInfoList.SCVolume.Index
    }

    Log -message "Threaded Task: Detach Disks"
    Detach-Disk -sessionId $global:DefaultVIServer.SessionId -vcServer $global:DefaultVIServer.Name -vmHostNames $VMHosts.Name -CanonicalName $canonicalNames
    
    Log -message "Remove Volumes from Storage Center"
    foreach($scVolumeInfo in $scVolInfoList) {
        $volume = $scVolumeInfo.SCVolume

        Log -message "Removing $($volume.Name)"
        Remove-SCVolumeMap -ConnectionName $scVolumeInfo.StorageCenter -SCServer $scVMCluster -SCVolume $volume -Confirm:$false
        Remove-SCVolume -ConnectionName $scVolumeInfo.StorageCenter -SCVolume $volume -Confirm:$false -SkipRecycleBin
    }

    Log -message "Theaded-Task: Rescan HBAs"
    ### NEW: Using the new RescanHBASerial to perform rescan. In This case we are looking for DEAD LUNs.
    Rescan-HBAsESXiserial -esxCliList $esxCliList -action delete

    
    Log -message "Remove Detached Devices."
    $esxClis | ForEach-Object { 
        foreach($conName in $canonicalNames) {
            $_.storage.core.device.detached.remove($false, $conName) 
        }
    }
  }

  function Remove-VMwareVolume {
    param([string]$storageCenterName,
        [string[]] $vmHostNames,
        [int] $volumeIndex,
        [string] $canonicalName,
        [SCVolume] $scVolume)

        Detach-Disk -sessionId $global:DefaultVIServer.SessionId -vcServer $global:DefaultVIServer.Name -vmHostNames $vmHostNames -CanonicalName $canonicalName
        
        Start-Sleep 30 #allow vmware to finish up before removing the volume mapping in Compellent (otherwise could trigger an alert)

        $scVMHostMap = $(Get-SCVolumeMap -ConnectionName $storageCenterName -VolumeIndex $volumeIndex)[0] #Get the first host in the old Volume Mapping
        $scVMHost = Get-SCServer -ConnectionName $storageCenterName -Name $scVMHostMap.ServerName #Use the host to get the cluster
        $scVMCluster = Get-SCServer -ConnectionName $storageCenterName -Name $scVMHost.ParentServer #Use the host to get the cluster
        Remove-SCVolumeMap -ConnectionName $storageCenterName -SCServer $scVMCluster -SCVolume $volumeInfo.SCVolumeInfo.SCVolume -Confirm:$false
        
        Remove-SCVolume -ConnectionName $volumeInfo.StorageCenterName -SCVolume $scVolume -Confirm:$false

  }

<#######################################  Utility Functions #####################################################>
<#
    Takes a comma seperated string of volumes and formats them
    For use in DataRefresh processes.
#>
  function FormatVolumeArray {
    param([string] $volumeString)
    
    
    Log -message "Format volume string and convert to array" 
    $volumes = @()
    $volumeString.Split(",") | ForEach { $volumes += "{0}:\" -f $_ }
    Log -message "Volumes: $volumes" 
    return $volumes

  }

## Function to create the drives and map them
  function Adding_drives_to_server 
    {
    param ([System.Object[]] $srcserver,
    [System.Array[]] $destservers,
    [System.Object[]] $volarray,
    [System.Object[]] $replayinfoList)

    #create the drives and Map them to VMware
    $destinationServers = @()
    ForEach ($Name in $destservers) 
        {

        Log -message "Get Volume Information for $Name "
        $destSrvInfo = GetServerInformation -serverName $Name -accessPaths $volarray

        ForEach($volumeInfo in $destSrvInfo.Volumes) 
            {
            Log -message "Get Source Volume"
            #Gets the correct drive volume from the source server
            $srcVolume = $srcserver.Volumes | Where-Object { $_.accessPath -eq $volumeInfo.accessPath }
            
            #Rename volume and mark volume for removal
            $volumeInfo | Add-Member -MemberType NoteProperty OldVolume $(RenameOldVolume -volumeInfo $volumeInfo) 
            Create-NewVolume -srcVolumeInfo $srcVolume -volumeInfo $volumeInfo -replayInfoList $replayInfoList

            Log -message "Map $($volumeInfo.NewVolume.Name)"
            #Get the first host in the old Volume Mapping
            $scVMHostMap = $(Get-SCVolumeMap -ConnectionName $volumeInfo.StorageCenterName -VolumeIndex $volumeInfo.Index)[0] 
            
            #Use the host to get the cluster
            $scVMHost = Get-SCServer -ConnectionName $volumeInfo.StorageCenterName -Name $scVMHostMap.ServerName 
            
            #Use the host to get the cluster
            $scVMCluster = Get-SCServer -ConnectionName $volumeInfo.StorageCenterName -Name $scVMHost.ParentServer 
            #map the volume to the cluster
            $vMap = New-SCVolumeMap -SCVolume $volumeInfo.NewVolume -SCServer $scVMCluster -connectionName $volumeInfo.StorageCenterName 
            }
        $destinationServers += $destSrvInfo
        }
  }