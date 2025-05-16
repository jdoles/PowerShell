<#
    GetDiskSpaceUsage.ps1
    Author: Justin Doles
    Requires: PowerShell 5 or higher
#>
<#
.SYNOPSIS
    This script calculates the size of each folder in a specified directory and sorts them by size.
.DESCRIPTION
    This script calculates the size of each folder in a specified directory and sorts them by size. It uses PowerShell's Get-ChildItem and Measure-Object cmdlets to gather folder sizes.
.EXAMPLE
    Get-DiskSpaceUsage -Path "C:\temp" -Recurse -ShowConsoleOutput
.NOTES
    This script requires PowerShell 5 or higher.
#>

$targetPath = "C:\"
if (Test-Path -Path $targetPath) {
    Write-Host "Enumerating: $targetPath"
    Get-ChildItem -Path $targetPath -Directory | Where-Object {
        -not ($_.Name -eq "System Volume Information") -and 
        -not ($_.Name -eq "Windows") -and
        -not ($_.Name -eq "Users")
    } | ForEach-Object {
        $folderPath = $_.FullName
        $folderSize = (Get-ChildItem -Path $folderPath -Recurse -ErrorAction SilentlyContinue | 
                    Where-Object { 
                        -not ($_.Attributes -match "ReparsePoint") -and
                        -not ($_.PSIsContainer)
                    }|
                    Measure-Object -Property Length -Sum).Sum

        [PSCustomObject]@{
            Folder = $_.FullName
            SizeGB = "{0:N2}" -f ($folderSize / 1GB)
        }
    } | Sort-Object SizeGB -Descending | Format-Table -AutoSize
} else {
    Write-Host "Target path does not exist: $targetPath"
    exit
}
