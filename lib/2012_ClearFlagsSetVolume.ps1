###################################################################################
# New function to set all disk and partition flags in a windows 2012 remoteserver #
###################################################################################

function ClearFlagsAndSetVolume_2012 {
param(
    [string] $serverName,
    [System.Object] $SerialNumber
)
    $cimsession = New-cimsession -ComputerName $serverName
    Log -message "Rescan drives, clean disk & partition attributes, rescan again"
    invoke-command -computerName $servername -ArgumentList $serialnumber -scriptblock {
        param($serialnumber) 
        Update-HostStorageCache
		start-sleep 5
        get-disk | where {$_.SerialNumber -eq $SerialNumber} | set-disk -IsOffline $false 
        get-disk | where {$_.SerialNumber -eq $SerialNumber} | set-disk -IsReadOnly $false
        get-disk | where {$_.SerialNumber -eq $SerialNumber} | Get-Partition | Set-Partition -IsReadOnly $false -IsActive $true -IsHidden $false
        Update-HostStorageCache
		start-sleep 5
        }

    Remove-CimSession -CimSession $cimsession
}