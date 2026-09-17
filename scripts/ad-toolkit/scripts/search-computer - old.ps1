#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Searches Active Directory for computers.

.DESCRIPTION
    Searches by exact or partial computer name and displays:

    - Computer name
    - Operating system
    - Enabled status
    - Online status
    - Last logon
    - Description
    - IPv4 address

.NOTES
    This script is read-only and does not modify Active Directory.
#>

$ErrorActionPreference = "Stop"

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

$SearchInput = Read-Host "Enter a computer name to search"

if (-not $SearchInput -or $SearchInput.Trim().Length -eq 0) {
    Write-Host ""
    Write-Host "Please enter a valid computer name." `
        -ForegroundColor Yellow

    exit 1
}

$SearchInput = $SearchInput.Trim()
$SafeSearchInput = $SearchInput.Replace("'", "''")

try {
    # Try an exact search first.
    $Computers = @(
        Get-ADComputer `
            -Filter "Name -eq '$SafeSearchInput'" `
            -Properties OperatingSystem,
                        OperatingSystemVersion,
                        LastLogonDate,
                        Enabled,
                        Description,
                        IPv4Address,
                        DNSHostName `
            -ErrorAction Stop
    )

    # If no exact result is found, perform a partial search.
    if ($Computers.Count -eq 0) {
        $Computers = @(
            Get-ADComputer `
                -Filter "Name -like '*$SafeSearchInput*'" `
                -Properties OperatingSystem,
                            OperatingSystemVersion,
                            LastLogonDate,
                            Enabled,
                            Description,
                            IPv4Address,
                            DNSHostName `
                -ErrorAction Stop |
            Sort-Object Name
        )
    }
}
catch {
    Write-Host ""
    Write-Host "An error occurred while searching for computers." `
        -ForegroundColor Red

    Write-Host "Details: $($_.Exception.Message)" `
        -ForegroundColor DarkRed

    exit 1
}

if ($Computers.Count -eq 0) {
    Write-Host ""
    Write-Host "No computers matching '$SearchInput' were found." `
        -ForegroundColor Yellow

    exit 0
}

Write-Host ""
Write-Host "Computer Search Results" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
Write-Host ""

$TableFormat = (
    "{0,-18} {1,-8} {2,-8} {3,-28} " +
    "{4,-18} {5,-16} {6,-35}"
)

Write-Host (
    $TableFormat -f `
        "Computer",
        "Enabled",
        "Online",
        "Operating System",
        "Last Logon",
        "IPv4 Address",
        "Description"
) -ForegroundColor Cyan

Write-Host ("-" * 140) -ForegroundColor DarkGray

foreach ($Computer in $Computers) {
    $ComputerName = $Computer.Name

    $OperatingSystem = if ($Computer.OperatingSystem) {
        $Computer.OperatingSystem
    }
    else {
        "N/A"
    }

    $Description = if ($Computer.Description) {
        $Computer.Description
    }
    else {
        "N/A"
    }

    $IPv4Address = if ($Computer.IPv4Address) {
        $Computer.IPv4Address
    }
    else {
        "N/A"
    }

    $LastLogon = if ($Computer.LastLogonDate) {
        $Computer.LastLogonDate.ToString("dd-MM-yyyy HH:mm")
    }
    else {
        "N/A"
    }

    $EnabledText = if ($Computer.Enabled) {
        "Yes"
    }
    else {
        "No"
    }

    # Test whether the computer responds to ping.
    try {
        $Online = Test-Connection `
            -ComputerName $ComputerName `
            -Count 1 `
            -Quiet `
            -ErrorAction SilentlyContinue
    }
    catch {
        $Online = $false
    }

    $OnlineText = if ($Online) {
        "Yes"
    }
    else {
        "No"
    }

    $LineColor = if (-not $Computer.Enabled) {
        "DarkGray"
    }
    elseif ($Online) {
        "Green"
    }
    else {
        "Yellow"
    }

    Write-Host (
        $TableFormat -f `
            $ComputerName,
            $EnabledText,
            $OnlineText,
            $OperatingSystem,
            $LastLogon,
            $IPv4Address,
            $Description
    ) -ForegroundColor $LineColor
}

Write-Host ""
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "=======" -ForegroundColor Cyan
Write-Host ""

$OnlineComputers = @(
    $Computers | Where-Object {
        Test-Connection `
            -ComputerName $_.Name `
            -Count 1 `
            -Quiet `
            -ErrorAction SilentlyContinue
    }
)

$EnabledComputers = @(
    $Computers | Where-Object { $_.Enabled }
)

Write-Host "Computers found : $($Computers.Count)"
Write-Host "Enabled         : $($EnabledComputers.Count)"
Write-Host "Responding      : $($OnlineComputers.Count)"

Write-Host ""
Write-Host "Green  = Enabled and responding to ping" `
    -ForegroundColor Green

Write-Host "Yellow = Enabled but not responding to ping" `
    -ForegroundColor Yellow

Write-Host "Gray   = Disabled in Active Directory" `
    -ForegroundColor DarkGray

Write-Host ""
Write-Host "Note: A computer may be online even if ping is blocked." `
    -ForegroundColor DarkGray

exit 0