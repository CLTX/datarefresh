#Getting hosts inside new cluster and passing them into ESXCLI.
$hosts = get-cluster "Compellent R810" | Get-VMHost
$esxCliList = Get-EsxCli -VMHost $Hosts

#Counting amount of detached devices that weren't removed 
($esxCliList.storage.core.device.detached.list() | sort DeviceUID).count   ## This should return nothing, but it was returning 58 detached LUNs that weren't removed.## 
58


foreach ($device in ($esxCliList[0].storage.core.device.detached.list()).DeviceUID) {$esxCliList[0].storage.core.device.detached.remove($device)}
($esxCliList[0].storage.core.device.detached.list()).DeviceUID    ## Now returns nothing for host 0 ##

foreach ($device in ($esxCliList[1].storage.core.device.detached.list()).DeviceUID) {$esxCliList[1].storage.core.device.detached.remove($device)}
($esxCliList[1].storage.core.device.detached.list()).DeviceUID   ## Same for host 1  ##






$esxCliList[$i].storage.core.adapter.rescan($adaptersUp[$j].HBAName, $false, $false, $false, $action) 
$esxCliList[1].storage.core.device.detached.list()).DeviceUID) {$esxCliList[1].storage.core.device.detached.remove($device)}



storage core device set 
<# --device | -d
The device you wish to operate upon. This can be any of the UIDs that a device reports.
--help | -h
Show the help message.
--name | -n
The new name to assign the given device.
--no-persist | -N
Set device state non-peristently; state is lost after reboot.
--state
Set the SCSI device state for a the specific device given. Valid values are : off: Set the device's state to OFF. on: Set the device's state to ON.
#>

storage core device setconfig
# --detached  -- Mark device as detached.


