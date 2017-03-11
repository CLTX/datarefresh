try {

$ErrorActionPreference = "Stop"
$global:scriptPath = $MyInvocation.MyCommand.Path;
$global:executingScriptDirectory = [io.path]::GetDirectoryName($scriptPath);
$global:scriptName = [io.path]::GetFileNameWithoutExtension($scriptPath);


Import-Module $executingScriptDirectory\objects\VolumeInformation.ps1 -Force
Import-Module $executingScriptDirectory\lib\Common.ps1 -Force
Import-Module $executingScriptDirectory\lib\Utility.ps1 -Force
Import-Module $executingScriptDirectory\lib\Vmware.ps1 -Force
Import-Module $executingScriptDirectory\lib\VmwareDatastoreFunctions.ps1 -Force


Write-Output "Initialize"
Init

OpenVCenter

$cluster = Get-Cluster -Name "Compellent Large"
$vmHosts = Get-VMHost -Location $cluster    

ForEach($vmHost in $vmHosts) {
    Log -message "Checking $($vmHost.Name)"
    $esxCli = Get-EsxCli -VMHost $vmHost
    $detachedScsiDeviceList = $esxCli.storage.core.device.detached.list()
    if($detachedScsiDeviceList -ne $null) {
        Log -message "$($detachedScsiDeviceList.Count) scsi devices to remove"
        $esxCli.storage.core.device.detached.remove($true)
    }
}


}
finally {
}

