function ExecNonQuery {
    param ([System.Data.SqlClient.SqlConnection]$connection, 
        [string]$query, 
        [System.Data.SqlClient.SqlParameter[]] $sqlParameters, 
        [int] $queryTimeout = 90)

    $cmd = Get-SqlCmd -connection $connection -query $query -sqlParameters $sqlParameters -queryTimeout $queryTimeout

    $cmd.ExecuteNonQuery()
}

function Exec-NonQuerySP {
    param ([System.Data.SqlClient.SqlConnection]$connection, 
        [string]$query, 
        [System.Data.SqlClient.SqlParameter[]] $sqlParameters, 
        [int] $queryTimeout = 90)

    $cmd = Get-SqlCmd -connection $connection  -query $query -cmdType StoredProcedure -sqlParameters $sqlParameters -queryTimeout $queryTimeout

    $cmd.ExecuteNonQuery()
}


function ExecQuery {
    param ([System.Data.SqlClient.SqlConnection]$connection, 
        [string]$query, 
        [System.Data.CommandType] $cmdType = [System.Data.CommandType]::Text,
        [System.Data.SqlClient.SqlParameter[]] $sqlParameters, 
        [int] $queryTimeout = 90)

    
    $cmd = Get-SqlCmd -connection $connection -query $query -cmdType $cmdType -sqlParameters $sqlParameters -queryTimeout $queryTimeout

    #Run Query 
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)

    #Load Dataset
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataset)
    return $dataset
}

function Exec-ScalarQuery {
    param ([System.Data.SqlClient.SqlConnection]$connection, 
        [string]$query, 
        [System.Data.SqlClient.SqlParameter[]] $sqlParameters, 
        [int] $queryTimeout = 90)

    $cmd = Get-SqlCmd -connection $connection  -query $query -cmdType StoredProcedure -sqlParameters $sqlParameters -queryTimeout $queryTimeout

    return [Int]$cmd.ExecuteScalar()
}


function Get-SqlCmd {
    param(
        [System.Data.SqlClient.SqlConnection]$connection,
        [string]$query, 
        [System.Data.CommandType] $cmdType = [System.Data.CommandType]::Text,
        [System.Data.SqlClient.SqlParameter[]] $sqlParameters, 
        [int] $queryTimeout = 90
    )

    #Create a command object
    $cmd = $connection.CreateCommand()
    $cmd.CommandText = $query
    $cmd.CommandType = $cmdType

    if($sqlParameters -ne $null) {
        $cmd.Parameters.AddRange($sqlParameters)
    }
    $cmd.CommandTimeout = $queryTimeout
    
    return $cmd
}

function OpenConnection {
    param([string] $connectionString)
    $conn=new-object System.Data.SqlClient.SQLConnection
    $conn.ConnectionString = $connectionString
    $conn.Open()
    return $conn
}
function CloseConnection {
    param([System.Data.SqlClient.SqlConnection]$connection)
    $conn.Close()
}

function GetConnString {
    param([string] $server, [string] $database, [int] $timeout = 30)

    return "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $server,$database,$timeout

}