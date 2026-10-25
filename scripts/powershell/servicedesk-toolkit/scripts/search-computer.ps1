#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Searches Active Directory for computers.

.DESCRIPTION
    Searches by exact or partial computer name.

    The operator can choose between:
    - A fast Active Directory-only search
    - An Active Directory search with ping testing

.NOTES
    This script is read-only.
#>

$ErrorActionPreference = "Stop"

# Ping timeout in milliseconds.
$PingTimeout = 300

# Import the Active Directory module.
try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "Failed to import the Active Directory module." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    exit 1
}

# Request the computer name.
$SearchInput = Read-Host "Enter a computer name to search"

if (-not $SearchInput -or $SearchInput.Trim().Length -eq 0) {
    Write-Host ""
    Write-Host "Please enter a valid computer name." -ForegroundColor Yellow
    exit 1
}

$SearchInput = $SearchInput.Trim()

# Ask whether ping testing should be enabled.
Write-Host ""
$PingChoice = Read-Host "Test ping connectivity? (Y/N)"

if ($PingChoice -and $PingChoice.Trim().ToUpper() -in @("Y", "YES")) {
    $TestPing = $true
}
elseif ($PingChoice -and $PingChoice.Trim().ToUpper() -in @("N", "NO")) {
    $TestPing = $false
}
else {
    Write-Host ""
    Write-Host "Invalid selection. Ping testing will be disabled." -ForegroundColor Yellow
    $TestPing = $false
}

# Escape apostrophes before using the input in an AD filter.
$SafeSearchInput = $SearchInput.Replace("'", "''")

try {
    # Search for an exact computer name first.
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

    # If there is no exact result, perform a partial search.
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
    Write-Host "An error occurred while searching for computers." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    exit 1
}

if ($Computers.Count -eq 0) {
    Write-Host ""
    Write-Host "No computers matching '$SearchInput' were found." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Computer Search Results" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
Write-Host ""

$EnabledCount = 0
$DisabledCount = 0

if ($TestPing) {
    # ============================================================
    # ACTIVE DIRECTORY SEARCH WITH PING
    # ============================================================

    Write-Host "Mode: Active Directory search with ping" -ForegroundColor Cyan
    Write-Host ""

    $OnlineCount = 0
    $OfflineCount = 0

    $TableFormat = "{0,-18} {1,-8} {2,-8} {3,-10} {4,-28} {5,-18} {6,-16} {7,-35}"

    Write-Host (
        $TableFormat -f
        "Computer",
        "Enabled",
        "Online",
        "Ping",
        "Operating System",
        "Last Logon",
        "IPv4 Address",
        "Description"
    ) -ForegroundColor Cyan

    Write-Host ("-" * 150) -ForegroundColor DarkGray

    $Ping = New-Object System.Net.NetworkInformation.Ping

    try {
        foreach ($Computer in $Computers) {
            if ($Computer.Enabled) {
                $EnabledCount++
            }
            else {
                $DisabledCount++
            }

            $PingReply = $null
            $Online = $false
            $PingTime = "N/A"

            try {
                $PingReply = $Ping.Send($Computer.Name, $PingTimeout)
                $Online = $PingReply.Status -eq "Success"

                if ($Online) {
                    $PingTime = "$($PingReply.RoundtripTime) ms"
                    $OnlineCount++
                }
                else {
                    $OfflineCount++
                }
            }
            catch {
                $Online = $false
                $OfflineCount++
            }

            if ($Computer.OperatingSystem) {
                $OperatingSystem = $Computer.OperatingSystem
            }
            else {
                $OperatingSystem = "N/A"
            }

            if ($Computer.Description) {
                $Description = $Computer.Description
            }
            else {
                $Description = "N/A"
            }

            if ($Computer.LastLogonDate) {
                $LastLogon = $Computer.LastLogonDate.ToString("dd-MM-yyyy HH:mm")
            }
            else {
                $LastLogon = "N/A"
            }

            if ($Online -and $PingReply -and $PingReply.Address) {
                $IPv4Address = $PingReply.Address.ToString()
            }
            elseif ($Computer.IPv4Address) {
                $IPv4Address = $Computer.IPv4Address
            }
            else {
                $IPv4Address = "N/A"
            }

            if ($Computer.Enabled) {
                $EnabledText = "Yes"
            }
            else {
                $EnabledText = "No"
            }

            if ($Online) {
                $OnlineText = "Yes"
            }
            else {
                $OnlineText = "No"
            }

            if (-not $Computer.Enabled) {
                $LineColor = "DarkGray"
            }
            elseif ($Online) {
                $LineColor = "Green"
            }
            else {
                $LineColor = "Yellow"
            }

            Write-Host (
                $TableFormat -f
                $Computer.Name,
                $EnabledText,
                $OnlineText,
                $PingTime,
                $OperatingSystem,
                $LastLogon,
                $IPv4Address,
                $Description
            ) -ForegroundColor $LineColor
        }
    }
    finally {
        $Ping.Dispose()
    }

    Write-Host ""
    Write-Host "Summary" -ForegroundColor Cyan
    Write-Host "=======" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Computers found : $($Computers.Count)"
    Write-Host "Enabled         : $EnabledCount"
    Write-Host "Disabled        : $DisabledCount"
    Write-Host "Responding      : $OnlineCount" -ForegroundColor Green
    Write-Host "Not responding  : $OfflineCount" -ForegroundColor Yellow

    Write-Host ""
    Write-Host "Green  = Enabled and responding to ping" -ForegroundColor Green
    Write-Host "Yellow = Enabled but not responding to ping" -ForegroundColor Yellow
    Write-Host "Gray   = Disabled in Active Directory" -ForegroundColor DarkGray

    Write-Host ""
    Write-Host "A computer may be online even if ping is blocked." -ForegroundColor DarkGray
}
else {
    # ============================================================
    # ACTIVE DIRECTORY SEARCH WITHOUT PING
    # ============================================================

    Write-Host "Mode: Active Directory search only" -ForegroundColor Cyan
    Write-Host ""

    $TableFormat = "{0,-18} {1,-8} {2,-28} {3,-18} {4,-16} {5,-35}"

    Write-Host (
        $TableFormat -f
        "Computer",
        "Enabled",
        "Operating System",
        "Last Logon",
        "IPv4 Address",
        "Description"
    ) -ForegroundColor Cyan

    Write-Host ("-" * 130) -ForegroundColor DarkGray

    foreach ($Computer in $Computers) {
        if ($Computer.Enabled) {
            $EnabledCount++
            $EnabledText = "Yes"
            $LineColor = "Green"
        }
        else {
            $DisabledCount++
            $EnabledText = "No"
            $LineColor = "DarkGray"
        }

        if ($Computer.OperatingSystem) {
            $OperatingSystem = $Computer.OperatingSystem
        }
        else {
            $OperatingSystem = "N/A"
        }

        if ($Computer.Description) {
            $Description = $Computer.Description
        }
        else {
            $Description = "N/A"
        }

        if ($Computer.IPv4Address) {
            $IPv4Address = $Computer.IPv4Address
        }
        else {
            $IPv4Address = "N/A"
        }

        if ($Computer.LastLogonDate) {
            $LastLogon = $Computer.LastLogonDate.ToString("dd-MM-yyyy HH:mm")
        }
        else {
            $LastLogon = "N/A"
        }

        Write-Host (
            $TableFormat -f
            $Computer.Name,
            $EnabledText,
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

    Write-Host "Computers found : $($Computers.Count)"
    Write-Host "Enabled         : $EnabledCount"
    Write-Host "Disabled        : $DisabledCount"

    Write-Host ""
    Write-Host "Ping testing was not performed." -ForegroundColor DarkGray
}

exit 0