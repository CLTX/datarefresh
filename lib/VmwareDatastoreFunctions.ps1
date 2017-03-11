function RenameScsiLun
{
    param(
        [VMware.VimAutomation.ViCore.Util10.ScsiLunImpl]$scsiLun, 
        [string]$newName, 
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost)

	$uuid = $scsiLun.ExtensionData.Uuid
	$storSys = Get-View $vmHost.ExtensionData.ConfigManager.StorageSystem
	$storSys.UpdateScsiLunDisplayName($uuid, $newName)
}

Function Get-DatastoreMountInfo {
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline=$true)]
		$Datastore
	)
	Process {
		$AllInfo = @()
		if (-not $Datastore) {
			$Datastore = Get-Datastore
		}
		Foreach ($ds in $Datastore) {  
			if ($ds.ExtensionData.info.Vmfs) {
				$hostviewDSDiskName = $ds.ExtensionData.Info.vmfs.extent[0].diskname
				if ($ds.ExtensionData.Host) {
					$attachedHosts = $ds.ExtensionData.Host
					Foreach ($VMHost in $attachedHosts) {
						$hostview = Get-View $VMHost.Key
						$hostviewDSState = $VMHost.MountInfo.Mounted
						$StorageSys = Get-View $HostView.ConfigManager.StorageSystem
						$devices = $StorageSys.StorageDeviceInfo.ScsiLun
						Foreach ($device in $devices) {
							$Info = "" | Select Datastore, VMHost, Lun, Mounted, State
							if ($device.canonicalName -eq $hostviewDSDiskName) {
								$hostviewDSAttachState = ""
								if ($device.operationalState[0] -eq "ok") {
									$hostviewDSAttachState = "Attached"							
								} elseif ($device.operationalState[0] -eq "off") {
									$hostviewDSAttachState = "Detached"							
								} else {
									$hostviewDSAttachState = $device.operationalstate[0]
								}
								$Info.Datastore = $ds.Name
								$Info.Lun = $hostviewDSDiskName
								$Info.VMHost = $hostview.Name
								$Info.Mounted = $HostViewDSState
								$Info.State = $hostviewDSAttachState
								$AllInfo += $Info
							}
						}
						
					}
				}
			}
		}
		$AllInfo
	}
}

Function Detach-Datastore {
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline=$true)]
		$Datastore
	)
	Process {
		if (-not $Datastore) {
			Log -message "No Datastore defined as input"
			Exit
		}
		Foreach ($ds in $Datastore) {
			$hostviewDSDiskName = $ds.ExtensionData.Info.vmfs.extent[0].Diskname
			if ($ds.ExtensionData.Host) {
				$attachedHosts = $ds.ExtensionData.Host
				Foreach ($VMHost in $attachedHosts) {
					$hostview = Get-View $VMHost.Key
					$StorageSys = Get-View $HostView.ConfigManager.StorageSystem
					$devices = $StorageSys.StorageDeviceInfo.ScsiLun
					Foreach ($device in $devices) {
						if ($device.canonicalName -eq $hostviewDSDiskName) {
							$LunUUID = $Device.Uuid
							Log -message "Detaching LUN $($Device.CanonicalName) from host $($hostview.Name)..."
							$StorageSys.DetachScsiLun($LunUUID);
						}
					}
				}
			}
		}
	}
}

Function Unmount-Datastore {
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline=$true)]
		$Datastore
	)
	Process {
		if (-not $Datastore) {
			Log -message "No Datastore defined as input"
			Exit
		}
		Foreach ($ds in $Datastore) {
			$hostviewDSDiskName = $ds.ExtensionData.Info.vmfs.extent[0].Diskname
			if ($ds.ExtensionData.Host) {
				$attachedHosts = $ds.ExtensionData.Host
				Foreach ($VMHost in $attachedHosts) {
					$hostview = Get-View $VMHost.Key
					$StorageSys = Get-View $HostView.ConfigManager.StorageSystem
					Log -message "Unmounting VMFS Datastore $($DS.Name) from host $($hostview.Name)..."
					$StorageSys.UnmountVmfsVolume($DS.ExtensionData.Info.vmfs.uuid);
				}
			}
		}
	}
}

Function Mount-Datastore {
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline=$true)]
		$Datastore
	)
	Process {
		if (-not $Datastore) {
			Log -message "No Datastore defined as input"
			Exit
		}
		Foreach ($ds in $Datastore) {
			$hostviewDSDiskName = $ds.ExtensionData.Info.vmfs.extent[0].Diskname
			if ($ds.ExtensionData.Host) {
				$attachedHosts = $ds.ExtensionData.Host
				Foreach ($VMHost in $attachedHosts) {
					$hostview = Get-View $VMHost.Key
					$StorageSys = Get-View $HostView.ConfigManager.StorageSystem
					Log -message "Mounting VMFS Datastore $($DS.Name) on host $($hostview.Name)..."
					$StorageSys.MountVmfsVolume($DS.ExtensionData.Info.vmfs.uuid);
				}
			}
		}
	}
}

Function Attach-Datastore {
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline=$true)]
		$Datastore
	)
	Process {
		if (-not $Datastore) {
			Log -message "No Datastore defined as input"
			Exit
		}
		Foreach ($ds in $Datastore) {
			$hostviewDSDiskName = $ds.ExtensionData.Info.vmfs.extent[0].Diskname
			if ($ds.ExtensionData.Host) {
				$attachedHosts = $ds.ExtensionData.Host
				Foreach ($VMHost in $attachedHosts) {
					$hostview = Get-View $VMHost.Key
					$StorageSys = Get-View $HostView.ConfigManager.StorageSystem
					$devices = $StorageSys.StorageDeviceInfo.ScsiLun
					Foreach ($device in $devices) {
						if ($device.canonicalName -eq $hostviewDSDiskName) {
							$LunUUID = $Device.Uuid
							Log -message "Attaching LUN $($Device.CanonicalName) to host $($hostview.Name)..."
							$StorageSys.AttachScsiLun($LunUUID);
						}
					}
				}
			}
		}
	}
}

 workflow Attach-Disk{
    param(
    [string]$sessionId,
    [string]$vcServer,
    [string[]]$vmHostNames,
    [string]$CanonicalName)
            
    foreach -parallel ($vmHostName in $vmHostNames)
    {
        InlineScript {
            Add-PSSnapin VMware.VimAutomation.Core 
            connect-viserver $using:vcServer -session $using:sessionId
            $vmHost = Get-VMHost -Name $using:vmHostName
            $storSys = Get-View $VMHost.Extensiondata.ConfigManager.StorageSystem
            $lunUuid = (Get-ScsiLun -VmHost $VMHost | where {$_.CanonicalName -eq $using:CanonicalName}).ExtensionData.Uuid
     
            $storSys.AttachScsiLun($lunUuid)
        }
     }
}

workflow Detach-Disk{
    param(
    [string]$sessionId,
    [string]$vcServer,
    [string[]]$vmHostNames,
    [string[]]$CanonicalNames)
            
    foreach -parallel ($vmHostName in $vmHostNames)
    {
        InlineScript {
            Add-PSSnapin VMware.VimAutomation.Core 
            connect-viserver $using:vcServer -session $using:sessionId
            $vmHost = Get-VMHost -Name $using:vmHostName
            $storSys = Get-View $VMHost.Extensiondata.ConfigManager.StorageSystem

            #get the scsi luns to detach
            $scsiLuns = Get-ScsiLun -VmHost $VMHost -CanonicalName $using:CanonicalNames

            #detach the luns
            foreach($scsiLun in $scsiLuns) {
                if($scsiLuns.ExtensionData.OperationalState -ne "off") {
                    #get the UUID of the device
                    $lunUuid = $scsiLun.ExtensionData.Uuid
                    #detached scsi lun
                    $storSys.DetachScsiLun($lunUuid)
                }
            }

       }
   }
}


function Detach-Disk2 {
    param(
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl[]]$vmHost,
    [string[]]$CanonicalNames)
            
    $vmHosts | foreach-parallel 
    {
            #get the host storage system
            $storSys = Get-View $_.Extensiondata.ConfigManager.StorageSystem

            #get the scsi luns to detach
            $scsiLuns = Get-ScsiLun -VmHost $_ -CanonicalName $using:CanonicalNames

            #detach the luns
            foreach($scsiLun in $scsiLuns) {
                #get the UUID of the device
                $lunUuid = $scsiLun.ExtensionData.Uuid
                #detached scsi lun
                $storSys.DetachScsiLun($lunUuid)
            }
     }
}


workflow Detach-DiskEsxicli{
    param(
    [string]$sessionId,
    [string]$vcServer,
    [string[]]$vmHostNames,
    [string[]]$CanonicalNames)
            
    foreach -parallel ($vmHostName in $vmHostNames)
    {
        InlineScript {
            Add-PSSnapin VMware.VimAutomation.Core 
            connect-viserver $using:vcServer -session $using:sessionId
            $vmHost = Get-VMHost -Name $using:vmHostName
            $esxCli = Get-EsxCli -VMHost $vmHost
            #$storSys = Get-View $VMHost.Extensiondata.ConfigManager.StorageSystem

            #get the scsi luns to detach
            $scsiLuns = Get-ScsiLun -VmHost $VMHost -CanonicalName $using:CanonicalNames

            #detach the luns
            foreach($private:canonicalName in $using:CanonicalNames) {
                #get the UUID of the device
                #$lunUuid = $scsiLun.ExtensionData.Uuid
                #detached scsi lun
                #$storSys.DetachScsiLun($lunUuid)
                $esxCli.storage.core.device.set($private:canonicalName, $null,$null, $null, $null, "off")
            }
        }
     }
}
