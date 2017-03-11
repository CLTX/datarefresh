if ("GSMA_Destination" -as [type] -eq $null) {
Add-Type -TypeDefinition @"
  
    using System;
    public class GSMA_Destination 
    { 
        // The name of the Server Receiving GSMA Datarefresh. 
        public string ServerName { get; set;} 
         
        // The Folder Name where New Volume will be created 
        public string FolderName { get; set; }   

        // New RDM Identifier Name 
        public string NewRDMIdentifer { get; set; }

        // The Volume ShortName
        public string ShortName { get { return ServerName.Substring(5);}}
        
        // The Volume OldRDMName
        public string OldRDMName { get { return String.Format("{0}_RDM_VOL1", ShortName ); }} 

        // The Volume NewRDMName
        public string NewRDMName { get { return String.Format("{0}_RDM_VOL1A", ShortName ); }} 

        // The Volume NewScsiName
        public string NewScsiName { get { return String.Format("DAE01_{0}_RDM_VOL1A", ShortName ); }} 

        // The Vsphere Cluster where the Volume will be mapped to
        public string ServerMapping { get; set; }
        
        // The VMHost that owns this VM
        public string OwningHost { get; set; } 

        // The SQL Data Path
        public string DataPath { get; set; } 

        // The SQL Log Path
        public string LogPath { get; set; } 

        // The VM OS Version
        public string OSVersion { get; set; } 

        // The VM DriveLetters to be refreshed
        public string DriveLetters { get; set; } 
    }
"@
}