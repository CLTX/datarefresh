if ("error_object" -as [type] -eq $null) {
Add-Type -TypeDefinition @"
  
    using System;
    public class error_object
    { 
        // failing host
        public string errorhost { get; set; }
		
		// error category information
        public string errorcategoryInfo { get; set;} 
         
        // error reason
        public string errorreason { get; set; }   

        // failing scriptname
        public string errorscriptname { get; set; }
        
        // error position message
        public string positionmessage { get; set; } 

        // error message
        public string errormessage { get; set; } 
        
    }
"@
}