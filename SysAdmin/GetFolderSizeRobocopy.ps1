<#
    GetFolderSizeRobocopy.ps1
    Author: Justin Doles
    Requires: PowerShell 5 or higher, Robocopy
#>
<#
    .SYNOPSIS
        This script calculates the size of each folder in a specified directory using Robocopy and sorts them by size.
    .DESCRIPTION
        This script calculates the size of each folder in a specified directory using Robocopy and sorts them by size. It uses Robocopy's /L option to list the size without copying files.
    .EXAMPLE
        Get-FolderSizeRobocopy -RootPath "C:\temp" -Recurse -ShowConsoleOutput
        Get-FolderSizeRobocopy -RootPath "C:\temp" -OutputCsv "C:\temp\folder_sizes.csv"
    .NOTES
        This script requires PowerShell 5 or higher and Robocopy.
    .PARAMETER RootPath
        The root path to scan for folder sizes. Default is "C:\Temp".
    .PARAMETER OutputCsv
        The path to save the output CSV file. If not specified, the output will be displayed in the console.
    .PARAMETER Recurse
        If specified, the script will scan all subdirectories recursively.
    .PARAMETER ShowConsoleOutput
        If specified, the script will display the output in the console.
    .PARAMETER ExcludeFolders
        An array of folder names to exclude from the scan. This can be used to skip specific folders.  Folder names are case-insensitive and are relative to the root path.
        For example, to exclude "Temp" and "Logs", use: -ExcludeFolders "Temp", "Logs".
#>
param (
    [string]$RootPath = "C:\Temp",
    [string]$OutputCsv = "",
    [switch]$Recurse,
    [switch]$ShowConsoleOutput,
    [string[]]$ExcludeFolders = @()
)

function Get-FolderStatsWithRobocopy {
    param (
        [string]$Path
    )

    $output = robocopy $Path NULL /L /NFL /NDL /NJH /BYTES /NC /NP 2>&1

    $bytes = 0
    $files = 0

    foreach ($line in $output) {
        if ($line -match "Bytes\s+:\s+(\d+)\s") {
            $bytes = [int64]$matches[1]
        }
        elseif ($line -match "Files\s+:\s+(\d+)") {
            $files = [int]$matches[1]
        }
    }

    return [PSCustomObject]@{
        Folder     = $Path
        SizeBytes  = $bytes
        SizeGB     = "{0:N2}" -f ($bytes / 1GB)
        FileCount  = $files
    }
}

# Build list of folders, excluding reparse points and user-defined folder names
$folders = if ($Recurse) {
    Get-ChildItem -Path $RootPath -Directory -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Get-ChildItem -Path $RootPath -Directory -Force -ErrorAction SilentlyContinue
}

$folders = $folders | Where-Object {
    -not ($_.Attributes -match "ReparsePoint") -and
    -not ($ExcludeFolders -contains $_.Name)
}

# Include root folder if it isn't excluded
if (-not ($ExcludeFolders -contains (Split-Path $RootPath -Leaf))) {
    $folders = @([pscustomobject]@{ FullName = $RootPath }) + $folders
}

# Scan with progress
$total = $folders.Count
$counter = 0
$results = @()

foreach ($folder in $folders) {
    $counter++
    Write-Progress -Activity "Scanning Folders" -Status "$counter of $total" -PercentComplete (($counter / $total) * 100)
    $results += Get-FolderStatsWithRobocopy -Path $folder.FullName
}

Write-Progress -Activity "Scanning Folders" -Completed

# Sort and output
$sortedResults = $results | Sort-Object SizeBytes -Descending

if ($ShowConsoleOutput) {
    $sortedResults | Format-Table Folder, SizeGB, FileCount -AutoSize
}

if ($OutputCsv) {
    $sortedResults | Export-Csv -Path $OutputCsv -NoTypeInformation
    Write-Host "`nFolder size report saved to '$OutputCsv'" -ForegroundColor Green
}
