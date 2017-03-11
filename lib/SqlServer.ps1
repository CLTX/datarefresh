

function Stop-SqlServer {
    param(
        [parameter(Mandatory=$True)]
        [string]$serverName 
    )
    
    Stop-Service -InputObject $(Get-Service -ComputerName $serverName -Name "MSSQLServer") -Force

}

function Start-SqlServerWithAgent {
    param(
        [parameter(Mandatory=$True)]
        [string]$serverName 
    )

    Start-Service -InputObject $(Get-Service -ComputerName $serverName -Name "MSSQLServer")
    Start-Service -InputObject $(Get-Service -ComputerName $serverName -Name "SQLSERVERAGENT")    
}


## Function to detach Data for xMedia Datarefresh
#TODO: Modify detach function to verify if any database coud be detached. Otherwise, don't call detach DBs SP.
function Detaching-xMedia-DBs 
{
    param (
        $xMediaServerName
    )

    try
    {
    # Open Connection to Server 
    $sqlconnection = new-object system.data.sqlclient.sqlconnection("Data Source=$($xMediaServerName);Initial Catalog=DBA;Integrated Security=SSPI;Connection Timeout=1500");
    $sqlconnection.Open();

    # Invoke Stored Procedrue 
	$sqlquery ="
		DECLARE @RC int  
		EXECUTE @RC = [dbo].[usp_SQL_Detach_DBs] @BY_SEARCH_STRING = 'xmedia%' 
		If @RC <> 0 
			Begin 
				RAISERROR (51000, 18, 1,  'DETACH DB FAILURE') 
			End" 
    $cmd = new-object system.data.sqlclient.sqlcommand ($sqlquery, $sqlconnection);
    $cmd.CommandTimeout = 0;
    $cmd.ExecuteNonQuery() | out-null
    }
    catch [System.Exception]
    {
        throw "Error: " + $_.Exception.Message + " 
	    -->> Contact DevOPs <<--"
    }
    finally
    {
        $sqlconnection.Close();
    }
}


## Attaching Data
function Attaching-xMedia-DBs 
{
    param (
        $xMediaSourceServerName,
        $xMediaServerName
    )

    try
    {
        # Open Connection to Server 
        $sqlconnection = new-object system.data.sqlclient.sqlconnection("Data Source=$($xMediaServerName);Initial Catalog=DBA;Integrated Security=SSPI;Connection Timeout=1500");
        $sqlconnection.Open();

        # Invoke Stored Procedrue 
	    $sqlquery = "
		    DECLARE @RC int  
		    EXECUTE @RC = [dbo].[usp_SQL_Attach_DBs] 
			    @BY_SEARCH_STRING = 'xmedia%' 
			    ,@SOURCE_SERVER = $($xMediaSourceServerName) 
			    If @RC <> 0 
				    Begin 
			            RAISERROR (51000, 18, 1,  'ATTACH DB FAILURE') 
				    End 
		    "
        $cmd = new-object system.data.sqlclient.sqlcommand ($sqlquery, $sqlconnection)
        $cmd.CommandTimeout = 0
        $cmd.ExecuteNonQuery() | out-null;
    }
    catch [System.Exception]
    {
        throw "Error: " + $_.Exception.Message + " 
	    -->> Contact DevOPs <<--"
    }
    finally
    {
        $sqlconnection.Close();
    }
}
