<#
    RemoveUnwantedApps.ps1
    Author: Justin Doles
    Requires: PowerShell 5 or higher
    Updated: 2025-05-16
#>
<#
    .SYNOPSIS
        This script removes unwanted Windows apps from the system.
    .DESCRIPTION
        This script removes unwanted Windows apps from the system using PowerShell. It checks for installed apps with names matching specific patterns and attempts to uninstall them.
    .EXAMPLE
        RemoveUnwantedApps.ps1
    .NOTES
        This script requires PowerShell 5 or higher and administrative privileges.
    .PARAMETER None
        No parameters are required for this script.
#>

# List of unwanted Microsoft apps to remove
$software = @(
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxIdentityProvider",
    #"Microsoft.XboxGameCallableUI", # this does not seem to be removable
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.MinecraftEducationEdition"
    "Microsoft.YourPhone",
    "Microsoft.SkypeApp"
)

# Counter for the number of apps found
$appsFound = 0

# Loop through each unwanted app and remove it if found
foreach ($app in $software) {
    Write-Host "Checking for $app..."
    # Get the app information using Get-AppxPackage
    $appInfo = Get-AppxPackage -AllUsers | Where-Object {$_.name -like "*$app*"}
    if ($appInfo) {
        if ($appInfo.Count -gt 1) {
            Write-Host "Multiple instances of $($appInfo.Name) found. Removing all instances."
            foreach ($instance in $appInfo) {
                if ($instance.NonRemovable -eq $true) {
                    Write-Host "Cannot remove: $($instance.Name) (Non-removable)"
                } else {
                    Write-Host "Removing: $($instance.Name)"
                    # Remove the app using Remove-AppxPackage
                    $instance | Remove-AppxPackage -AllUsers
                    $appsFound++    
                }                
            }
        } else {
            Write-Host "Removing: $($appInfo.Name)"
            # Remove the app using Remove-AppxPackage
            $appInfo | Remove-AppxPackage -AllUsers
            $appsFound++
        }
    } else {
        Write-Host "$app not found."
    }
}

# Check if any unwanted apps were found and removed
if ($appsFound -eq 0) {
    Write-Host "No unwanted apps found."
} else {
    Write-Host "$appsFound unwanted apps removed."
}