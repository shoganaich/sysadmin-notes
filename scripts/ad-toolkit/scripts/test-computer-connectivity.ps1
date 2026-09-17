#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Tests connectivity to an Active Directory computer.

.DESCRIPTION
    Performs the following read-only checks:

    - Active Directory computer lookup
    - DNS resolution
    - ICMP ping
    - SMB connectivity on TCP port 445
    - RDP connectivity on TCP port 3389
    - WinRM HTTP connectivity on TCP port 5985
    - WinRM HTTPS connectivity on TCP port 5986

.NOTES
    The script only tests whether the ports accept a TCP connection.
    It does not authenticate to any service.
#>

$ErrorActionPreference = "Stop"

# Timeout values in milliseconds.
$PingTimeout = 1000
$PortTimeout = 1000

function Test-TcpPort {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [int]$Port,

        [int]$Timeout = 1000
    )

    $TcpClient = New-Object System.Net.Sockets.TcpClient

    try {
        $Connection = $TcpClient.BeginConnect(
            $ComputerName,
            $Port,
            $null,
            $null
        )

        $ConnectedInTime = $Connection.AsyncWaitHandle.WaitOne(
            $Timeout,
            $false
        )

        if (-not $ConnectedInTime) {
            return $false
        }

        $TcpClient.EndConnect($Connection)
        return $TcpClient.Connected
    }
    catch {
        return $false
    }
    finally {
        $TcpClient.Close()
        $TcpClient.Dispose()
    }
}

function Write-TestResult {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Test,

        [Parameter(Mandatory = $true)]
        [string]$Result,

        [Parameter(Mandatory = $true)]
        [string]$Color
    )

    Write-Host (
        "{0,-23}: {1}" -f $Test, $Result
    ) -ForegroundColor $Color
}

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

Write-Host ""
Write-Host "Computer Connectivity Test" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

# Look up the computer in Active Directory.
try {
    $ADComputer = Get-ADComputer `
        -Identity $ComputerInput `
        -Properties DNSHostName,
                    Enabled,
                    OperatingSystem,
                    Description,
                    LastLogonDate,
                    IPv4Address `
        -ErrorAction Stop

    Write-TestResult `
        -Test "Active Directory" `
        -Result "Computer found" `
        -Color "Green"
}
catch {
    Write-TestResult `
        -Test "Active Directory" `
        -Result "Computer not found" `
        -Color "Red"

    Write-Host ""
    Write-Host "Details: $($_.Exception.Message)" `
        -ForegroundColor DarkRed

    exit 1
}

# Prefer the fully qualified DNS hostname when available.
if ($ADComputer.DNSHostName) {
    $Target = $ADComputer.DNSHostName
}
else {
    $Target = $ADComputer.Name
}

if ($ADComputer.Enabled) {
    $EnabledText = "Yes"
    $EnabledColor = "Green"
}
else {
    $EnabledText = "No"
    $EnabledColor = "Red"
}

if ($ADComputer.OperatingSystem) {
    $OperatingSystem = $ADComputer.OperatingSystem
}
else {
    $OperatingSystem = "N/A"
}

if ($ADComputer.Description) {
    $Description = $ADComputer.Description
}
else {
    $Description = "N/A"
}

if ($ADComputer.LastLogonDate) {
    $LastLogon = $ADComputer.LastLogonDate.ToString(
        "dd-MM-yyyy HH:mm"
    )
}
else {
    $LastLogon = "N/A"
}

Write-Host ""
Write-Host "Computer Information" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host ""

Write-Host ("{0,-23}: {1}" -f "Computer", $ADComputer.Name)
Write-Host ("{0,-23}: {1}" -f "DNS hostname", $Target)

Write-Host (
    "{0,-23}: {1}" -f "Enabled in AD", $EnabledText
) -ForegroundColor $EnabledColor

Write-Host ("{0,-23}: {1}" -f "Operating system", $OperatingSystem)
Write-Host ("{0,-23}: {1}" -f "Last logon", $LastLogon)
Write-Host ("{0,-23}: {1}" -f "Description", $Description)

Write-Host ""
Write-Host "Connectivity Results" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host ""

# DNS resolution.
$ResolvedAddresses = @()

try {
    $HostEntry = [System.Net.Dns]::GetHostEntry($Target)

    $ResolvedAddresses = @(
        $HostEntry.AddressList |
        Where-Object {
            $_.AddressFamily -eq "InterNetwork"
        } |
        ForEach-Object {
            $_.IPAddressToString
        } |
        Select-Object -Unique
    )

    if ($ResolvedAddresses.Count -gt 0) {
        $IPAddressText = $ResolvedAddresses -join ", "

        Write-TestResult `
            -Test "DNS resolution" `
            -Result "Successful" `
            -Color "Green"

        Write-TestResult `
            -Test "IPv4 address" `
            -Result $IPAddressText `
            -Color "Green"
    }
    else {
        Write-TestResult `
            -Test "DNS resolution" `
            -Result "No IPv4 address returned" `
            -Color "Yellow"
    }
}
catch {
    Write-TestResult `
        -Test "DNS resolution" `
        -Result "Failed" `
        -Color "Red"
}

# Ping test.
$PingSuccessful = $false
$PingTime = $null

$Ping = New-Object System.Net.NetworkInformation.Ping

try {
    $PingReply = $Ping.Send(
        $Target,
        $PingTimeout
    )

    if ($PingReply.Status -eq "Success") {
        $PingSuccessful = $true
        $PingTime = $PingReply.RoundtripTime

        Write-TestResult `
            -Test "Ping" `
            -Result "Successful ($PingTime ms)" `
            -Color "Green"
    }
    else {
        Write-TestResult `
            -Test "Ping" `
            -Result "No response ($($PingReply.Status))" `
            -Color "Yellow"
    }
}
catch {
    Write-TestResult `
        -Test "Ping" `
        -Result "Failed" `
        -Color "Yellow"
}
finally {
    $Ping.Dispose()
}

# Define the TCP services to test.
$PortTests = @(
    [PSCustomObject]@{
        Name = "SMB"
        Port = 445
    },
    [PSCustomObject]@{
        Name = "RDP"
        Port = 3389
    },
    [PSCustomObject]@{
        Name = "WinRM HTTP"
        Port = 5985
    },
    [PSCustomObject]@{
        Name = "WinRM HTTPS"
        Port = 5986
    }
)

$OpenPortCount = 0
$ClosedPortCount = 0

foreach ($PortTest in $PortTests) {
    $IsOpen = Test-TcpPort `
        -ComputerName $Target `
        -Port $PortTest.Port `
        -Timeout $PortTimeout

    $TestLabel = "{0} TCP/{1}" -f `
        $PortTest.Name,
        $PortTest.Port

    if ($IsOpen) {
        $OpenPortCount++

        Write-TestResult `
            -Test $TestLabel `
            -Result "Open" `
            -Color "Green"
    }
    else {
        $ClosedPortCount++

        Write-TestResult `
            -Test $TestLabel `
            -Result "Closed or unreachable" `
            -Color "Yellow"
    }
}

Write-Host ""
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "=======" -ForegroundColor Cyan
Write-Host ""

if ($PingSuccessful) {
    Write-Host "The computer responded to ping." `
        -ForegroundColor Green
}
elseif ($OpenPortCount -gt 0) {
    Write-Host (
        "The computer did not respond to ping, but at least one TCP service is reachable."
    ) -ForegroundColor Yellow
}
else {
    Write-Host (
        "The computer did not respond to ping and no tested TCP services were reachable."
    ) -ForegroundColor Yellow
}

exit 0