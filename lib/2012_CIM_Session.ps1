###############################################
# CIM CONNECTION LIBRARY                      #   
# Create and returns a new CIM Session        #
###############################################

function Create-NewCIMSession {
    param([Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$Server,
          [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]$Credentials,
          [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]$Protocol
    )
 
    #TRY CONNECT WITH SERVER WITH PROTOCOL BY DEFAULT WSMAN
    try {
        if($Credentials -eq $null){
            $global:session = New-CimSession -ComputerName $Server 
        }else{
            $global:session = New-CimSession -ComputerName $Server -Credential $Credentials
        }
    }catch { [system.exception]
        throw "THE PROTOCOL WSMAN FAILED" 
    }
    return $global:session
}
