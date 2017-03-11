

function ClearFlagsAndSetVolume {
param(
    [string] $serverName,
    [string] $deviceName
)

$disk = Get-WmiObject -ComputerName $serverName -Class Win32_DiskDrive 
$disk = $disk | Where-Object { $_.DeviceId.Substring(4) -EQ $deviceName.Substring(4) }
#$deviceName.Substring($deviceName.Length - 1)

$DiskPartScript = @"
rescan
select disk $($disk.index)
attributes disk clear readonly noerr
online disk noerr
"@

$selectVolumeScript = @"
    att vol clear readonly
    att vol clear hidden
    att vol clear shadowcopy
"@


$pssession = New-PSSession -ComputerName $serverName
Invoke-Command -Session $pssession { $using:DiskPartScript | diskpart }

$info = Invoke-Command -Session $pssession { $using:selectVolumeScript | diskpart }
Remove-PSSession -Session $pssession



}


