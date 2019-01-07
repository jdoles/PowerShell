<#
    PasswordExpirationNotice.ps1
    Updated: 2019-01-07
    Author: Justin Doles
    Requires: PowerShell 5.1 or higher
#>
<#
.SYNOPSIS
Notifies users of expiring passwords

.DESCRIPTION
Notifies users of expiring passwords.  Also sends a list of soon to be expiring accounts to the administrator.

.INPUTS
None

.EXAMPLE
PS > ./PasswordExpirationNotice.ps1

.NOTES
Requires ActiveDirectory module

#>
Param (
	[Parameter(Mandatory=$False)]
        [int]$DaysToNotice = 10,
    [Parameter(Mandatory=$False)]
        [string]$ADSearchBase = "dc=example,dc=com",
    [Parameter(Mandatory=$False)]
        [array]$ExcludedAccounts = @("DiscoverySearchMailbox", "SystemMailbox"),
    [Parameter(Mandatory=$False)]
        [string]$HelpDeskEmail = "helpdesk@example.com",
    [Parameter(Mandatory=$False)]
        [string]$UserEmailClosing = "The Help Desk Team",
    [Parameter(Mandatory=$False)]
        [bool]$LogToServer = $True,
    [Parameter(Mandatory=$False)]
        [string]$MailSubject = "Domain Password Expiration Notice",
    [Parameter(Mandatory=$False)]
        [string]$MailFrom = "no-reply@example.com",
    [Parameter(Mandatory=$False)]
        [string]$AdminEmail = "admins@example.com",
    [Parameter(Mandatory=$False)]
        [string]$MailServer = "mail.example.com"
)

# General script variables
$ScriptName = ($MyInvocation.MyCommand).Name
$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir = Split-Path $ScriptPath

New-EventLog -LogName "Application" -Source "CustomScripts" -ErrorAction SilentlyContinue
Write-EventLog -LogName Application -Source "CustomScripts" -EventId 1000 -EntryType Information -Message "$scriptName Started"

try {
    # load the AD tools
    Import-Module ActiveDirectory -ErrorAction Stop
    # get the domain name
    $domain = (Get-ADDomain).Name
    $domaindns = (Get-ADDomain).DNSRoot
    # get the MaxPasswordAge from AD
    $maxpasswordage = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge.Days
    # admins summary
    $summary = "<body style=`"font-family: Verdana, sans-serif`">
    <h1>$domain Password Expiration Summary</h1>
    <table style=`"font-family: Verdana, sans-serif`">
        <thead>
            <tr>
                <th>Name</th>
                <th>Days</th>
                <th>Expiry Date</th>
            </tr>
        </thead>
        <tbody>"

    if ($maxpasswordage -le 0) {
        # MaxPasswordAge is not configured. nothing we can do here.
        throw "Maximum Password Age not configured...exiting"
    } else {
        # get the list of users with expiring password
        $users = Get-ADUser -SearchBase $ADSearchBase -Filter {Enabled -eq $true -and PasswordNeverExpires -eq $false} -Properties "Name","EmailAddress","PasswordLastSet" | Select-Object Name, EmailAddress, @{n="PasswordAge";e={(New-TimeSpan -Start $_.PasswordLastSet -End (Get-Date)).Days}}, PasswordLastSet | Sort-Object -Property Name
        if ($users.Count -eq 0) {
            # no users
            Write-Host "No users with passwords expiring in $DaysToNotice days"
        } else {
            $users | ForEach-Object {
                $daysleft = ($maxpasswordage - $_.PasswordAge)
                if ($daysleft -le $DaysToNotice -and $ExcludedAccounts -notcontains $_.Name) {
                    # password is within threshold and it's not an excluded account
                    # add to the admin summary
                    $summary += "<tr>`n"
                    $summary += "<td>"+$_.Name+"</td>`n"
                    if ( $daysleft -gt 0 ) {
                        $message += "Your password for the $domain domain will expire in <span style=`"color:red; font-weight: bold; text-decoration: underline`">$daysleft</span> day(s).  To avoid interruption with company services, please consider changing your password as soon as possible.<br><br>"
                    }
                    if ( $daysleft -le 0 ) {
                        $message += "Your password for the $domain domain has expired. Your access to company services may be impacted.<br><br>"
                    }
                    $summary += "<td>"+$_.PasswordLastSet+"</td>`n"
                    $summary += "</tr>`n"

                    # email to send to the user
                    $message = "<body style=`"font-family: Verdana, sans-serif`">"
                    $message += "<p>"+$_.Name+",<br>"
                    if ( $daysleft -gt 0 ) {
                        $message += "Your password for the $domain domain will expire in <span style=`"color:red; font-weight: bold; text-decoration: underline`">$daysleft</span> day(s).  To avoid interruption with company services, please consider changing your password as soon as possible.<br><br>"
                    }
                    if ( $daysleft -le 0 ) {
                        $message += "Your password for the $domain domain has expired. Your access to company services may be impacted.<br><br>"
                    }
                    $message += "If you need assistance, please contact the <a href=`"mailto:$($HelpDeskEmail)?subject=Password Expiration Notice Help`">Infrastructure team</a>.<br><br>"
                    $message += "Thank you,<br>"
                    $message += $UserEmailClosing
                    $message += "</p>"
                    $message += "<hr>"
                    $message += "<p><em><small>Notice Generated: "+(Get-Date -Format g)+"</small></em></p>"
                    $message += "</body>"

                    # send the email
                    # sleep to help throttle emails
                    Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 750)
                    Send-MailMessage -SmtpServer $MailServer -To $_.EmailAddress -From $HelpDeskEmail -Subject $MailSubject -Body $message -BodyAsHtml -Priority High
                }
            }
            Write-EventLog -LogName Application -Source "CustomScripts" -EventId 1000 -EntryType Information -Message "$ScriptName`nNotifed $($users.Count) users."
        }
        $summary += "</tbody>
            </table>
            <hr>
            <em><small>Server: " + $ScriptServer + "`nScript: " + $ScriptName + "`nScript Path: " + $ScriptDir + "</small></em>
        </body>"
        Send-MailMessage -SmtpServer $MailServer -To $AdminEmail -From $MailFrom -Subject $MailSubject -Body $summary -BodyAsHtml
    }
} catch {
    $ename = $_.Exception.GetType().Name
    $etext = $Error[0].Exception.ToString()
    Write-EventLog -LogName Application -Source "CustomScripts" -EventId 1000 -EntryType Error -Message "$ScriptName`n$etext"
    Write-Host $ScriptName":" $etext -ForegroundColor Red
}
