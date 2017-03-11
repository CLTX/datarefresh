function Enable-Nagios {
    param(
        [string] $serverName    
    )
    
    Log -message "Enabling Nagios on Server: $($serverName) (give it a minute to refresh)" 
    Call-NagiosCmd -serverName $serverName -cmdIds @(24,28)

}

function Disable-Nagios {
    param(
        [string] $serverName    
    )
    
    Log -message "Disabling Nagios on Server: $($serverName) (give it a minute to refresh)" 
    Call-NagiosCmd -serverName $serverName -cmdIds @(25,29)

}


function Call-NagiosCmd {
    param(
        [string] $serverName,
        [int[]] $cmdIds
    )
    $serverName = $serverName.ToUpper()
    if ($serverName.StartsWith("VSUSA")) {
	    $subDomain = "devops-nagios"	
        $protocol = "https"
    } else {
	    $subDomain = "nagios"
	    $protocol = "http"
    }

    $cmdIds | ForEach-Object {
	    $url = "$($protocol)://$subDomain.office.yourCompany.com/nagios/cgi-bin/cmd.cgi?cmd_typ=$_&host=$serverName&cmd_mod=2"

        $webclient = new-object System.Net.WebClient
        $webclient.Credentials = new-object System.Net.NetworkCredential("daebuilduser", "1800SPrairie")
	    $webpage = $webclient.DownloadString($url);
    }
}