<#
    RemoveGoogleChrome.ps1
    Author: Justin Doles
    Requires: PowerShell 5 or higher
    Updated: 2025-06-04
    Repository: https://github.com/jdoles/PowerShell
#>
<#
    .SYNOPSIS
        This script uninstalls Google Chrome from the system.
    .DESCRIPTION
        This script uninstalls Google Chrome from the system using WMI and registry paths.
        This script handles both 64-bit and 32-bit installations, cleans up associated files and registry keys, and logs the process.
    .EXAMPLE
        RemoveGoogleChrome.ps1
    .NOTES
        This script requires PowerShell 5 or higher and administrative privileges.
    .PARAMETER None
        No parameters are required for this script.
#>

# Function to log messages with a timestamp
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Level) {
        "INFO" { $color = "Green" }
        "WARN" { $color = "Yellow" }
        "ERROR" { $color = "Red" }
        default { $color = "White" }
    }
    Write-Host "[$timestamp] [$Level]: $Message" -ForegroundColor $color
}

# Remove artifacts function to clean up files and registry keys
function Remove-Artifacts {
    param (
        [string]$Path,
        [string]$RegPath
    )
    
    if (Test-Path -Path $Path) {
        Write-Log "Removing folder $Path"
        Remove-Item -Path $Path -Force -Recurse -ErrorAction SilentlyContinue
    } else {
        Write-Log "Folder $Path does not exist." -Level "WARN"
    }

    if (Test-Path -Path $RegPath) {
        Write-Log "Removing registry key $RegPath"
        Remove-Item -Path $RegPath -Force -Recurse -ErrorAction SilentlyContinue
    } else {
        Write-Log "Registry key $RegPath does not exist." -Level "WARN"
    }
}

# 64 bit and 32 bit paths for Google Chrome
$chrome64RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\"
$chrome64BasePath = "C:\Program Files\Google\Chrome\"
$chrome32RegPath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
$chrome32BasePath = "C:\Program Files (x86)\Google\Chrome\"
# Registry path for Google Chrome classes
#$chromeClassesPath = "Registry::HKEY_CLASSES_ROOT\Installer\Products\"
$chromeClassesPath = "HKLM:\SOFTWARE\Classes\Installer\Products\"

Write-Host "Stopping Google Chrome processes..."
# Stop any running Google Chrome processes
Get-Process -Name "chrome" -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Log "Searching for Google Chrome installations..."
$chromeApp = Get-WmiObject Win32_Product -Filter "Name Like 'Google Chrome'"
$chrome64 = Get-ChildItem -path $chrome64RegPath -ErrorAction SilentlyContinue | Get-ItemProperty| Where-Object {$_.DisplayName -match "Google Chrome"} | Select-Object DisplayVersion, UninstallString
$chrome32 = Get-ChildItem -path $chrome32RegPath -ErrorAction SilentlyContinue | Get-ItemProperty| Where-Object {$_.DisplayName -match "Google Chrome"} | Select-Object DisplayVersion, UninstallString
$chromeClasses = Get-ChildItem -Path $chromeClassesPath | Get-ItemProperty | Where-Object { $_.ProductName -match "Google Chrome" }

if ($chromeApp) {
    Write-Log "Attempting to uninstall Google Chrome..."
    $uninstallCommand = $chromeApp.Uninstall()
    if ($uninstallCommand.ReturnValue -eq 0) {
        Write-Log "Successfully uninstalled Google Chrome."
    } else {
        switch ($uninstallCommand.ReturnValue) {
            1603 { Write-Log "Error $($uninstallCommand.ReturnValue): Generic MSI error." -Level "WARN" }
            1605 { Write-Log "Error $($uninstallCommand.ReturnValue): Google Chrome is not installed." -Level "WARN" }
            1612 { Write-Log "Error $($uninstallCommand.ReturnValue): Google Chrome installation source missing." -Level "WARN" }
            1614 { Write-Log "Error $($uninstallCommand.ReturnValue): Google Chrome is already uninstalled." -Level "WARN" }
            default { Write-Log "Failed to uninstall Google Chrome with error code $($uninstallCommand.ReturnValue)." -Level "ERROR" }
        }
    }
} else {
    Write-Log "Google Chrome not found in Win32_Product." -Level "WARN"
}

if ($chrome64) {
    Write-Log "Attempting to uninstall Google Chrome (64-bit)..."
    $chrome64Path = "$chrome64BasePath\Application\$($chrome64.DisplayVersion)\Installer\"
    if (Test-Path -Path $chrome64Path) {
        Start-Process -FilePath "$chrome64Path\setup.exe" -ArgumentList "--uninstall --channel=stable --system-level --verbose-logging --force-uninstall" -Wait
    } else {
        Write-Log "Google Chrome (64-bit) installer not found." -Level "ERROR"
    }
} else {
    Write-Log "Google Chrome (64-bit) not found in registry." -Level "WARN"
}

if ($chrome32) {
    Write-Log "Attempting to uninstall Google Chrome (32-bit)..."
    $chrome32Path = "$chrome32BasePath\Application\$($chrome32.DisplayVersion)\Installer\"
    if (Test-Path -Path $chrome32Path) {
        Start-Process -FilePath "$chrome32Path\setup.exe" -ArgumentList "--uninstall --channel=stable --system-level --verbose-logging --force-uninstall" -Wait
    } else {
        Write-Log "Google Chrome (32-bit) installer not found." -Level "ERROR"
    }
} else {
    Write-Log "Google Chrome (32-bit) not found in registry." -Level "WARN"
}

if ($chromeClasses) {
    Write-Log "Removing Google Chrome classes from registry..."
    foreach ($class in $chromeClasses) {
        Remove-Item -Path $class.PSPath -Force -Recurse -ErrorAction SilentlyContinue
    }
} else {
    Write-Log "No Google Chrome classes found in registry." -Level "WARN"
}

# Final cleanup of any remaining artifacts
Remove-Artifacts -Path $chrome64BasePath -RegPath $chrome64RegPath
Remove-Artifacts -Path $chrome32BasePath -RegPath $chrome32RegPath