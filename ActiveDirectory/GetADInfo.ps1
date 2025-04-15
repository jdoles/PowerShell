<#
    GetADInfo.ps1
    Author: Justin Doles
    Requires: PowerShell 7 or higher
#>
<#
.SYNOPSIS
Gathers Active Directory domain information such as site names, subnets, and domain controllers.

.DESCRIPTION
Gathers Active Directory domain information such as site names, subnets, and domain controllers. The information is exported to CSV files for further analysis.

.INPUTS
None

.EXAMPLE
PS > ./GetADInfo.ps1

.NOTES
Requires ActiveDirectory module

#>

# Check if the Active Directory module is loaded
if (-not (Get-Module -Name ActiveDirectory)) {
    Write-Host "Active Directory module is not loaded. Please load it before running this script."
    exit
}

# Report Path
# Alter this as desired.
$reportpath = (Get-Item Env:USERPROFILE).Value + "\Desktop\ADInfo"

# Check if the report path exists, if not create it
if (-not (Test-Path -Path $reportpath)) {
    New-Item -Path $reportpath -ItemType Directory | Out-Null
}

# Collection of site and domain controller information
# Initialize arrays to hold site and domain controller information
$siteinfo = [System.Collections.ArrayList]::new()
$dcinfo = [System.Collections.ArrayList]::new()

# Get the current domain name
$domain = (Get-ADDomain).Name

Write-Host "Gathering domain information for $domain"
# Get the domain information
$sites = Get-ADReplicationSite -Filter *
$sitelinks = Get-ADReplicationSiteLink -Filter *
$dcs = Get-ADDomainController -Filter * | Select-Object -Property Name,HostName,Site,IPv4Address,OperatingSystem,OperatingSystemVersion,IsGlobalCatalog,OperationMasterRoles,Forest,Domain

Write-Host "Gathering site information"
# Loop through each site and gather information
$sites | ForEach-Object {
    $site = [PSCustomObject]@{
        SiteName = $_.Name
        SiteDistinguishedName = $_.DistinguishedName
        SiteSubnets = ''
        SiteLink = ''
        SiteDC = [System.Collections.ArrayList]::new()
    }
    $dn = $site.SiteDistinguishedName
    Get-ADReplicationSubnet -Filter "Site -eq '$dn'" | ForEach-Object {
        $site.SiteSubnets += $_.Name + ","
    }
    $site.SiteSubnets = $site.SiteSubnets.Trim(",")

    $sitelinks | ForEach-Object {
        if ($_.SitesIncluded -contains $site.SiteDistinguishedName) {
            $site.SiteLink = $_.Name
        }
    }

    $dcs | ForEach-Object {
        if ($_.Site -eq $site.SiteName) {
            $site.SiteDC += $_.Name + ","
        }
    }
    $site.SiteDC = $site.SiteDC.Trim(",")

    $siteinfo.Add($site) | Out-Null
}
# Get the domain controller information
$dcs | ForEach-Object {
    $dc = [PSCustomObject]@{
        Name = $_.Name
        HostName = $_.HostName
        Site = $_.Site
        IPV4Address = $_.IPv4Address
        OperatingSystem = $_.OperatingSystem + " " + $_.OperatingSystemVersion
        GlobalCatalog = $_.IsGlobalCatalog ? "Yes" : "No"
        OperationMasterRoles = $_.OperationMasterRoles.Count -gt 0 ? $_.OperationMasterRoles -join "," : "None"
        Forest = $_.Forest
        Domain = $_.Domain
    }
    $dcinfo.Add($dc) | Out-Null
}

# Export the information to CSV files
Write-Host "Exporting reports"
$siteinfo | Export-Csv -Path "$reportpath\siteinfo.csv"
$dcinfo | Export-Csv -Path "$reportpath\dcinfo.csv"
Write-Host "Reports saved to $reportpath"