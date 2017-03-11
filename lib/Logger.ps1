## Function that initialize new log file, spunk formatted, to replace transcript
Function Start-LogTranscript {
  param ([string] $path)
  $timestamp = Get-Date -Format yyyyMMddHHmmss
  
  ## This variable will be used to log every line.
  $global:FullLoggingPath = "$path\logs\$scriptName-{0}.txt" -f $timestamp
  
  $username = "$env:USERDOMAIN\$env:username"
  $logtime = LoggingTime
  $message = ',Action='+'"Datarefresh start"'+',Username='+'"'+$($username)+'"'
  Write-output "$($logtime)$($message)" | Out-File -FilePath $global:FullLoggingPath -Force:$Force
  Write-host "Starting Datarefresh Logging. Initial Time= $($timestamp)" -ForegroundColor Cyan
}

## Just write last line into Log file to report logging has finished
Function Stop-LogTranscript
{
  $message = "Datarefresh Finished. Output file is $global:FullLoggingPath"
  Log -message $message
}


## Function Below return DateTime in splunk format
function LoggingTime {
    $logtime = 'EventTime=' + '"' + [dateTime]::Now.ToString("MM/dd/yyyy HH:mm:ss") + '"'
    return $logtime
}


## This function does a write-output adding time & action in splunk format.
function Log {
    param([string] $message)
    $logtime = LoggingTime
    $FormattedMessage = ',Action=' + '"' + $($message) +'"' + ',Type=' + '"OK"'
    Write-output "$($logtime)$($FormattedMessage)" | Out-File -FilePath $global:FullLoggingPath -Force -Append
    Write-host $message 
}


## This function does a write-output adding time & action in splunk format.
function Log-Warning {
    param([string] $message)
    $logtime = LoggingTime
    $FormattedMessage = ',Action=' + '"' + $($message) + '"' + ',Type=' + '"WARNING"'
    Write-output "$($logtime)$($FormattedMessage)" | Out-File -FilePath $global:FullLoggingPath -Force -Append
    Write-host $message -ForegroundColor Yellow
}


## This function does a write-output adding time & action in splunk format.
function Log-Error {
    param([string] $message)
    $logtime = LoggingTime
    $FormattedMessage = ',Action=' + '"' + $($message) +'"' + ',Type=' + '"ERROR"'
    Write-output "$($logtime)$($FormattedMessage)" | Out-File -FilePath $global:FullLoggingPath -Force -Append
    Write-host $message -ForegroundColor Red
}
