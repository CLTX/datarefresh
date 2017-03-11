function LoadConfig([string] $path)
{
    if(!$global:appSettings) {
        $global:appSettings = [hashtable]::Synchronized(@{})
    }

    if(!(test-path $path)) {
        return;
    }

    $config = [xml](get-content $path)
    foreach ($addNode in $config.configuration.appsettings.add) {
        if ($addNode.value.Contains(‘,’)) {
            # Array case
            $value = $addNode.value.Split(‘,’)
            for ($i = 0; $i -lt $value.length; $i++) { 
                $value[$i] = $value[$i].Trim() 
            }
        }
        elseif($addNode.type -eq "secure"){
            $value = ConvertTo-SecureString $addNode.Value -AsPlainText -force
        }
        else {
            # Scalar case
            $value = $addNode.value
        }
     $global:appSettings[$addNode.key] = $value
    }
}

function Init([string] $path) {
    Log -message "Loading Common Config"
    LoadConfig -path $("$executingScriptDirectory\conf\yourCompany.config")
    LoadAppConfig
}

function LoadAppConfig() {
    Log -message  "Loading App Config $($configPath)"
    $Private:configPath = "$executingScriptDirectory\conf\$scriptName.config";
    LoadConfig -path $($configPath);
}

function GetUnsecuredPassword([SecureString] $password)
{
    return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
}