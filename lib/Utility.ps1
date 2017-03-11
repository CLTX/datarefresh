<#
    Extracts the server short name
    Example: 
    GetServerShortName("VSUSATST01")

    returns "TST01"
#>
function GetServerShortName {
    param( [string] $serverName,
        [System.Boolean] $withServerNumber = $True)

        If($withServerNumber) {
            return $serverName.Substring(5);
        }
        Else {
            return $serverName.Substring(5, 3);
        }
}