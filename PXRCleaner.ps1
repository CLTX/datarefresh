$ErrorActionPreference = "Stop"
$global:scriptPath = $MyInvocation.MyCommand.Path;
$global:executingScriptDirectory = [io.path]::GetDirectoryName($scriptPath);
$global:scriptName = [io.path]::GetFileNameWithoutExtension($scriptPath);

## Importing modules. 
  Import-Module $executingScriptDirectory\objects\VolumeInformation.ps1 -Force
  Import-Module $executingScriptDirectory\objects\error_object.ps1 -Force
  Import-Module $executingScriptDirectory\objects\xMediaObjects.ps1
  Import-Module $executingScriptDirectory\lib\Common.ps1 -Force
  Import-Module $executingScriptDirectory\lib\exceptions_handling.ps1 -Force
  Import-Module $executingScriptDirectory\lib\Emailing.ps1 -Force
  Import-Module $executingScriptDirectory\lib\Compellent.ps1 -Force
  Import-Module $executingScriptDirectory\lib\CompellentRM.ps1 -Force
  Import-Module $executingScriptDirectory\lib\Vmware.ps1 -Force
  Import-Module $executingScriptDirectory\lib\DataRefresh_common_functions.ps1 -Force
  Import-Module $executingScriptDirectory\lib\2012_CIM_Session.ps1 -Force
  Import-Module $executingScriptDirectory\lib\2012_Datarefresh.ps1 -Force
  Import-Module $executingScriptDirectory\lib\Logger.ps1 -Force

trap { Handle-Error $_; break }

## Starting Logging
Start-LogTranscript -path $global:executingScriptDirectory

Log -message "Loading config using Init function from common lib"
  Init 

Log -message "Adding connections to compellent"
  $sccon = GetSCConnection -storageCenter "PSUSADAE01"

## Getting Server Data. A Difference of Datarefresh,we won't populate objects
Log -message "Creating Source and Destination objects from JSON config files"
  $DestServers = Get-Content -Path $executingScriptDirectory\conf\xMedia\xMedia_destServers.JSON | Out-String | ConvertFrom-Json 

## Filling a list with all disks' serianumbers currently in use
Log -message "Populating a list with all disks' serial numbers currently in use"
$ExcludedSerialNumbers = @()
foreach ($servername in $DestServers.ServerName)
{
    Create-NewCIMSession -Server $servername
    $ExcludedSerialNumbers += Invoke-Command -ComputerName $servername -ScriptBlock {
        $serialnumbers = @()
        $remotevolumes = get-volume | where {($_.FileSystemLabel -eq "DATA") -or ($_.FilesystemLabel -eq "LOG")}
        Foreach ($volume in $remoteVolumes)
        {
            $partition = get-partition | where {$_.AccessPaths -contains $volume.ObjectId}   
            $disk = get-disk| where {$_.ObjectId -eq $partition.DiskId}
            $serialnumbers += $disk.serialnumber;                    
        }
        return $serialnumbers
    }
     
}

$DeleteList = @()
foreach ($servername in $DestServers.Servername)
{
    $shortname = $servername.Replace('VSUSA','')
	Log -message "Populating a list with all disks to be removed"
    $DeleteList += Get-SCVolume -Connection $sccon | where {($_.Name -like "$($shortname)_D*") -and ($_.SerialNumber -notin $ExcludedSerialNumbers)}
    $DeleteList += Get-SCVolume -Connection $sccon | where {($_.Name -like "$($shortname)_E*") -and ($_.SerialNumber -notin $ExcludedSerialNumbers)}
}

Log -message "Removing Volumes"
Remove-Volumes -StorageCenterName "PSUSADAE01" -CMLIndexes $DeleteList.Index