If ( !( Get-PSSnapin | Where-Object { $_.Name -eq "Compellent.ReplayManager.Scripting" } ) )
{
	Add-PSSnapin Compellent.ReplayManager.Scripting 
}

function OpenReplayManager([string]$server)
{
    ## Connect to the Replay Manager Services
    Log -message "Connecting to the Replay Manager on server: $($server)"
    Connect-RMServer -Computer $server -SetAsDefault -UserName $appSettings["FullyQualifiedAdminUser"] -Password $appSettings["AdminUserPassword"] 
    
    #successfully opened a connection to RM
    return $True    
}

function CloseReplayManager([string]$server)
{
    ## Connect to the Replay Manager Services
    Log -message "Disconnecting from Replay Manager on server: $($server)"
    Disconnect-RMServer -Computer $server 
}

<######################################################
# Creates a Replay Manager Snapshot with excluded 
# databases
#######################################################>
function RMSnapshotWithExclude([string]$server, [string]$backupSetName, [string[]]$excludedDbList)
{
    ## Take the backup set
    Log -message "Taking a Snapshot - SourceServer: $($server)"

    ## Exclude list
    $components = Get-RMComponentInfo -ExtensionType SqlServer -Computer $server | where-object {(($($excludedDbList) -notcontains $_.Name) -and ($_.Info -eq "Database"))}
    $RMBackupSet = Get-RMBackupSet -BackupSet $backupSetName -ExtensionType SqlServer
    If ( !$RMBackupSet )
    {
        # Backup set didn't exist so create a new one.
        Log -message "Creating a New Backup Set"
        $components = Get-RMComponentInfo -ExtensionType SqlServer -Computer $server | where-object {(($($excludedDbList) -notcontains $_.Name) -and ($_.Info -eq "Database"))}
        $RMBackupSet = New-RMBackupSet -Name $backupSetName -RMComponents $components -ExtensionType SqlServer
    }

    ## If is not possible to find or create backup, we will cancel execution.
    If ( !$RMBackupSet )
    {
        throw "Unable to create backup set. Canceling execution"
    }
    Submit-RMBackupSet -RMBackupSet $RMBackupSet -WaitForCompletion
    ####SNAPSHOT COMPLETE#####
}

<######################################################
# Creates a Replay Manager Snapshot of the specified  
# volumes
#######################################################>
function RMSnapshotVolumes {
    param([string]$server, 
        [string] $backupSetName, 
        [string[]]$volumes)

    ## Take the backup set
    Log -message "Taking a Snapshot - SourceServer: $($server)"


    $RMBackupSet = Get-RMBackupSet -BackupSet $backupSetName -ExtensionType Volumes
    If ( !$RMBackupSet )
    {

        # Backup set didn't exist so create a new one.
        Log -message "Creating a New Backup Set"
        $RMBackupSet = New-RMBackupSet -Computer $server -Name $backupSetname -Components $volumes -ExtensionType Volumes -RetentionSets 3  
    }

    ## If is not possible to find or create backup, we will cancel execution.
    If ( !$RMBackupSet )
    {
        throw "Unable to create backup set. Canceling execution"
    }
    Submit-RMBackupSet -RMBackupSet $RMBackupSet  -Computer $server -WaitForCompletion 

    If($removeBackupset) {
        Remove-RMBackupSet -RMBackupSet $RMBackupSet -Confirm:$false -Computer $server
    }

    ####SNAPSHOT COMPLETE#####
}

###############################################################################
# Function below does the complete backup process, calling other RM functions #
###############################################################################
function Replay_process 
{
    param([string]$backupsource,
    [string]$backupSetName,
    [string[]]$excludedDatabaseList)

    ## Connecting to Replay Manager services
    Log -message "Connecting to the Replay Manager" 
    OpenReplayManager -server $backupsource

    ## Generating unique ID for backup set
    ## $timestamp = Get-Date -Format yyyyMMddHHmmss
    ## $newbackupsetname = "$($backupSetName)-$($timestamp)"

    ## Take the backup set
    Log -message " Taking Snapshot. Excluded Database List: $excludedDatabaseList" 
    RMSnapshotWithExclude -Server $backupsource -backupSetName $backupsetname -excludedDbList ($excludedDatabaseList)

    ## Disconnect to the Replay Manager Services
    Log -message "Disconnecting to the Replay Manager" 
    CloseReplayManager -server $backupsource
}
