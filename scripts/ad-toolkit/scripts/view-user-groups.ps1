#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Displays the Active Directory group memberships of a user.

.DESCRIPTION
    Requests an exact username and displays the user's Active Directory
    group memberships, including:

    - Group name
    - Group category
    - Group scope
    - Distinguished name

    Potentially privileged groups are highlighted in yellow.

.NOTES
    This script is read-only and does not modify Active Directory.
#>

$ErrorActionPreference = "Stop"

# Import the Active Directory module.
try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "Failed to import the Active Directory module." `
        -ForegroundColor Red

    Write-Host "Details: $($_.Exception.Message)" `
        -ForegroundColor DarkRed

    exit 1
}

# Request an exact username.
$Username = Read-Host "Enter the username"

if (-not $Username -or $Username.Trim().Length -eq 0) {
    Write-Host ""
    Write-Host "Please enter a valid username." `
        -ForegroundColor Yellow

    exit 1
}

$Username = $Username.Trim()

# Retrieve the user.
try {
    $User = Get-ADUser `
        -Identity $Username `
        -Properties DisplayName, Enabled, DistinguishedName `
        -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "User '$Username' was not found in Active Directory." `
        -ForegroundColor Red

    Write-Host "Details: $($_.Exception.Message)" `
        -ForegroundColor DarkRed

    exit 1
}

# Retrieve group memberships.
try {
    $Groups = @(
        Get-ADPrincipalGroupMembership `
            -Identity $User.DistinguishedName `
            -ErrorAction Stop |
        Sort-Object Name
    )
}
catch {
    Write-Host ""
    Write-Host "Failed to retrieve group memberships." `
        -ForegroundColor Red

    Write-Host "Details: $($_.Exception.Message)" `
        -ForegroundColor DarkRed

    exit 1
}

$DisplayName = if ($User.DisplayName) {
    $User.DisplayName
}
else {
    "N/A"
}

$EnabledText = if ($User.Enabled) {
    "Yes"
}
else {
    "No"
}

Write-Host ""
Write-Host "User Group Memberships" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host ""

Write-Host ("{0,-18}: {1}" -f "Display name", $DisplayName)
Write-Host ("{0,-18}: {1}" -f "Username", $User.SamAccountName)

if ($User.Enabled) {
    Write-Host ("{0,-18}: {1}" -f "Account enabled", $EnabledText) `
        -ForegroundColor Green
}
else {
    Write-Host ("{0,-18}: {1}" -f "Account enabled", $EnabledText) `
        -ForegroundColor Red
}

Write-Host ("{0,-18}: {1}" -f "Groups found", $Groups.Count)
Write-Host ""

if ($Groups.Count -eq 0) {
    Write-Host "No group memberships were found." `
        -ForegroundColor Yellow

    exit 0
}

# Groups that may provide elevated or sensitive access.
$PrivilegedGroupPatterns = @(
    "Domain Admins",
    "Enterprise Admins",
    "Schema Admins",
    "Administrators",
    "Account Operators",
    "Server Operators",
    "Backup Operators",
    "Print Operators",
    "Group Policy Creator Owners",
    "DnsAdmins"
)

$TableFormat = "{0,-45} {1,-12} {2,-15}"

Write-Host (
    $TableFormat -f `
        "Group Name",
        "Category",
        "Scope"
) -ForegroundColor Cyan

Write-Host ("-" * 76) -ForegroundColor DarkGray

foreach ($Group in $Groups) {
    $GroupName = if ($Group.Name) {
        $Group.Name
    }
    else {
        "N/A"
    }

    $GroupCategory = if ($Group.GroupCategory) {
        $Group.GroupCategory
    }
    else {
        "N/A"
    }

    $GroupScope = if ($Group.GroupScope) {
        $Group.GroupScope
    }
    else {
        "N/A"
    }

    $IsPrivileged = $false

    foreach ($Pattern in $PrivilegedGroupPatterns) {
        if ($GroupName -like "*$Pattern*") {
            $IsPrivileged = $true
            break
        }
    }

    $LineColor = if ($IsPrivileged) {
        "Yellow"
    }
    else {
        "Green"
    }

    Write-Host (
        $TableFormat -f `
            $GroupName,
            $GroupCategory,
            $GroupScope
    ) -ForegroundColor $LineColor
}

$PrivilegedGroups = @(
    $Groups | Where-Object {
        $CurrentGroupName = $_.Name
        $MatchesPrivilegedGroup = $false

        foreach ($Pattern in $PrivilegedGroupPatterns) {
            if ($CurrentGroupName -like "*$Pattern*") {
                $MatchesPrivilegedGroup = $true
                break
            }
        }

        $MatchesPrivilegedGroup
    }
)

Write-Host ""
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "=======" -ForegroundColor Cyan
Write-Host ""

Write-Host "Total group memberships: $($Groups.Count)"

if ($PrivilegedGroups.Count -gt 0) {
    Write-Host ""
    Write-Host (
        "Potentially privileged groups: {0}" -f
        $PrivilegedGroups.Count
    ) -ForegroundColor Yellow

    foreach ($PrivilegedGroup in $PrivilegedGroups) {
        Write-Host "  [!] $($PrivilegedGroup.Name)" `
            -ForegroundColor Yellow
    }
}
else {
    Write-Host "No common privileged groups were identified." `
        -ForegroundColor Green
}

Write-Host ""
Write-Host "User distinguished name:" -ForegroundColor DarkGray
Write-Host $User.DistinguishedName -ForegroundColor DarkGray

exit 0