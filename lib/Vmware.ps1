If ( !( Get-PSSnapin | Where-Object { $_.Name -eq "VMware.VimAutomation.Core" } ) )
{
    Add-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue
}


function OpenVCenter
{
    ## Connect to vCenter
    Log -message  $("Connecting to vCenter server: " + $appSettings["VmwareVCenterServer"])
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope Session -Confirm:$false 

    Connect-VIServer -Server $appSettings["VmwareVCenterServer"] -User $appSettings["FullyQualifiedAdminUser"] -Password $(GetUnsecuredPassword $appSettings["AdminUserPassword"]) -WarningAction SilentlyContinue
}

function CloseVCenter()
{
    ## Connect to vCenter
    Log -message  $("Disconnecting from vCenter server: " + $appSettings["VmwareVCenterServer"])
    Disconnect-VIServer -Server $appSettings["VmwareVCenterServer"]  -Confirm:$false 
}

Workflow RescanAllHBAs
{
    param(
    [string]$sessionId,
    [string]$vcServer,
    [string[]]$vmHostNames)
            
    foreach -parallel ($vmHostName in $vmHostNames)
    {
        InlineScript {
            Add-PSSnapin VMware.VimAutomation.Core 
            connect-viserver -Server $using:vcServer -session $using:sessionId
            $vmHost = Get-VMHost -Name $using:vmHostName
            Get-VMHostStorage -RescanAllHba  -VMHost $vmHost
        }
                
    }

}

<###############################
    Experimental Testing using workflows

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    DO NOT USE FOR PRODUCTION
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

##################################>
function RescanAllHBAs2
{
    param(
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl[]]$vmHosts)

    $modules = $(Get-Module | Where-Object { $_.ModuleType -eq "Script" -and ($_.Name -eq "Vmware" -or $_.Name -eq "Common") }).Path

    $inputObj = New-Object -TypeName psobject -Property @{
      VCServerName = $global:DefaultVIServer.Name
      VCServerSessionId = $global:DefaultVIServer.SessionId
      VCServer = $global:DefaultVIServer
      ScriptDirectory = $global:executingScriptDirectory
      AppSettings = $appSettings
    }

    
    <#-AdditionalInputObject $inputObj#>
    invoke-parallel -InputObject $vmHosts -parameter $inputObj -throttle $vmHosts.Count -Modules $modules -runspaceTimeout 30 -ScriptBlock {  
        param($vmHost,
            $parameter)    
        try {
        

        #Import-Module "$($parameter.ScriptDirectory)\lib\Common.ps1" -Force
        #Import-Module "$($parameter.ScriptDirectory)\lib\Vmware.ps1" -Force       
        $appSettings = $parameter.AppSettings

        #Write-Host $parameter

        #OpenVCenter
        connect-viserver -Server $parameter.VCServerName -session $parameter.VCServerSessionId


        Log -message "Rescanning HBAs on $($vmHost.Name)" 
        #$vmGuest = Get-VMGuest -VM "VSUSATAR01"
        #Get-VMHostStorage -RescanAllHba -VMHost 

        }
        catch {
            Log -message $Error

        }
        
    }
   
}


function GetScsiLunFromId($identifier, $vmHost)
{
    return get-scsilun -VMHost $vmHost -CanonicalName $identifier
}

function Rename-ScsiLun {

    param (
        $scsiLun, 
        [string] $newName, 
        $vmHost,
        [string] $uuid = $null)
    
    if(!$uuid) {
 	    $uuid = $scsiLun.ExtensionData.Uuid
    }
	$storSys = Get-View $vmHost.ExtensionData.ConfigManager.StorageSystem
	$storSys.UpdateScsiLunDisplayName($uuid, $newName)
}


### (If we are adding a new RDM, just call the ADD action. If we are deleting, just a delete. If we want to update the settings, run an update ###
function Rescan-HBAsESXiserial
{
    param(
    [object[]]$esxCliList,
    [string]$action)
    #######################################################################
    # $Action can be:
    # add : Perform rescan and only add new devices if any,
    # delete: perform rescan and only delete DEAD devices,
    # update: Rescan existing paths only and update path states,
    # all: Perform rescan and do all operations (Default but it's slower).
    #######################################################################
	$count = $esxCliList.count
	for($i=0; $i -lt $count; $i++)
	{
	$adaptersUp = $esxCliList[$i].storage.core.adapter.list() | where {$_.LinkState -eq "link-up"}
    $countadapter = $adaptersUp.Count
    for($j=0; $j -lt $countadapter; $j++)
	    { 
	    $esxCliList[$i].storage.core.adapter.rescan($adaptersUp[$j].HBAName, $false, $false, $false, $action) 
	    }
	}
Start-Sleep 5
}