#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Displays detailed information about an Active Directory computer.

.DESCRIPTION
    Displays:

    - Computer name
    - DNS hostname
    - Enabled status
    - Description
    - Location
    - Organizational Unit
    - Operating system and version
    - IPv4 address
    - Last logon
    - Computer password last set
    - Creation and modification dates
    - Managed By
    - Direct group memberships

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

# Request the computer name.
$ComputerInput = Read-Host "Enter the computer name"

if (-not $ComputerInput -or $ComputerInput.Trim().Length -eq 0) {
    Write-Host ""
    Write-Host "Please enter a valid computer name." `
        -ForegroundColor Yellow

    exit 1
}

$ComputerInput = $ComputerInput.Trim()

# Remove the trailing dollar sign if the computer account was
# entered in the COMPUTER$ format.
if ($ComputerInput.EndsWith('$')) {
    $ComputerInput = $ComputerInput.TrimEnd('$')
}

# Retrieve the computer information.
try {
    $Computer = Get-ADComputer `
        -Identity $ComputerInput `
        -Properties DNSHostName,
                    Enabled,
                    Description,
                    Location,
                    OperatingSystem,
                    OperatingSystemVersion,
                    IPv4Address,
                    LastLogonDate,
                    PasswordLastSet,
                    WhenCreated,
                    WhenChanged,
                    ManagedBy,
                    CanonicalName,
                    DistinguishedName `
        -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "Computer '$ComputerInput' was not found in Active Directory." `
        -ForegroundColor Red

    Write-Host "Details: $($_.Exception.Message)" `
        -ForegroundColor DarkRed

    exit 1
}

# Retrieve group memberships.
try {
    $Groups = @(
        Get-ADPrincipalGroupMembership `
            -Identity $Computer.DistinguishedName `
            -ErrorAction Stop |
        Sort-Object Name
    )
}
catch {
    Write-Host ""
    Write-Host "Failed to retrieve computer group memberships." `
        -ForegroundColor Red

    Write-Host "Details: $($_.Exception.Message)" `
        -ForegroundColor DarkRed

    $Groups = @()
}

# Resolve the Managed By value.
$ManagedByName = "N/A"

if ($Computer.ManagedBy) {
    try {
        $ManagerObject = Get-ADObject `
            -Identity $Computer.ManagedBy `
            -Properties DisplayName, Name `
            -ErrorAction Stop

        if ($ManagerObject.DisplayName) {
            $ManagedByName = $ManagerObject.DisplayName
        }
        elseif ($ManagerObject.Name) {
            $ManagedByName = $ManagerObject.Name
        }
    }
    catch {
        $ManagedByName = $Computer.ManagedBy
    }
}

# Determine the Organizational Unit from the distinguished name.
$OrganizationalUnit = "N/A"

if ($Computer.DistinguishedName -match '^CN=[^,]+,(.+)$') {
    $OrganizationalUnit = $Matches[1]
}

# Format optional properties.
if ($Computer.DNSHostName) {
    $DNSHostName = $Computer.DNSHostName
}
else {
    $DNSHostName = "N/A"
}

if ($Computer.Description) {
    $Description = $Computer.Description
}
else {
    $Description = "N/A"
}

if ($Computer.Location) {
    $Location = $Computer.Location
}
else {
    $Location = "N/A"
}

if ($Computer.CanonicalName) {
    $CanonicalName = $Computer.CanonicalName
}
else {
    $CanonicalName = "N/A"
}

if ($Computer.OperatingSystem) {
    $OperatingSystem = $Computer.OperatingSystem
}
else {
    $OperatingSystem = "N/A"
}

if ($Computer.OperatingSystemVersion) {
    $OperatingSystemVersion = $Computer.OperatingSystemVersion
}
else {
    $OperatingSystemVersion = "N/A"
}

if ($Computer.IPv4Address) {
    $IPv4Address = $Computer.IPv4Address
}
else {
    $IPv4Address = "N/A"
}

if ($Computer.LastLogonDate) {
    $LastLogon = $Computer.LastLogonDate.ToString(
        "dd-MM-yyyy HH:mm"
    )
}
else {
    $LastLogon = "N/A"
}

if ($Computer.PasswordLastSet) {
    $PasswordLastSet = $Computer.PasswordLastSet.ToString(
        "dd-MM-yyyy HH:mm"
    )
}
else {
    $PasswordLastSet = "N/A"
}

if ($Computer.WhenCreated) {
    $Created = $Computer.WhenCreated.ToString(
        "dd-MM-yyyy HH:mm"
    )
}
else {
    $Created = "N/A"
}

if ($Computer.WhenChanged) {
    $Modified = $Computer.WhenChanged.ToString(
        "dd-MM-yyyy HH:mm"
    )
}
else {
    $Modified = "N/A"
}

if ($Computer.Enabled) {
    $EnabledText = "Yes"
    $EnabledColor = "Green"
}
else {
    $EnabledText = "No"
    $EnabledColor = "Red"
}

# Display the computer details.
Write-Host ""
Write-Host "Computer Details" -ForegroundColor Cyan
Write-Host "================" -ForegroundColor Cyan
Write-Host ""

Write-Host ("{0,-25}: {1}" -f "Computer name", $Computer.Name)
Write-Host ("{0,-25}: {1}" -f "DNS hostname", $DNSHostName)

Write-Host (
    "{0,-25}: {1}" -f "Enabled in AD", $EnabledText
) -ForegroundColor $EnabledColor

Write-Host ("{0,-25}: {1}" -f "Description", $Description)
Write-Host ("{0,-25}: {1}" -f "Location", $Location)
Write-Host ("{0,-25}: {1}" -f "Managed by", $ManagedByName)

Write-Host ""
Write-Host "Active Directory" -ForegroundColor Cyan
Write-Host "----------------" -ForegroundColor Cyan

Write-Host (
    "{0,-25}: {1}" -f "Canonical name", $CanonicalName
)

Write-Host (
    "{0,-25}: {1}" -f "Organizational Unit", $OrganizationalUnit
)

Write-Host ""
Write-Host "Operating System" -ForegroundColor Cyan
Write-Host "----------------" -ForegroundColor Cyan

Write-Host (
    "{0,-25}: {1}" -f "Operating system", $OperatingSystem
)

Write-Host (
    "{0,-25}: {1}" -f "OS version", $OperatingSystemVersion
)

Write-Host (
    "{0,-25}: {1}" -f "IPv4 address", $IPv4Address
)

Write-Host ""
Write-Host "Activity" -ForegroundColor Cyan
Write-Host "--------" -ForegroundColor Cyan

Write-Host ("{0,-25}: {1}" -f "Last logon", $LastLogon)

Write-Host (
    "{0,-25}: {1}" -f "Password last set", $PasswordLastSet
)

Write-Host ("{0,-25}: {1}" -f "Created", $Created)
Write-Host ("{0,-25}: {1}" -f "Last modified", $Modified)

Write-Host ""
Write-Host "Group Memberships" -ForegroundColor Cyan
Write-Host "=================" -ForegroundColor Cyan
Write-Host ""

if ($Groups.Count -eq 0) {
    Write-Host "No direct group memberships were found." `
        -ForegroundColor Yellow
}
else {
    $TableFormat = "{0,-50} {1,-12} {2,-15}"

    Write-Host (
        $TableFormat -f `
            "Group Name",
            "Category",
            "Scope"
    ) -ForegroundColor Cyan

    Write-Host ("-" * 80) -ForegroundColor DarkGray

    foreach ($Group in $Groups) {
        if ($Group.Name) {
            $GroupName = $Group.Name
        }
        else {
            $GroupName = "N/A"
        }

        if ($Group.GroupCategory) {
            $GroupCategory = $Group.GroupCategory
        }
        else {
            $GroupCategory = "N/A"
        }

        if ($Group.GroupScope) {
            $GroupScope = $Group.GroupScope
        }
        else {
            $GroupScope = "N/A"
        }

        Write-Host (
            $TableFormat -f `
                $GroupName,
                $GroupCategory,
                $GroupScope
        ) -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "=======" -ForegroundColor Cyan
Write-Host ""

Write-Host "Direct group memberships: $($Groups.Count)"

Write-Host ""
Write-Host "Distinguished name:" -ForegroundColor DarkGray
Write-Host $Computer.DistinguishedName -ForegroundColor DarkGray

exit 0
