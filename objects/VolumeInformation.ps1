if ("VolumeInformation" -as [type] -eq $null) {

# Wrap in a try-catch in case we try to add this type twice.
# Create a class to hold an IIS Application Service's Information.
Add-Type -TypeDefinition @"
    using System;
     
    public class VolumeInformation
    {
        // The name of the Server to which the volume belongs.
        public string ServerName { get; set;}
         
        // The drive letter of the volume.
        public string AccessPath { get; set; }

        public string DriveLetter {get {  return AccessPath.Substring(0, 1); } }
 
        // The volume name in Compellent.
        public string Name { get; set; }

        public string Folder {get; set; }

        public string CanonicalName {get {  return String.Format("naa.{0}", DeviceId); } }

        public string DeviceId {get; set; }

        public UInt32 Index {get; set; }

        public string Label {get; set; }

        public string SerialNumber {get; set; }

        public string StorageCenterName {get; set; }

        public string RemoteStorageCenterName {get; set; }
        public UInt32 RemoteVolumeIndex {get; set; }

 
        // Implicit Constructor.
        public VolumeInformation() { }

        public string GenerateVolumeName() {
            
            return String.Format("{0}_{1}_{2}",
                ServerName.Substring(5),
                DriveLetter,
                Label);

        }
    }
"@ 
}