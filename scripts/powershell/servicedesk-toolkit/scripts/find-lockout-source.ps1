#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Finds which device is locking out an Active Directory account.

.DESCRIPTION
    Reads account lockout events (Event ID 4740) from the Security log on the
    domain controller that holds the PDC emulator role. Each event records the
    "caller computer": the device that sent the bad password.

    If nothing is found on the PDC emulator, the technician can search every
    domain controller.

.NOTES
    Requires:
    - ActiveDirectory module
    - Permission to read the Security log on the domain controllers
      (for example membership of "Event Log Readers")
    - "Audit User Account Management" enabled on the domain controllers

    This script is read-only.
#>

$ErrorActionPreference = "Stop"

$DefaultHours = 24

function Get-LockoutEvents {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server,

        [Parameter(Mandatory = $true)]
        [string]$SamAccountName,

        [Parameter(Mandatory = $true)]
        [int]$Hours
    )

    $Milliseconds = [int64]$Hours * 3600 * 1000

    # Filter on the server side: only 4740 events for this user in the time window.
    $XPath = "*[System[(EventID=4740) and TimeCreated[timediff(@SystemTime) <= $Milliseconds]]" +
             " and EventData[Data[@Name='TargetUserName']='$SamAccountName']]"

    try {
        $Events = @(
            Get-WinEvent `
                -ComputerName $Server `
                -LogName Security `
                -FilterXPath $XPath `
                -ErrorAction Stop
        )
    }
    catch {
        if ($_.Exception.Message -match "No events were found") {
            return [PSCustomObject]@{ Server = $Server; Events = @(); Error = $null }
        }

        return [PSCustomObject]@{ Server = $Server; Events = @(); Error = $_.Exception.Message }
    }

    $Results = foreach ($EventRecord in $Events) {
        # Event 4740 data: [0] TargetUserName, [1] caller computer name.
        $Caller = [string]$EventRecord.Properties[1].Value

        [PSCustomObject]@{
            Time             = $EventRecord.TimeCreated
            DomainController = $Server
            CallerComputer   = if ([string]::IsNullOrWhiteSpace($Caller)) { "(blank)" } else { $Caller.Trim('\') }
        }
    }

    return [PSCustomObject]@{ Server = $Server; Events = @($Results); Error = $null }
}

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

Write-Host ""
Write-Host "Find Lockout Source" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host ""

$Username = Read-Host "Enter the username"

if ([string]::IsNullOrWhiteSpace($Username)) {
    Write-Host ""
    Write-Host "Please enter a valid username." -ForegroundColor Yellow
    exit 1
}

$Username = $Username.Trim()

# Find the PDC emulator. Lockouts are always forwarded to it, so it has the
# most current lockout state and the lockout events.
try {
    $PDC = (Get-ADDomain -ErrorAction Stop).PDCEmulator
}
catch {
    Write-Host ""
    Write-Host "Unable to find the PDC emulator." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    exit 1
}

# Retrieve the user from the PDC emulator.
try {
    $User = Get-ADUser `
        -Identity $Username `
        -Server $PDC `
        -Properties DisplayName, LockedOut, LockoutTime, BadLogonCount, LastBadPasswordAttempt `
        -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "User '$Username' was not found in Active Directory." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    exit 1
}

# XPath uses single quotes, so a quote in the name would break the query.
if ($User.SamAccountName -match "'") {
    Write-Host ""
    Write-Host "This username contains a quote character and can't be searched with this tool." -ForegroundColor Yellow
    exit 1
}

$HoursInput = Read-Host "How many hours back should be searched? [$DefaultHours]"

if ([string]::IsNullOrWhiteSpace($HoursInput)) {
    $Hours = $DefaultHours
}
elseif ($HoursInput.Trim() -match '^\d+$' -and [int]$HoursInput.Trim() -gt 0) {
    $Hours = [int]$HoursInput.Trim()
}
else {
    Write-Host ""
    Write-Host "Invalid number of hours. Using $DefaultHours." -ForegroundColor Yellow
    $Hours = $DefaultHours
}

# Show the current account state.
$DisplayName = if ($User.DisplayName) { $User.DisplayName } else { "N/A" }

$LockoutTimeText = "N/A"
if ($User.LockoutTime -and [int64]$User.LockoutTime -gt 0) {
    try {
        $LockoutTimeText = [DateTime]::FromFileTime([int64]$User.LockoutTime).ToString("dd-MM-yyyy HH:mm:ss")
    }
    catch {
        $LockoutTimeText = "N/A"
    }
}

$LastBadPassword = if ($User.LastBadPasswordAttempt) {
    $User.LastBadPasswordAttempt.ToString("dd-MM-yyyy HH:mm:ss")
}
else {
    "N/A"
}

Write-Host ""
Write-Host "Account" -ForegroundColor Cyan
Write-Host "-------" -ForegroundColor Cyan
Write-Host ("{0,-24}: {1}" -f "Display name", $DisplayName)
Write-Host ("{0,-24}: {1}" -f "Username", $User.SamAccountName)

if ($User.LockedOut) {
    Write-Host ("{0,-24}: {1}" -f "Currently locked", "Yes") -ForegroundColor Red
}
else {
    Write-Host ("{0,-24}: {1}" -f "Currently locked", "No") -ForegroundColor Green
}

Write-Host ("{0,-24}: {1}" -f "Locked out at", $LockoutTimeText)
Write-Host ("{0,-24}: {1}" -f "Last bad password", $LastBadPassword)
Write-Host ("{0,-24}: {1}" -f "Bad password count", $User.BadLogonCount)

Write-Host ""
Write-Host "Searching lockout events on $PDC (last $Hours hours)..." -ForegroundColor DarkGray

$SearchResults = @(Get-LockoutEvents -Server $PDC -SamAccountName $User.SamAccountName -Hours $Hours)
$AllEvents = @($SearchResults | ForEach-Object { $_.Events })

# Offer a wider search if the PDC emulator returned nothing.
if ($AllEvents.Count -eq 0) {
    if ($SearchResults[0].Error) {
        Write-Host ""
        Write-Host "Unable to read the Security log on $PDC." -ForegroundColor Red
        Write-Host "Details: $($SearchResults[0].Error)" -ForegroundColor DarkRed
    }
    else {
        Write-Host ""
        Write-Host "No lockout events were found on the PDC emulator." -ForegroundColor Yellow
    }

    Write-Host ""
    $SearchAll = Read-Host "Search all domain controllers? This can be slow. (Y/N)"

    if ($SearchAll -and $SearchAll.Trim().ToUpper() -in @("Y", "YES")) {
        try {
            $DomainControllers = @(
                Get-ADDomainController -Filter * -ErrorAction Stop |
                    ForEach-Object { $_.HostName } |
                    Where-Object { $_ -ne $PDC } |
                    Sort-Object
            )
        }
        catch {
            Write-Host ""
            Write-Host "Unable to list the domain controllers." -ForegroundColor Red
            Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
            exit 1
        }

        foreach ($DC in $DomainControllers) {
            Write-Host "Searching $DC..." -ForegroundColor DarkGray
            $SearchResults += Get-LockoutEvents -Server $DC -SamAccountName $User.SamAccountName -Hours $Hours
        }

        $AllEvents = @($SearchResults | ForEach-Object { $_.Events })
    }
}

# Report unreadable domain controllers.
$FailedServers = @($SearchResults | Where-Object { $_.Error })

if ($FailedServers.Count -gt 0) {
    Write-Host ""
    Write-Host "Domain controllers that could not be read" -ForegroundColor Yellow
    Write-Host "-----------------------------------------" -ForegroundColor Yellow

    foreach ($Failed in $FailedServers) {
        Write-Host ("{0,-30}: {1}" -f $Failed.Server, $Failed.Error) -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "Reading the Security log usually requires membership of 'Event Log Readers'" -ForegroundColor DarkGray
    Write-Host "on the domain controllers." -ForegroundColor DarkGray
}

if ($AllEvents.Count -eq 0) {
    Write-Host ""
    Write-Host "No lockout events were found for '$($User.SamAccountName)' in the last $Hours hours." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Possible reasons:" -ForegroundColor DarkGray
    Write-Host "- The account was not locked out in that period." -ForegroundColor DarkGray
    Write-Host "- The Security log has already been overwritten (busy DCs may only keep a few hours)." -ForegroundColor DarkGray
    Write-Host "- Account lockout auditing is not enabled on the domain controllers." -ForegroundColor DarkGray
    exit 0
}

# Summary by source device.
$BySource = @(
    $AllEvents |
        Group-Object -Property CallerComputer |
        Sort-Object -Property Count -Descending
)

Write-Host ""
Write-Host "Lockout Sources" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan
Write-Host ""

$SourceFormat = "{0,-30} {1,-9} {2,-20}"
Write-Host ($SourceFormat -f "Caller computer", "Lockouts", "Most recent") -ForegroundColor Cyan
Write-Host ("-" * 62) -ForegroundColor DarkGray

foreach ($Source in $BySource) {
    $Latest = ($Source.Group | Sort-Object -Property Time -Descending | Select-Object -First 1).Time
    Write-Host ($SourceFormat -f $Source.Name, $Source.Count, $Latest.ToString("dd-MM-yyyy HH:mm:ss")) -ForegroundColor Yellow
}

# Detailed list, newest first.
Write-Host ""
Write-Host "Lockout Events (newest first)" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

$EventFormat = "{0,-20} {1,-30} {2,-30}"
Write-Host ($EventFormat -f "Time", "Caller computer", "Domain controller") -ForegroundColor Cyan
Write-Host ("-" * 82) -ForegroundColor DarkGray

foreach ($LockoutEvent in $AllEvents | Sort-Object -Property Time -Descending | Select-Object -First 25) {
    Write-Host ($EventFormat -f $LockoutEvent.Time.ToString("dd-MM-yyyy HH:mm:ss"), $LockoutEvent.CallerComputer, $LockoutEvent.DomainController)
}

if ($AllEvents.Count -gt 25) {
    Write-Host ""
    Write-Host "Showing the 25 most recent of $($AllEvents.Count) events." -ForegroundColor DarkGray
}

# Hints for the technician.
Write-Host ""
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "==========" -ForegroundColor Cyan
Write-Host ""
Write-Host "If the caller is the user's own PC, check on that PC:"
Write-Host "- Saved credentials:    cmdkey /list"
Write-Host "- Mapped drives:        net use"
Write-Host "- Scheduled tasks or services running as the user"
Write-Host "- Another signed-in session with the old password"
Write-Host ""
Write-Host "If the caller is a server (mail, VPN, Wi-Fi/RADIUS, ADFS):"
Write-Host "- A phone or tablet with the old password saved for mail or Wi-Fi is the usual cause"
Write-Host ""
Write-Host "If the caller is blank:"
Write-Host "- The request often came through a service that doesn't report the device name."
Write-Host "  Check the logs of that service (for example the mail or VPN server)."

exit 0
