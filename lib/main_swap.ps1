#####################################################################################################################
#####################################################################################################################
###                                                                                                               ###
### Main Swap Function:                                                                                           ###
### ###################                                                                                           ###
###                                                                                                               ###
### Detach SQL Databases, Shutdown SQL Server, remove Drive letters, Offline disk, remove disks from VM,          ###
### Add new disk, Rename SCSI LUN, Clear Flags, RescanDisk, Set it online, Start SQL server, attach databases,    ###
### enable nagios, unlien all servers, detach scsi luns from vmware, remove mappings, and remove from compellent  ###
###                                                                                                               ###
#####################################################################################################################
#####################################################################################################################

#TODO Break functions in OS Version
Function main_swap {
  param ([Parameter(Mandatory=$True)][System.Object]$destinationServers, 
  [Parameter(Mandatory=$True)][string]$OSVersion)
    
    Log -message  "Removing Old Volumes and Adding New Ones"
    ForEach ($destinationServer in $destinationServers) {

        $vm = Get-VM -Name $destinationServer.Name
        $vmHost = Get-VMHost -VM $vm
        
        $getxMediaDatabases = ExecQuery -connection "server=$($destinationServer.Name);database=DBA;trusted_connection=true;" -query "select name from Sys.Databases where name like 'xMedia_%'" -cmdType Text
        if ($getxMediaDatabases.Tables.Name)
        {
            Log -message  "Detaching Data"
            Detaching-xMedia-DBs -xMediaServerName $destinationServer.Name
        } else {
            Log -message "No xMedia databases to detach"
        }
        
        Disable-Nagios -serverName $destinationServer.Name
		Lien-XMediaServer -serverName $destinationServer.Name
                
        ## IF OS VERSION IS 2008 RUN THE OLD SCRIPTS
        If ($osVersion -eq "2008")
        {    
            Log -message "INFO:  Working in a Windows 2008 R2 Server as Destination" 
            Log -message "Shutting down SQL Server" 
            Stop-SqlServer -serverName $destinationServer.Name
            ForEach($volumeInfo in $destinationServer.Volumes) {
                Log -message "Removing $($volumeInfo.AccessPath)"
        
                ### Remove drive letter, offline disk 
                RemoveVolumeAccessPath -volumeInfo $volumeInfo
                Set-CMLDiskDevice -Offline -SerialNumber $volumeInfo.SerialNumber -Server $volumeInfo.ServerName -Confirm:$false
                
                #remove disk from VM --  VSPhere
                Get-HardDisk -VM $vm | Where-Object { $_.ScsiCanonicalName -eq $volumeInfo.CanonicalName } | Remove-HardDisk -DeletePermanently -Confirm: $false

                Log -message "Adding $($volumeInfo.NewVolume.Name)"
                #add disk --VM
                $newSCVolume = $volumeInfo.NewVolume
                $scsiLun = get-scsilun -VMHost $vmHost -CanonicalName $("naa.{0}" -f $newSCVolume.DeviceId)
                Rename-ScsiLun -scsiLun $scsiLun -newName $("{0}_VOLATILE" -f $newSCVolume.Name) -vmHost $vmHost
                $newVMHardDisk = New-HardDisk -VM $vm -disktype RawPhysical -devicename $scsiLun.ConsoleDeviceName
        
                $cmlDiskDevice = Get-CMLDiskDevice -Server $vm.Name -SerialNumber $volumeInfo.NewVolume.SerialNumber
				Start-Sleep	3
                ClearFlagsAndSetVolume -serverName $vm.Name -deviceName $cmlDiskDevice.DeviceName
        
                Rescan-CMLDiskDevice -RescanDelay 5 -Server $vm.Name
                Start-Sleep -s 5
                Set-CMLVolume -Server $vm.Name -DiskSerialNumber $volumeInfo.NewVolume.SerialNumber -ReadOnly:$false -Hidden:$false -ClearShadowFlag -confirm: $false
                Add-CMLVolumeAccessPath -Server $vm.Name -DiskSerialNumber $volumeInfo.NewVolume.SerialNumber -AccessPath $volumeInfo.accessPath
             }
             Log -message "STARTING SQL SERVER..."
             Start-SqlServerWithAgent -serverName $destinationServer.Name 
        }

        ## ELSE, VERSION IS 2012, AND NEW SCRIPTS WILL BE EXECUTED 
        Else
        {
            Log -message "INFO:  Working in a Windows 2012 R2 Server as Destination"
            Log -message "Shutting down SQL Server" 
            Invoke-Command -ComputerName $destinationServer.Name -ScriptBlock {Stop-Service -Name MSSQLSERVER -Force} 
            ForEach($volumeInfo in $destinationServer.Volumes) {
                Log -message "Removing $($volumeInfo.AccessPath)" 
    
                ### Remove drive letter, offline disk
                Log -message "Calling function RemoveVolumeAccessPAth_2012"
                RemoveVolumeAccessPath_2012 -volumeInfo $volumeInfo 
                
                Log -message "Calling function Set-DiskOffline_2012"
                Set-DiskOffline_2012 -volumeInfo $volumeinfo

                #remove disk from VM --  VSPhere
                Log -message "calling Remove-HardDisk from VSphere" 
                Get-HardDisk -VM $vm | Where-Object { $_.ScsiCanonicalName -eq $volumeInfo.CanonicalName } | Remove-HardDisk -DeletePermanently -Confirm: $false

                Log -message "Adding $($volumeInfo.NewVolume.Name)" 
                #add disk --VM
                $newSCVolume = $volumeInfo.NewVolume
                $scsiLun = get-scsilun -VMHost $vmHost -CanonicalName $("naa.{0}" -f $newSCVolume.DeviceId)
                
                Log -message "calling function Rename-SCSILun from VSphere" 
                Rename-ScsiLun -scsiLun $scsiLun -newName $("{0}_VOLATILE" -f $newSCVolume.Name) -vmHost $vmHost
                $newVMHardDisk = New-HardDisk -VM $vm -disktype RawPhysical -devicename $scsiLun.ConsoleDeviceName
                
                #Get new remote volume as an object and remove its flags
                $diskSerialNumber = $volumeInfo.NewVolume.SerialNumber
                
                Log -message "Getting Disk remotely to 2012" 
                $cmlDiskDevice = Invoke-command -ComputerName $vm.Name -ArgumentList $diskSerialNumber -ScriptBlock {
                    param($diskSerialNumber) 
                    Get-disk | Where {$_.Serialnumber -eq $diskSerialNumber }}

                Log -message "calling function ClearFlagsAndSetVolume_2012" 
                ClearFlagsAndSetVolume_2012 -serverName $vm.Name -SerialNumber $diskSerialNumber
                
                Log -message "calling function AddVolumeAccessPath_2012" 
                AddVolumeAccessPath_2012 -ServerName $volumeInfo.Servername -DriveLetter $volumeInfo.DriveLetter -SerialNumber $diskSerialNumber 
            }
            Log -message "STARTING SQL SERVER AND AGENT..."
            Invoke-Command -ComputerName $destinationServer.Name -ScriptBlock {Start-Service -Name MSSQLSERVER} 
            Invoke-Command -ComputerName $destinationServer.Name -ScriptBlock {Start-Service -Name SQLSERVERAGENT} 
        }
        
    ## ATTACH DATABASES USING FUNCTION FROM SQL LIB AND ENABLE NAGIOS
    Log -message "Waiting 10 seconds until all SQL System DBs be up before proceed with the Attach" 
    start-sleep 10

    Log -message "Attaching Databases..." 
    Attaching-xMedia-DBs -xMediaSourceServerName $SourceServer.Servername -xMediaServerName $destinationServer.Name

    Log -message "Enabling Nagios" 
    Enable-Nagios -serverName $destinationServer.Name   
	Unlien-XMediaServer -serverName $destinationServer.Name
	
    }
    

    # Finally, remove all the old volumes
    $detachCanonicalNameList = @()
    $removeVolumeList = @()
	Log -message "Preparing settings to remove Old Volumes. This take some time"
    ForEach ($destinationServer in $destinationServers) {
        ForEach($volumeInfo in $destinationServer.Volumes) {
            $detachCanonicalNameList += $volumeInfo.CanonicalName
            $scVMHostMap = $(Get-SCVolumeMap -ConnectionName $volumeInfo.StorageCenterName -VolumeIndex $volumeInfo.Index)[0] #Get the first host in the old Volume Mapping
            $scVMHost = Get-SCServer -ConnectionName $volumeInfo.StorageCenterName -Name $scVMHostMap.ServerName #Use the host to get the cluster
            $scVMCluster = Get-SCServer -ConnectionName $volumeInfo.StorageCenterName -Name $scVMHost.ParentServer #Use the host to get the cluster

            $removeVolumeInfo = New-Object PSObject
            $removeVolumeInfo | Add-Member -MemberType NoteProperty SCVMCluster $scVMCluster
            $removeVolumeInfo | Add-Member -MemberType NoteProperty SCVolume $volumeInfo.SCVolumeInfo.SCVolume
            $removeVolumeInfo | Add-Member -MemberType NoteProperty SCName $volumeInfo.StorageCenterName

            $removeVolumeList += $removeVolumeInfo
        }
    }
    
    #Perform the detach from each host
	Log -message "Detaching Old volumes from VSphere"
    Detach-Disk -sessionId $global:DefaultVIServer.SessionId -vcServer $global:DefaultVIServer.Name -vmHostNames $vmHosts.Name -CanonicalNames $detachCanonicalNameList

    #Remove each volume from Compellent
    ForEach($removeVolumeInfo in $removeVolumeList) {

        #first we need to remove the volume mappings from the san
		Log -message "Removing Old volumes mapping from VSphere in Compellent for $($removeVolumeInfo.SCVolume)"
        Remove-SCVolumeMap -ConnectionName $removeVolumeInfo.SCName -SCServer $removeVolumeInfo.SCVMCluster -SCVolume $removeVolumeInfo.SCVolume -Confirm:$false
        
        #finally remove the volume from the san
		Log -message "Deleting $($removeVolumeInfo.SCVolume) from Compellent"
        Remove-SCVolume -ConnectionName $removeVolumeInfo.SCName -SCVolume $removeVolumeInfo.SCVolume -SkipRecycleBin  -Confirm:$false
    } 
}