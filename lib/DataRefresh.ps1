
function GetServerInformation {
    param([string] $serverName,
        [string[]] $accessPaths )

    $global:serverObj = New-Object PSObject
    $global:serverObj | Add-Member -MemberType NoteProperty Name $serverName
    $global:serverObj | Add-Member -MemberType NoteProperty Volumes @()
    
    $serverObj.Volumes = Get-VolumeInformation -serverName $serverName -accessPaths $accessPaths

    return $global:serverObj
}

function Get-VolumeInformation {
    param(
        [string] $serverName,
        [string[]] $accessPaths
    )
    
    Log -message "Getting Volume Information for $($serverName)"
    $vmVolumeInfoList = Get-CMLVolume -Server $serverName | Where-Object { $_.AccessPaths -in $accessPaths}

    $global:volumes = @()
    ForEach ($vmVolumeInfo in $vmVolumeInfoList) { 
        
        Log -message "Gathering Volume Data For $($vmVolumeInfo.AccessPaths)"
        $volumeInfo = New-Object VolumeInformation        
        $volumeInfo.AccessPath = $vmVolumeInfo.AccessPaths
        $volumeInfo.ServerName  = $serverName #Provided for convenience of volume info object
        $volumeInfo.SerialNumber = $vmVolumeInfo.DiskSerialNumber
        $volumeInfo.Label = $vmVolumeInfo.Label

        $scVolInfo = GetSCVolumeInfo -serverName $serverName -diskSerialNumber $vmVolumeInfo.DiskSerialNumber
        $volumeInfo | Add-Member -MemberType NoteProperty SCVolumeInfo $scVolInfo
        $scVol = $scVolInfo.SCVolume
        $volumeInfo.Name = $scVol.Name
        $volumeInfo.Index = $scVol.Index
        $volumeInfo.DeviceId = $scVol.DeviceId
        $volumeInfo.Folder = $scVol.ParentFolder
        $volumeInfo.StorageCenterName = $scVolInfo.StorageCenter

        If($scVol.IsMirrored -or $scVol.IsReplicated) {
        
            $repl = GetAsyncReplications | Where-Object { $_.SourceVolumeIndex -eq $volumeInfo.Index }
            $volumeInfo.RemoteStorageCenterName = $repl.RemoteSystemName
            $volumeInfo.RemoteVolumeIndex = $repl.RemoteVolumeIndex
        }

        $global:volumes += $volumeInfo
    }

    return $global:volumes
}


function RemoveVolumeAccessPath {
    param([VolumeInformation] $volumeInfo )

    Remove-CMLVolumeAccessPath -AccessPath $volumeInfo.AccessPath -Server $volumeInfo.ServerName -DiskSerialNumber $volumeInfo.SerialNumber -Force -Confirm:$false
}

function AddVolumeAccessPath {
    param([VolumeInformation] $volumeInfo)

    Add-CMLVolumeAccessPath -AccessPath $volumeInfo.AccessPath -Server $volumeInfo.ServerName -DiskSerialNumber $volumeInfo.SerialNumber -Confirm:$false
}

Function CreateAndMapDrives {
  param ([Parameter(Mandatory=$True)][string]$servernames, 
  [Parameter(Mandatory=$True)][System.Array]$Volumes,
  [Parameter(Mandatory=$True)][System.Object]$ReplayInfoList)
  
#create the drives and Map them to VMWare
  $global:destinationServers = @()
  ForEach ($serverName in $serverNames) {

    Log -message "Get Volume Information for $($serverName) "
    $destSrvInfo = GetServerInformation -serverName $serverName -accessPaths $volumes

    ForEach($volumeInfo in $destSrvInfo.Volumes) {
        Log -message "Get Source Volume"
        #Gets the correct drive volume from the source server
        $srcVolume = $srcSrvInfo.Volumes | Where-Object { $_.accessPath -eq $volumeInfo.accessPath }
         
        $volumeInfo | Add-Member -MemberType NoteProperty OldVolume $(RenameOldVolume -volumeInfo $volumeInfo)  #Rename volume and mark volume for removal

        Create-NewVolume -srcVolumeInfo $srcVolume -volumeInfo $volumeInfo -replayInfoList $replayInfoList

        Log -message "Map $($volumeInfo.NewVolume.Name)"
        $scVMHostMap = $(Get-SCVolumeMap -ConnectionName $volumeInfo.StorageCenterName -VolumeIndex $volumeInfo.Index)[0] #Get the first host in the old Volume Mapping
        $scVMHost = Get-SCServer -ConnectionName $volumeInfo.StorageCenterName -Name $scVMHostMap.ServerName #Use the host to get the cluster
        $scVMCluster = Get-SCServer -ConnectionName $volumeInfo.StorageCenterName -Name $scVMHost.ParentServer #Use the host to get the cluster
        $vMap = New-SCVolumeMap -SCVolume $volumeInfo.NewVolume -SCServer $scVMCluster -connectionName $volumeInfo.StorageCenterName #map the volume to the cluster

    }
    $global:destinationServers += $destSrvInfo
  }
  return $global:destinationServers     
}  


function OfflineAndRemove-Disk {
  param (
  [Parameter(Mandatory=$True)][VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$vm,
  [Parameter(Mandatory=$True)][VolumeInformation]$volumeInfo)

    $OS_Volume = Get-CMLDiskDevice -SerialNumber $volumeInfo.SerialNumber -server $volumeInfo.ServerName 
    $VM_Volume = Get-HardDisk -VM $vm | Where-Object { $_.ScsiCanonicalName -eq $volumeInfo.CanonicalName }

    if (($OS_Volume.Status -eq "Online") -and ($VM_Volume -ne $null))
        {
        Log -message "Taking volume Offline and Removing it from Vmware" 
        Set-CMLDiskDevice -Offline -SerialNumber $volumeInfo.SerialNumber -Server $volumeInfo.ServerName -Confirm:$false
        Remove-HardDisk -HardDisk $VM_Volume -DeletePermanently -Confirm: $false
        }
    elseif (($OS_Volume.Status -eq "Offline") -and ($VM_Volume -ne $null))
        {
        Log -message "Volume was already Offline -- Removing it from Vmware"
        Remove-HardDisk -HardDisk $VM_Volume -DeletePermanently -Confirm: $false
        }
    else
        { throw "Disk not available in Windows or Vmware" }
}
