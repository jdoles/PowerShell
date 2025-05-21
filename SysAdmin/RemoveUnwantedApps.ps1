<#
    RemoveUnwantedApps.ps1
    Author: Justin Doles
    Requires: PowerShell 5 or higher
    Updated: 2025-05-20
    Repository: https://github.com/jdoles/PowerShell
#>
<#
    .SYNOPSIS
        This script removes unwanted Windows apps from the system.
    .DESCRIPTION
        This script removes unwanted Windows apps from the system using PowerShell. It checks for installed apps with names matching specific patterns and attempts to uninstall them.
        It also removes these apps from the system image if specified.
    .EXAMPLE
        RemoveUnwantedApps.ps1
        RemoveUnwantedApps.ps1 -RemoveFromImage
    .NOTES
        This script requires PowerShell 5 or higher and administrative privileges.
    .PARAMETER RemoveFromImage
        If specified, the script will remove the apps from the system image as well.
#>


param (
    [Parameter(Mandatory=$false)]
    [switch]$RemoveFromImage
)

# Function to log messages with a timestamp
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level]: $Message"
}

# Function to remove unwanted apps
function Remove-Apps {
    param (
        [string]$AppName,
        [switch]$RemoveFromImage
    )

    # Get the app information using Get-AppxPackage
    $appInfo = Get-AppxPackage -AllUsers | Where-Object {$_.name -like "*$AppName*"}
    if ($appInfo) {
        if ($appInfo.Count -gt 1) {
            Write-Log "Multiple instances of $($appInfo.Name) found. Removing all instances."
            foreach ($instance in $appInfo) {
                if ($instance.NonRemovable -eq $true) {
                    Write-Log -Message "Cannot remove: $($instance.Name) (Non-removable)" -Level "WARN"
                } else {
                    # Remove the app using Remove-AppxPackage
                    Write-Log -Message "REMOVE: $($instance.Name)"
                    $instance | Remove-AppxPackage -AllUsers
                    $script:appsRemoved++
                }
            }
        } else {
            Write-Log -Message "REMOVE: $($appInfo.Name)"
            # Remove the app using Remove-AppxPackage
            $appInfo | Remove-AppxPackage -AllUsers
            $script:appsRemoved++
        }
    } else {
        Write-Log -Message "$appName not found."
    }

    # If the RemoveFromImage switch is specified, remove the app from the system image
    if ($RemoveFromImage) {
        $appImage = Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -like "*$AppName*"}
        if ($appImage) {
            # Remove the app from the image using Remove-AppxProvisionedPackage
            Write-Log -Message "REMOVE: $AppName from image..."
            $appImage | Remove-AppxProvisionedPackage -Online
            $script:appsRemoved++
        } else {
            Write-Log -Message "$AppName not found in image."
        }
    }
}

# List of unwanted Microsoft apps to remove
$software = @(
    "Microsoft.BingFinance",
    "Microsoft.BingNews",
    "Microsoft.BingSports",
    "Microsoft.BingWeather",
    "Microsoft.Getstarted"
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MinecraftEducationEdition",
    "Microsoft.SkypeApp",
    "Microsoft.WindowsCommunicationsApps",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.XboxApp",    
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    #"Microsoft.XboxGameCallableUI", # this does not seem to be removable
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo"
)

# Counter for the number of apps found
$appsRemoved = 0

# Loop through each unwanted app and remove it if found

Write-Log -Message "$($software.Count) unwanted apps will be removed."
if ($RemoveFromImage) {
    Write-Log -Message "Apps will be removed from the system image as well."
}

foreach ($app in $software) {
    Write-Log -Message "Checking for $app..."
    if ($RemoveFromImage) {
        Remove-Apps -AppName $app -RemoveFromImage
    } else {
        Remove-Apps -AppName $app
    }    
}

# Check if any unwanted apps were found and removed
if ($appsRemoved -eq 0) {
    Write-Log -Message "No unwanted apps removed."
} else {
    Write-Log -Message "$appsRemoved unwanted apps removed."
}