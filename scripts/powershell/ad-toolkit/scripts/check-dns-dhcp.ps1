#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Checks Active Directory, DNS, and DHCP information for a computer.

.DESCRIPTION
    Performs read-only checks for a selected Active Directory computer:

    - Validates the computer object in Active Directory
    - Resolves forward DNS A records
    - Checks reverse DNS PTR records
    - Discovers authorized Windows DHCP servers
    - Searches active IPv4 leases by hostname and DNS address
    - Displays lease, scope, client ID, and expiration information
    - Identifies missing, duplicate, and mismatched records

.NOTES
    Requires:
    - Windows PowerShell 5.1
    - ActiveDirectory module
    - DhcpServer module
    - Permission to query the DHCP servers

    This script does not modify Active Directory, DNS, or DHCP.
#>

$ErrorActionPreference = "Stop"

function Format-DateValue {
    param($Value)

    if ($null -eq $Value) {
        return "N/A"
    }

    try {
        return ([datetime]$Value).ToString("dd-MM-yyyy HH:mm:ss")
    }
    catch {
        return [string]$Value
    }
}

function Normalize-HostName {
    param([string]$Name)

    if (-not $Name) {
        return ""
    }

    return ($Name.Trim().TrimEnd('.').Split('.')[0]).ToUpperInvariant()
}

function Get-IPv4Text {
    param($Address)

    if ($null -eq $Address) {
        return $null
    }

    try {
        return ([System.Net.IPAddress]$Address).ToString()
    }
    catch {
        return [string]$Address
    }
}

function Get-ReverseDnsName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress
    )

    try {
        $Result = Resolve-DnsName `
            -Name $IPAddress `
            -Type PTR `
            -DnsOnly `
            -ErrorAction Stop |
            Where-Object { $_.NameHost } |
            Select-Object -First 1

        if ($Result.NameHost) {
            return $Result.NameHost.TrimEnd('.')
        }
    }
    catch {
        return $null
    }

    return $null
}

# Import required modules.
try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "Failed to import the Active Directory module." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    exit 1
}

try {
    Import-Module DhcpServer -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "Failed to import the DHCP Server module." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "Install the DHCP management RSAT tools or run this script" -ForegroundColor Yellow
    Write-Host "from an approved management workstation." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Check DNS and DHCP Records" -ForegroundColor Cyan
Write-Host "=========================="
Write-Host ""

$ComputerInput = Read-Host "Enter the computer name"

if (-not $ComputerInput -or $ComputerInput.Trim().Length -eq 0) {
    Write-Host ""
    Write-Host "Please enter a valid computer name." -ForegroundColor Yellow
    exit 1
}

$ComputerInput = $ComputerInput.Trim()

if ($ComputerInput.EndsWith('$')) {
    $ComputerInput = $ComputerInput.TrimEnd('$')
}

# Retrieve the computer object.
try {
    $Computer = Get-ADComputer `
        -Identity $ComputerInput `
        -Properties DNSHostName, Enabled, OperatingSystem, Description, IPv4Address `
        -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "Computer '$ComputerInput' was not found in Active Directory." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    exit 1
}

$ShortName = $Computer.Name
$NormalizedComputerName = Normalize-HostName -Name $ShortName
$DNSHostName = if ($Computer.DNSHostName) { $Computer.DNSHostName } else { $ShortName }
$ADIPv4 = if ($Computer.IPv4Address) { [string]$Computer.IPv4Address } else { "N/A" }
$OperatingSystem = if ($Computer.OperatingSystem) { $Computer.OperatingSystem } else { "N/A" }
$Description = if ($Computer.Description) { $Computer.Description } else { "N/A" }
$EnabledText = if ($Computer.Enabled) { "Yes" } else { "No" }

Write-Host ""
Write-Host "Computer Information" -ForegroundColor Cyan
Write-Host "===================="
Write-Host ""
Write-Host ("{0,-22}: {1}" -f "Computer", $ShortName)
Write-Host ("{0,-22}: {1}" -f "DNS hostname", $DNSHostName)
Write-Host ("{0,-22}: {1}" -f "Enabled in AD", $EnabledText) `
    -ForegroundColor $(if ($Computer.Enabled) { "Green" } else { "Red" })
Write-Host ("{0,-22}: {1}" -f "AD IPv4", $ADIPv4)
Write-Host ("{0,-22}: {1}" -f "Operating system", $OperatingSystem)
Write-Host ("{0,-22}: {1}" -f "Description", $Description)

# Forward DNS lookup.
$DnsAddresses = @()

try {
    $DnsAddresses = @(
        Resolve-DnsName `
            -Name $DNSHostName `
            -Type A `
            -DnsOnly `
            -ErrorAction Stop |
        Where-Object { $_.IPAddress } |
        ForEach-Object { [string]$_.IPAddress } |
        Sort-Object -Unique
    )
}
catch {
    $DnsAddresses = @()
}

Write-Host ""
Write-Host "Forward DNS Records" -ForegroundColor Cyan
Write-Host "==================="
Write-Host ""

if ($DnsAddresses.Count -eq 0) {
    Write-Host "No IPv4 A records were found." -ForegroundColor Red
}
else {
    for ($Index = 0; $Index -lt $DnsAddresses.Count; $Index++) {
        $AddressNumber = $Index + 1
        Write-Host ("{0,-22}: {1}" -f "A record $AddressNumber", $DnsAddresses[$Index]) `
            -ForegroundColor $(if ($DnsAddresses.Count -gt 1) { "Yellow" } else { "Green" })
    }
}

# Reverse DNS checks for all forward addresses.
$ReverseResults = @()

foreach ($Address in $DnsAddresses) {
    $PtrName = Get-ReverseDnsName -IPAddress $Address

    $ReverseResults += [PSCustomObject]@{
        IPAddress = $Address
        PTRName   = if ($PtrName) { $PtrName } else { "N/A" }
        Matches   = if ($PtrName) {
            (Normalize-HostName -Name $PtrName) -eq $NormalizedComputerName
        }
        else {
            $false
        }
    }
}

Write-Host ""
Write-Host "Reverse DNS Records" -ForegroundColor Cyan
Write-Host "==================="
Write-Host ""

if ($ReverseResults.Count -eq 0) {
    Write-Host "No addresses were available for reverse lookup." -ForegroundColor Yellow
}
else {
    foreach ($Result in $ReverseResults) {
        $MatchText = if ($Result.Matches) { "Match" } else { "Mismatch or missing" }
        $Color = if ($Result.Matches) { "Green" } else { "Yellow" }

        Write-Host ("{0,-22}: {1}" -f "IPv4 address", $Result.IPAddress)
        Write-Host ("{0,-22}: {1}" -f "PTR record", $Result.PTRName)
        Write-Host ("{0,-22}: {1}" -f "PTR validation", $MatchText) -ForegroundColor $Color
        Write-Host ""
    }
}

# Discover authorized DHCP servers.
try {
    $DhcpServers = @(Get-DhcpServerInDC -ErrorAction Stop | Sort-Object DnsName)
}
catch {
    Write-Host ""
    Write-Host "Unable to discover authorized DHCP servers." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    exit 1
}

Write-Host "DHCP Search" -ForegroundColor Cyan
Write-Host "==========="
Write-Host ""
Write-Host ("{0,-22}: {1}" -f "Authorized servers", $DhcpServers.Count)
Write-Host "Searching active leases. This can take some time..." -ForegroundColor DarkGray
Write-Host ""

$LeaseResults = New-Object System.Collections.ArrayList
$DhcpErrors = New-Object System.Collections.ArrayList

foreach ($DhcpServer in $DhcpServers) {
    $ServerName = if ($DhcpServer.DnsName) { $DhcpServer.DnsName } else { [string]$DhcpServer }

    Write-Progress `
        -Activity "Searching DHCP leases" `
        -Status "Server: $ServerName" `
        -PercentComplete 0

    try {
        $Scopes = @(Get-DhcpServerv4Scope -ComputerName $ServerName -ErrorAction Stop)
    }
    catch {
        $null = $DhcpErrors.Add([PSCustomObject]@{
            Server = $ServerName
            Error  = $_.Exception.Message
        })
        continue
    }

    for ($ScopeIndex = 0; $ScopeIndex -lt $Scopes.Count; $ScopeIndex++) {
        $Scope = $Scopes[$ScopeIndex]
        $Percent = if ($Scopes.Count -gt 0) {
            [int](($ScopeIndex + 1) / $Scopes.Count * 100)
        }
        else {
            100
        }

        Write-Progress `
            -Activity "Searching DHCP leases" `
            -Status "$ServerName - Scope $($Scope.ScopeId)" `
            -PercentComplete $Percent

        try {
            $Leases = @(
                Get-DhcpServerv4Lease `
                    -ComputerName $ServerName `
                    -ScopeId $Scope.ScopeId `
                    -ErrorAction Stop
            )
        }
        catch {
            continue
        }

        foreach ($Lease in $Leases) {
            $LeaseIP = Get-IPv4Text -Address $Lease.IPAddress
            $LeaseHostName = [string]$Lease.HostName
            $NormalizedLeaseName = Normalize-HostName -Name $LeaseHostName

            $NameMatches = $NormalizedLeaseName -eq $NormalizedComputerName
            $AddressMatches = $DnsAddresses -contains $LeaseIP

            if ($NameMatches -or $AddressMatches) {
                $Existing = $LeaseResults | Where-Object {
                    $_.Server -eq $ServerName -and
                    $_.ScopeId -eq [string]$Scope.ScopeId -and
                    $_.IPAddress -eq $LeaseIP -and
                    $_.ClientId -eq [string]$Lease.ClientId
                }

                if (-not $Existing) {
                    $null = $LeaseResults.Add([PSCustomObject]@{
                        Server         = $ServerName
                        ScopeId        = [string]$Scope.ScopeId
                        IPAddress      = $LeaseIP
                        HostName       = $LeaseHostName
                        ClientId       = [string]$Lease.ClientId
                        AddressState   = [string]$Lease.AddressState
                        LeaseExpiry    = $Lease.LeaseExpiryTime
                        NameMatches    = $NameMatches
                        AddressMatches = $AddressMatches
                    })
                }
            }
        }
    }
}

Write-Progress -Activity "Searching DHCP leases" -Completed

Write-Host "DHCP Lease Results" -ForegroundColor Cyan
Write-Host "=================="
Write-Host ""

if ($LeaseResults.Count -eq 0) {
    Write-Host "No active DHCP lease matched the computer name or DNS addresses." `
        -ForegroundColor Yellow
}
else {
    foreach ($Lease in $LeaseResults | Sort-Object Server, ScopeId, IPAddress) {
        $Expiry = Format-DateValue -Value $Lease.LeaseExpiry
        $MatchReason = @()

        if ($Lease.NameMatches) {
            $MatchReason += "Hostname"
        }

        if ($Lease.AddressMatches) {
            $MatchReason += "DNS address"
        }

        Write-Host ("{0,-22}: {1}" -f "DHCP server", $Lease.Server)
        Write-Host ("{0,-22}: {1}" -f "Scope", $Lease.ScopeId)
        Write-Host ("{0,-22}: {1}" -f "Lease address", $Lease.IPAddress)
        Write-Host ("{0,-22}: {1}" -f "Lease hostname", $(if ($Lease.HostName) { $Lease.HostName } else { "N/A" }))
        Write-Host ("{0,-22}: {1}" -f "Client ID / MAC", $(if ($Lease.ClientId) { $Lease.ClientId } else { "N/A" }))
        Write-Host ("{0,-22}: {1}" -f "Address state", $Lease.AddressState)
        Write-Host ("{0,-22}: {1}" -f "Lease expiration", $Expiry)
        Write-Host ("{0,-22}: {1}" -f "Matched by", ($MatchReason -join ", "))
        Write-Host ""
    }
}

# Validation summary.
$Problems = New-Object System.Collections.ArrayList

if ($DnsAddresses.Count -eq 0) {
    $null = $Problems.Add("No forward DNS A record was found.")
}

if ($DnsAddresses.Count -gt 1) {
    $null = $Problems.Add("Multiple forward DNS A records were found.")
}

foreach ($ReverseResult in $ReverseResults) {
    if (-not $ReverseResult.Matches) {
        $null = $Problems.Add("PTR record is missing or does not match for $($ReverseResult.IPAddress).")
    }
}

if ($LeaseResults.Count -eq 0) {
    $null = $Problems.Add("No matching active DHCP lease was found.")
}

$LeaseAddresses = @($LeaseResults | ForEach-Object { $_.IPAddress } | Sort-Object -Unique)

foreach ($DnsAddress in $DnsAddresses) {
    if ($LeaseAddresses -notcontains $DnsAddress) {
        $null = $Problems.Add("DNS address $DnsAddress has no matching active DHCP lease.")
    }
}

foreach ($LeaseAddress in $LeaseAddresses) {
    if ($DnsAddresses -notcontains $LeaseAddress) {
        $null = $Problems.Add("DHCP lease $LeaseAddress is not present in forward DNS.")
    }
}

if ($ADIPv4 -ne "N/A" -and $DnsAddresses.Count -gt 0 -and $DnsAddresses -notcontains $ADIPv4) {
    $null = $Problems.Add("The AD IPv4 value does not match any forward DNS address.")
}

Write-Host "Validation Summary" -ForegroundColor Cyan
Write-Host "=================="
Write-Host ""

Write-Host ("{0,-28}: {1}" -f "Forward DNS addresses", $DnsAddresses.Count)
Write-Host ("{0,-28}: {1}" -f "Matching DHCP leases", $LeaseResults.Count)
Write-Host ("{0,-28}: {1}" -f "DHCP servers with errors", $DhcpErrors.Count)

if ($Problems.Count -eq 0) {
    Write-Host ("{0,-28}: {1}" -f "Overall status", "Healthy") -ForegroundColor Green
    Write-Host ""
    Write-Host "No obvious DNS or DHCP mismatch was detected." -ForegroundColor Green
}
else {
    Write-Host ("{0,-28}: {1}" -f "Overall status", "Review required") -ForegroundColor Yellow
    Write-Host ""

    foreach ($Problem in $Problems | Sort-Object -Unique) {
        Write-Host "[WARNING] $Problem" -ForegroundColor Yellow
    }
}

if ($DhcpErrors.Count -gt 0) {
    Write-Host ""
    Write-Host "DHCP Query Errors" -ForegroundColor Cyan
    Write-Host "================="
    Write-Host ""

    foreach ($DhcpError in $DhcpErrors) {
        Write-Host ("{0,-22}: {1}" -f "DHCP server", $DhcpError.Server)
        Write-Host ("{0,-22}: {1}" -f "Error", $DhcpError.Error) -ForegroundColor DarkYellow
        Write-Host ""
    }
}

exit 0
