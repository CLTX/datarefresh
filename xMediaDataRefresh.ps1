## Setting preferences and paths variables
  $ErrorActionPreference = "Stop"
  $global:scriptPath = $MyInvocation.MyCommand.Path;
  $global:scriptName = [io.path]::GetFileNameWithoutExtension($scriptPath);
  $global:executingScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent;

## Importing modules. 
  Import-Module $executingScriptDirectory\objects\VolumeInformation.ps1 -Force
  Import-Module $executingScriptDirectory\objects\error_object.ps1 -Force
  Import-Module $executingScriptDirectory\objects\xMediaObjects.ps1
  Import-Module $executingScriptDirectory\lib\Common.ps1 -Force
  Import-Module $executingScriptDirectory\lib\exceptions_handling.ps1 -Force
  Import-Module $executingScriptDirectory\lib\Emailing.ps1 -Force
  Import-Module $executingScriptDirectory\lib\Threading.ps1 -Force
  Import-Module $executingScriptDirectory\lib\Nagios.ps1 -Force
  Import-Module $executingScriptDirectory\lib\SqlQuery.ps1 -Force
  Import-Module $executingScriptDirectory\lib\Compellent.ps1 -Force
  Import-Module $executingScriptDirectory\lib\CompellentRM.ps1 -Force
  Import-Module $executingScriptDirectory\lib\Vmware.ps1 -Force
  Import-Module $executingScriptDirectory\lib\VmwareDatastoreFunctions.ps1 -Force
  Import-Module $executingScriptDirectory\lib\ServerLien.ps1 -Force
  Import-Module $executingScriptDirectory\lib\SqlServer.ps1 -Force
  Import-Module $executingScriptDirectory\lib\main_swap.ps1 -Force
  Import-Module $executingScriptDirectory\lib\DataRefresh_common_functions.ps1 -Force
  Import-Module $executingScriptDirectory\lib\2012_CIM_Session.ps1 -Force
  Import-Module $executingScriptDirectory\lib\2012_ClearFlagsSetVolume.ps1 -Force
  Import-Module $executingScriptDirectory\lib\2012_Datarefresh.ps1 -Force
  Import-Module $executingScriptDirectory\lib\DataRefresh.ps1 -Force
  Import-Module $executingScriptDirectory\lib\DiskPart.ps1 -Force
  import-Module $executingScriptDirectory\lib\Logger.ps1 -Force

## Notification on error. 
## Function Handle-Error is inside lib\exceptions_handling. Send-Mail inside lib\Emailing
  trap { Handle-Error $_; break }

## Start logging. If you are calling this from ISE it won't transcript
  Start-LogTranscript -path $global:executingScriptDirectory

Log -message "Creating Source and Destination objects from JSON config files"
  $DestServers_Json = Get-Content -Path $executingScriptDirectory\conf\xMedia\xMedia_destServers.JSON | Out-String | ConvertFrom-Json 
  $global:sourceServer = Get-Content -Path $executingScriptDirectory\conf\xMedia\xMedia_sourceServer.JSON | Out-String | ConvertFrom-Json

Log -message "Loading config using Init function from common lib"
  Init 

Log -message "Adding connections to compellenbt"
  GetAllSCConnections 
  
Log -message "Importing SourceServer settings from $($sourceServer) and creating it as a fullfilled Object. Getting volumes information from Volumes array directly from sourceserver."
  $volumes = FormatVolumeArray -volumeString $sourceServer.DriveLetters | Out-Host
  $replayDescription = $sourceServer.BackupSetName

#TODO: $sourceServer.IsWindows2008
  If ($sourceServer.OSVersion -eq "2008") {
    $srcSrvInfo = GetServerInformation -server $sourceServer.ServerName -accessPaths $volumes
  } else {
    Create-NewCIMSession -Server $sourceServer.ServerName
    $srcSrvInfo = GetServerInformation_2012 -server $sourceServer.ServerName -DriveLetters $sourceServer.DriveLetters
  }

Log -message "Filling xMedia_Destination object with data from $($DestServers_Json). "
  $DestServers = @()
  foreach ($servername in $DestServers_Json.ServerName)
  {
    $Object = New-Object xMedia_Destination                                       
    $Object.ServerName = $servername
    $Object.FolderName = $DestServers_Json.FolderNAme                  
    $Object.NewRDMIdentifer = $DestServers_Json.NewRDMIdentifer
    $Object.ServerMapping = $DestServers_Json.ServerMapping
    $Object.DataPath = $DestServers_Json.DataPath
    $Object.LogPath = $DestServers_Json.LogPath
    $Object.DriveLetters = $DestServers_Json.DriveLetters
    $Object.OSVersion = $DestServers_Json.OSVersion
    $DestServers += $Object
  }

############################################################################### 
### Function to do the complete Replay process. Added into lib\CompellentRM ###
###############################################################################
  Log -message "Calling Replay_Process"
  Replay_process -backupsource $sourceServer.Servername -backupSetName $sourceServer.backupSetName -excludedDatabaseList $sourceServer.ExcludedDatabaseList

  Log -message "Getting Source Replays" 
  $replayInfoList = Get-ReplayInformationList -srvVolumes $srcSrvInfo.Volumes

  Log -message "Open VCenter"
  OpenVCenter

###########################################################
## Function to Create and Map Drives based in OS Version ##
####################################################################
## NOTE: Here we create CIMSessions for 2012 Destination Servers  ##
####################################################################
  If ($DestServers_Json.OSVersion -eq "2008") {
    CreateAndMapDrives -servernames $DestServers_Json.Servername -Volumes $volumes -ReplayInfoList $replayInfoList
  } else {
    foreach ($destinationServername in $DestServers_Json.ServerName)
    { Create-NewCIMSession -Server $destinationServername }
    CreateAndMapDrives_2012 -servernames $DestServers_Json.Servername -DriveLetters $DestServers_Json.DriveLetters -ReplayInfoList $replayInfoList
  }


## Calling ESXCliList based in ServerMapping.
  $cluster = Get-Cluster -Name $DestServers.ServerMapping
  $vmHosts = Get-VMHost -Location $cluster
  $esxCliList = Get-EsxCli -VMHost $vmHosts

   
### NEW: Replacing old RescanAllHBAs function with this new serialized HBA rescan using ESXCLI. 
Log -message "Adding new LUNs using Serialized Rescan-HBA"
  Rescan-HBAsESXiserial -esxCliList $esxCliList -action add

###########################################################################################################################
###########################################################################################################################
##                                                                                                                       ##
## Major modify below: One function to call all swap related ones using Old and new Datarefresh libs based in OS Version ##
##                                                                                                                       ##
###########################################################################################################################
###########################################################################################################################
Log -message "Starting Main Swap function"
Main_Swap -destinationServers $destinationServers -Osversion $DestServers_Json.OSVersion

######################################################################################################################
## One final rescan to ensure the luns that were removed don't continue to show in vcenter                          ##
## NOTE: this needs to be done before the detached device cleanup else the lun will reattach and throw PDL errors.  ##
## NEW: Using the new RescanHBASerial to perform rescan. In This case we are looking for DEAD LUNs.                 ##
######################################################################################################################
Rescan-HBAsESXiserial -esxCliList $esxCliList -action delete

## Cleanup detached luns
  Log -message "Cleanup detached luns"
  ForEach($esxCli in $esxCliList) {
    Log -message "Checking $($esxCli.VMHost.Name)"    
    foreach($canonicalName in $detachCanonicalNameList) {
        Log -message "$($canonicalName) scsi device will be removed"
        $esxCli.storage.core.device.detached.remove($canonicalName)
        }
  }

Stop-LogTranscript