
function Send-Mail
{
    param( [Parameter(Mandatory=$True)][string]$subject, 
    [Parameter(Mandatory=$True)]$message, 
    [Parameter(Mandatory=$True)][string]$from, 
    [Parameter(Mandatory=$True)][string]$to )
		
	$smtpserver = 'smtp.office.yourCompany.com'
	$htmlmessage = New-Object System.Net.Mail.MailMessage $from, $to
	$htmlmessage.Subject = $subject
	$htmlmessage.IsBodyHTML = $true
	$htmlmessage.Body = $message
	$smtp = New-Object Net.Mail.SmtpClient($smtpServer)
	$smtp.Send($htmlmessage)
}