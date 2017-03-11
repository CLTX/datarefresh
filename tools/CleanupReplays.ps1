try {

#$ErrorActionPreference = "Stop"
$global:scriptPath = $MyInvocation.MyCommand.Path;
$global:executingScriptDirectory = [io.path]::GetDirectoryName($scriptPath);
$global:scriptName = [io.path]::GetFileNameWithoutExtension($scriptPath);


Import-Module $executingScriptDirectory\objects\VolumeInformation.ps1 -Force
Import-Module $executingScriptDirectory\lib\Common.ps1 -Force
# StartLog -path $executingScriptDirectory
Import-Module $executingScriptDirectory\lib\Utility.ps1 -Force
Import-Module $executingScriptDirectory\lib\Compellent.ps1 -Force


Write-Output "Initialize"
Init

 
 #HACK: Load App Config - there are two scripts that use this as their app config.
 $afxreportsnapshotPath = "$executingScriptDirectory\conf\afxreportsnapshot.config";
 Log -message "Load App Config: $($afxreportsnapshotPath)" 
 LoadConfig -path $($afxreportsnapshotPath);



#Get All Storage Center Connections
GetAllSCConnections 

$vIndexes = @(659,759,660,762,734,735)

ForEach( $vIndex in $vIndexes) {

$tempReplay = Get-SCReplay -ConnectionName "PSUSADAE02" -SourceVolumeIndex $vIndex  

$tempReplay = $tempReplay | Where-Object { $_.ExpireTime -eq "Never Expire" -and $_.Description -like "PAR Snapshot*" -and $_.State -eq "Frozen" -and [DateTime]$_.FreezeTime -le [DateTime]::Now.AddDays(-2)} 

    $tempReplay | ForEach-Object {
        Log -message "cleaning up: $($_.Description)"
        if($_.State -eq "Frozen") {
            Set-SCReplay -SCReplay $_ -ConnectionName "PSUSADAE02" -ExpirationTime ([DateTime]::Now)
        }
    }
}

}
finally {
}

