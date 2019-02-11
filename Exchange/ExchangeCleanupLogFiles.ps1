<#
    ExchangeCleanupLogFiles.ps1
    Updated: 2018-12-03
    Author: Justin Doles
    Requires: PowerShell 5.1 or higher
#>
<#
.SYNOPSIS
Deletes Exchange log files older than X days

.DESCRIPTION
Deletes Exchange log files older than X days

.EXAMPLE
None

.NOTES

#>

Param ( 
	[Parameter(Mandatory=$True)]
        [string]$Computer
)

try {
    # General script variables
    $ScriptName = ($MyInvocation.MyCommand).Name
    $ScriptPath = $MyInvocation.MyCommand.Path
    $ScriptDir = Split-Path $ScriptPath
    $ScriptServer = $Env:ComputerName

    $MailTo = "alerts@example.com"
    $MailFrom = "no-reply@example.com"
    $MailSubject = "[SUCCESS] Exchange Log Cleanup $Computer"
    $MailPriority = "Low"
    $MailServer = "mail.example.com"
    
    Invoke-Command -ComputerName $Computer -ErrorAction Stop -ScriptBlock {
        # create the event source if it doesn't exist
        New-EventLog -LogName "Application" -Source "CustomScripts" -ErrorAction SilentlyContinue
        # text that will be written to the event log upon completion
        $logmessage = ""
        # you can alter the numbers of days to retain logs here
        $lastwrite = (Get-Date).AddDays(-14)
        $totalsize = 0
        $deletedfiles = 0
        # get the list of log files that match the criteria
        $files = Get-Childitem -Path "c:\Program Files\Microsoft\Exchange Server\V15\Logging\" -Include "*.log" -Recurse -File -ErrorAction SilentlyContinue | Where-Object {$_.LastWriteTime -le "$lastwrite"}
        $logmessage += "Files Matched: " + $files.Count + "`n"
        # loop through the list of files
        $files | ForEach-Object {
            try {
                # remove the file
                Remove-Item $_.FullName -Force -ErrorAction Stop | Out-Null
                # increment the counters for size & count
                $totalsize += $_.Length
                $deletedfiles++
            } catch {
                # do not increment counters. often times the the log files are in use and cannot be deleted
            }
        }
        $logmessage += "Files Deleted: $deletedfiles`n"
        $logmessage += "Size: $totalsize bytes`n"
        $logmessage += "** It's normal to see 0 files deleted. Certain log files remain in use while Exchange is running. ***`n"
        $logmessage += "_________________________________________`n"
        $logmessage += "Server: " + $using:ScriptServer + "`nScript: " + $using:ScriptName + "`nScript Path: " + $using:ScriptDir
        Write-EventLog -LogName Application -Source "CustomScripts" -EventId 1000 -EntryType Information -Message $logmessage
        Send-MailMessage -To $using:MailTo -From $using:MailFrom -SmtpServer $using:MailServer -Subject $using:MailSubject -Priority Low -Body $logmessage
    }
} catch {
    $mailmessage = $Error[0].Exception.ToString()
    $mailmessage += "<hr>"
    $mailmessage += "<p style=`"font-family: courier; font-style: italic`">Server: " + $Env:ComputerName + "<br>Script: " + $ScriptName + "<br>Script Path: " + $ScriptDir
    $mailmessage += "</p>"
    Send-MailMessage -To $MailTo -From $MailFrom -SmtpServer $MailServer -BodyAsHtml -Subject "[ERROR] Exchange Log Cleanup $Computer" -Priority High -Body $mailmessage
}
