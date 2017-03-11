function Handle-Error($error) 
{
    $format = "<style>"
    $format = $format + "BODY"
    $format = $format + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
    $format = $format + "TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:thistle}"
    $format = $format + "TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:palegoldenrod}"
    $format = $format + "</style>"
    $errMsg = Create-ErrorObject -error $error | ConvertTo-Html -head $format
    Send-Mail -subject "Datarefresh error" -message $errMsg -from "datarefresh@yourCompany.com" -to "Carlos <ctapia@yourCompany.com>, Vlad <vkupchan@yourCompany.com>"
    $message = "Error: $($error.errorreason) -- Details sent by email"
    Log-Error -message $message
    [Environment]::Exit("1");
}

function Create-ErrorObject
{
    param([Parameter(Mandatory=$True)] $error)
    $Object = New-Object error_object
    $Object.errorhost = hostname
    $Object.errorcategoryInfo = $error.CategoryInfo.Category
    $Object.errorreason = $error.CategoryInfo.reason
    $Object.errorscriptname = $error.InvocationInfo.ScriptName
    $Object.positionmessage = $error.InvocationInfo.positionMessage
    $Object.errormessage = $error.Exception.Message
    return $Object
}

