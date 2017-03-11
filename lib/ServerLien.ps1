function Lien-XMediaServer {
    param( [string] $serverName )
    
    Log -message "Liening $($serverName)"

    $connection = new-object system.data.sqlclient.sqlconnection("Data Source=PSUSAADB03;Initial Catalog=mm2_system;Integrated Security=SSPI;");
	$connection.Open()
	$adapter = new-object system.data.sqlclient.sqldataadapter ("select COUNT(*) as server_count from v_server where server_id = '$servername'", $connection)
	$set = new-object system.data.dataset
	$adapter.Fill($set) | Out-Null
	$dataTable = new-object system.data.datatable
	$dataTable = $set.Tables[0]
	$dataTable.Rows | ForEach-Object { $serverTableCount = $_["server_count"] }
	if ($serverTableCount -gt 0)
	{
		$cmd = new-object system.data.sqlclient.sqlcommand ("INSERT INTO server_liens VALUES ('$servername', 'Maintenance mode', 'daepatch', GETDATE(), 0, null)", $connection)
		$cmd.ExecuteNonQuery() | Out-Null
	}
	$connection.Close()
	Log -Message " $($servername) has been successfully liened."
}

function Unlien-XMediaServer {
    param( [string] $serverName )
    
    Log -message "Unliening $($serverName)"
	
	$connection = new-object system.data.sqlclient.sqlconnection("Data Source=PSUSAADB03;Initial Catalog=mm2_system;Integrated Security=SSPI;");
	$connection.Open()
	$cmd = new-object system.data.sqlclient.sqlcommand ("UPDATE server_liens SET released = 1, time_released = GETDATE() WHERE mas_server= '$servername' AND lien_owner='daepatch'", $connection)
	$cmd.ExecuteNonQuery() | Out-Null
	$connection.Close()
	Log -message " $($servername) is no longer liened."

}