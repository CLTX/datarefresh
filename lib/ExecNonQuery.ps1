# Performs an ExecuteNonQuery command against the database connection. 
function ExecNonQuery 
{ 
    param ($conStr, $cmdText) 
 
    # Determine if parameters were correctly populated. 
    if (!$conStr -or !$cmdText) 
    { 
        # One or more parameters didn't contain values. 
        Log -message "ExecNonQuery function called with no connection string and/or command text." 
    } 
    else 
    { 
        Log -message "Creating SQL Connection..." 
        # Instantiate new SqlConnection object. 
        $Connection = New-Object System.Data.SQLClient.SQLConnection 
         
        # Set the SqlConnection object's connection string to the passed value. 
        $Connection.ConnectionString = $conStr 
         
        # Perform database operations in try-catch-finally block since database operations often fail. 
        try 
        { 
            Log -message "Opening SQL Connection..." 
            # Open the connection to the database. 
            $Connection.Open() 
             
            Log -message "Creating SQL Command..." 
            # Instantiate a SqlCommand object. 
            $Command = New-Object System.Data.SQLClient.SQLCommand 
            # Set the SqlCommand's connection to the SqlConnection object above. 
            $Command.Connection = $Connection 
            # Set the SqlCommand's command text to the query value passed in. 
            $Command.CommandText = $cmdText 
             
            Log -message "Executing SQL Command..." 
            # Execute the command against the database without returning results (NonQuery). 
            $Command.ExecuteNonQuery() 
        } 
        catch [System.Data.SqlClient.SqlException] 
        { 
            # A SqlException occurred. According to documentation, this happens when a command is executed against a locked row. 
            Log -message "One or more of the rows being affected were locked. Please check your query and data then try again." 
        } 
        catch 
        { 
            # An generic error occurred somewhere in the try area. 
            Log -message "An error occurred while attempting to open the database connection and execute a command." 
        } 
        finally { 
            # Determine if the connection was opened. 
            if ($Connection.State -eq "Open") 
            { 
                Log -message "Closing Connection..." 
                # Close the currently open connection. 
                $Connection.Close() 
            } 
        } 
    } 
Log -message "Query Complete!"
} 