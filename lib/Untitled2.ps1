# PAR Datarefresh script
## Line 253: we are detaching each canonicalname and that's OK.
Detach-Disk -sessionId $global:DefaultVIServer.SessionId -vcServer $global:DefaultVIServer.Name -vmHostNames $vmHosts.Name -CanonicalNames $detachCanonicalNameList

## Line 256: We remove them mapping from wmware and then remove the volume from compellent
ForEach($removeVolumeInfo in $removeVolumeList) {

    #first we need to remove the volume mappings from the san
    Remove-SCVolumeMap -ConnectionName $removeVolumeInfo.SCName -SCServer $removeVolumeInfo.SCVMCluster -SCVolume $removeVolumeInfo.SCVolume -Confirm:$false
	Start-Sleep 20
    #finally remove the volume from the san
    Remove-SCVolume -ConnectionName $removeVolumeInfo.SCName -SCVolume $removeVolumeInfo.SCVolume -SkipRecycleBin  -Confirm:$false

} 

# Line 273: A Rescan HBA is performed. That ensures all unused RDMs related to datarefresh were removed.
RescanAllHBAs -sessionId $global:DefaultVIServer.SessionId -vcServer $global:DefaultVIServer.Name -vmHostNames $vmHosts.Name

# Line 283: This Clean is unnecessary for two reasons:
#  a ) THE $esxCli.storage.core.device.detached.remove( $canonicalName) doesn't remove the lun from VMware, just remove it from the device detached list and then makes it attached.
#  b ) 
Write-Host "Cleanup detached luns"
ForEach($esxCli in $esxCliList) {
    Write-Host "Checking $($esxCli.VMHost.Name)"    
    foreach($canonicalName in $detachCanonicalNameList) {
    Write-Host "$($canonicalName) scsi devices to remove"
        $esxCli.storage.core.device.detached.remove( $canonicalName)
    }
}