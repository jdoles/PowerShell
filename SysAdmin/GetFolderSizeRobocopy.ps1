<#
    Get-FolderSizeRobocopy.ps1
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
    .PARAMETER MaxConcurrentJobs
        The maximum number of concurrent jobs to run. Default is 10. Adjust this based on your system's capabilities.
#>
param (
    [string]$RootPath = "C:\Temp",
    [string]$OutputCsv = "",
    [switch]$Recurse,
    [switch]$ShowConsoleOutput,
    [string[]]$ExcludeFolders = @(),
    [int]$MaxConcurrentJobs = 10
)

function Start-RobocopyJob {
    param($FolderPath)

    Start-Job -ScriptBlock {
        param($folderPath)

        $output = robocopy $folderPath NULL /L /NFL /NDL /NJH /BYTES /NC /NP 2>&1

        $bytes = 0
        $files = 0

        foreach ($line in $output) {
            if ($line -match "Bytes\s+:\s+(\d+)\s") {
                $bytes = [int64]$matches[1]
            } elseif ($line -match "Files\s+:\s+(\d+)") {
                $files = [int]$matches[1]
            }
        }

        return [PSCustomObject]@{
            Folder     = $folderPath
            SizeBytes  = $bytes
            SizeGB     = "{0:N2}" -f ($bytes / 1GB)
            FileCount  = $files
        }
    } -ArgumentList $FolderPath
}

# Step 1: Discover and filter folders
$folders = if ($Recurse) {
    Get-ChildItem -Path $RootPath -Directory -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Get-ChildItem -Path $RootPath -Directory -Force -ErrorAction SilentlyContinue
}

$folders = $folders | Where-Object {
    -not ($_.Attributes -match "ReparsePoint") -and
    -not ($ExcludeFolders -contains $_.Name)
}

if (-not ($ExcludeFolders -contains (Split-Path $RootPath -Leaf))) {
    $folders = @([pscustomobject]@{ FullName = $RootPath }) + $folders
}

$folderPaths = $folders.FullName
$total = $folderPaths.Count
$results = @()
$jobQueue = @()

$i = 0
while ($i -lt $total -or $jobQueue.Count -gt 0) {
    # Launch jobs up to the max concurrency
    while ($i -lt $total -and $jobQueue.Count -lt $MaxConcurrentJobs) {
        $path = $folderPaths[$i]
        $job = Start-RobocopyJob -FolderPath $path
        $jobQueue += $job
        $i++
    }

    # Wait for any job to complete and process it
    $completedJob = Wait-Job -Job $jobQueue -Any
    $results += Receive-Job -Job $completedJob
    Remove-Job -Job $completedJob
    $jobQueue = $jobQueue | Where-Object { $_.Id -ne $completedJob.Id }

    Write-Progress -Activity "Scanning folders" `
        -Status "$($results.Count) of $total complete" `
        -PercentComplete (($results.Count / $total) * 100)
}

Write-Progress -Activity "Scanning folders" -Completed

# Sort and output
$sortedResults = $results | Sort-Object SizeBytes -Descending

if ($ShowConsoleOutput) {
    $sortedResults | Format-Table Folder, SizeGB, FileCount -AutoSize
}

if ($OutputCsv) {
    $sortedResults | Export-Csv -Path $OutputCsv -NoTypeInformation
    Write-Host "`nFolder size report saved to '$OutputCsv'" -ForegroundColor Green
}
