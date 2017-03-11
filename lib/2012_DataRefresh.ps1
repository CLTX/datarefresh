function GetServerInformation_2012 {
    param([string] $serverName,
        [string[]] $DriveLetters )

    $global:serverObj = New-Object PSObject
    $global:serverObj | Add-Member -MemberType NoteProperty Name $serverName
    $global:serverObj | Add-Member -MemberType NoteProperty volumes (Get-VolumeInformation_2012 -serverName $serverName -DriveLetters $DriveLetters)
    return $global:serverObj
}

function Get-VolumeInformation_2012 {
    param(
        [string] $serverName,
        [string[]] $DriveLetters
    )
    
	$global:volumes = @()
	foreach ($DriveLetter in $DriveLetters) {
		Log -message "Getting Disk, Partition, and Volume Information for $($DriveLetter) Drive on $($serverName) " 
	
        #Remote object that collects all information from 2012 and return it back
		$RemoteDiskObject = Invoke-Command -ComputerName $serverName -ScriptBlock {
            $remoteVolumeObject = new-object PSObject;
            $volumeObject = get-volume ;
            $partitionObject = get-partition;
            $diskObject = get-disk;
            $remoteVolumeObject | Add-Member -MemberType NoteProperty volumeObject $volumeObject;
            $remoteVolumeObject | Add-Member -MemberType NoteProperty partitionObject $partitionObject;
            $remoteVolumeObject | Add-Member -MemberType NoteProperty diskObject $diskObject;
            return $remoteVolumeObject
        }
        $RemoteVolume = $RemoteDiskObject.volumeObject | where {$_.driveLetter -eq $DriveLetter}
        $RemotePartition = $RemoteDiskObject.partitionObject | where {$_.driveLetter -eq $DriveLetter}
        $RemoteDisk = $RemoteDiskObject.diskObject | where {$RemotePartition.DiskId -eq $_.ObjectId}
	
        #Building the New Volume Object
        Log -message  "Gathering Volume Data For $($DriveLetter)"
        $volumeInfo = New-Object VolumeInformation        
        $volumeInfo.AccessPath = $RemotePartition.AccessPaths[0]
        $volumeInfo.ServerName  = $serverName #Provided for convenience of volume info object
        $volumeInfo.SerialNumber = $RemoteDisk.SerialNumber
        $volumeInfo.Label = $RemoteVolume.FileSystemLabel

        $scVolInfo = GetSCVolumeInfo -serverName $serverName -diskSerialNumber $VolumeInfo.SerialNumber
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


## This function replaces the old Remove-CMLVolumeAccessPath. 
## Just need to use as parameter the same $volumeInfo and a CIM Session alrady established
  function RemoveVolumeAccessPath_2012 {
    param([VolumeInformation] $volumeInfo)
    [string]$filterString = 'DriveLetter=' + '"' + $volumeinfo.DriveLetter + ':"'
    $volume = Get-CimInstance -ComputerName $volumeInfo.ServerName -ClassName "Win32_Volume" -Filter "($filterString)"
	if ($null -ne $volume) {
		$volume.DriveLetter = $null
    }
}

## This function replaces the old Add-CMLVolumeAccessPath. 
## Need to pass the old volume and the new one. It uses the new one to ask for the serial number and the old one to ask for the drive letter
  function AddVolumeAccessPath_2012 {
    param($ServerName, $DriveLetter, $SerialNumber)
	$Remotevalues = New-object PSObject;
	$RemoteValues | Add-Member -MemberType Noteproperty SerialNumber $SerialNumber
	$RemoteValues | Add-Member -MemberType Noteproperty DriveLetter $DriveLetter
	
	Invoke-Command -ComputerName $ServerName -ArgumentList $RemoteValues -ScriptBlock { param($RemoteValues) get-disk | where {$_.SerialNumber -eq $RemoteValues.SerialNumber} | get-partition | Set-partition -NewDriveLetter $RemoteValues.DriveLetter }
}

## This function replaces the old Set-CMLDiskDevice -offline. 
## Just need to use as parameter the same $volumeInfo and a CIM Session alrady established
  function Set-DiskOffline_2012 {
	param([VolumeInformation] $volumeInfo)
    Log -message  "Setting disk Offline"
	Invoke-Command -ComputerName $volumeInfo.ServerName -ArgumentList $volumeInfo -Scriptblock { param($volumeInfo) get-disk | where {$_.SerialNumber -eq $volumeInfo.SerialNumber} | Set-disk -IsOffline $true }
}

## This function replaces the old Set-CMLDiskDevice -online. 
## Just need to use as parameter the same $volumeInfo and a CIM Session alrady established
  function Set-DiskOnline_2012 {
	param([VolumeInformation] $volumeInfo)
    Log -message "Setting disk Online" 
	Invoke-Command -ComputerName $volumeInfo.ServerName -ArgumentList $volumeInfo -Scriptblock { param($volumeInfo) get-disk | where {$_.SerialNumber -eq $volumeInfo.SerialNumber} | Set-disk -IsOffline $false }
}


Function CreateAndMapDrives_2012 {
  param ([Parameter(Mandatory=$True)][system.Array]$servernames, 
  [Parameter(Mandatory=$True)][System.Array]$DriveLetters,
  [Parameter(Mandatory=$True)][System.Object]$ReplayInfoList)

#create the drives and Map them to VMWare
  $global:destinationServers = @()
  ForEach ($serverName in $Servernames) {

    Log -message "Get Volume Information for $($serverName) " 
    $destSrvInfo = GetServerInformation_2012 -serverName $serverName -DriveLetters $DriveLetters

    ForEach($volumeInfo in $destSrvInfo.Volumes) {
        Log -message  "Getting Source Volume for $($volumeInfo.AccessPath)" 
        #Gets the correct drive volume from the source server
        $srcVolume = $srcSrvInfo.Volumes | Where-Object { $_.accessPath -eq $volumeInfo.accessPath }
         
        $volumeInfo | Add-Member -MemberType NoteProperty OldVolume $(RenameOldVolume -volumeInfo $volumeInfo)  #Rename volume and mark volume for removal

        Create-NewVolume -srcVolumeInfo $srcVolume -volumeInfo $volumeInfo -replayInfoList $replayInfoList

        Log -message  "Mapping $($volumeInfo.NewVolume.Name)" 
        $scVMHostMap = $(Get-SCVolumeMap -ConnectionName $volumeInfo.StorageCenterName -VolumeIndex $volumeInfo.Index)[0] #Get the first host in the old Volume Mapping
        $scVMHost = Get-SCServer -ConnectionName $volumeInfo.StorageCenterName -Name $scVMHostMap.ServerName #Use the host to get the cluster
        $scVMCluster = Get-SCServer -ConnectionName $volumeInfo.StorageCenterName -Name $scVMHost.ParentServer #Use the host to get the cluster
        $vMap = New-SCVolumeMap -SCVolume $volumeInfo.NewVolume -SCServer $scVMCluster -connectionName $volumeInfo.StorageCenterName #map the volume to the cluster

    }
    $global:destinationServers += $destSrvInfo

  }
  return $global:destinationServers     
}