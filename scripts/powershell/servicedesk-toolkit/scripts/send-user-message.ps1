#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Sends a pop-up message to the users signed in to a remote computer.

.DESCRIPTION
    Shows who is signed in to the computer, lets the technician pick a
    ready-made message or write one, asks for confirmation, and sends it
    with msg.exe.

    Useful for "please restart your computer" or "please call the
    Service Desk" when the user can't be reached by phone or chat.

.NOTES
    The target computer must allow remote messages:

        HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server
        AllowRemoteRPC = 1 (DWORD)

    Without it, msg.exe returns "Error 5" (access denied) or
    "Error 1722" (RPC server unavailable).
#>

$ErrorActionPreference = "Stop"

# How long the message stays on screen, in seconds.
$DisplaySeconds = 300

# Ready-made messages. Edit these to match your team's wording.
$Templates = @(
    "Hello, this is the IT Service Desk. Please save your work and restart your computer when possible. Thank you."
    "Hello, this is the IT Service Desk. Please call us back on the usual Service Desk number. Thank you."
    "Hello, this is the IT Service Desk. We are about to connect to your computer to work on your ticket."
    "Hello, this is the IT Service Desk. Your computer will be restarted in 10 minutes. Please save your work now."
)

# Use the 64-bit msg.exe even when running in 32-bit PowerShell.
$MsgPath = Join-Path -Path $env:WINDIR -ChildPath "Sysnative\msg.exe"

if (-not (Test-Path -LiteralPath $MsgPath)) {
    $MsgPath = Join-Path -Path $env:WINDIR -ChildPath "System32\msg.exe"
}

$QuserPath = Join-Path -Path $env:WINDIR -ChildPath "Sysnative\quser.exe"

if (-not (Test-Path -LiteralPath $QuserPath)) {
    $QuserPath = Join-Path -Path $env:WINDIR -ChildPath "System32\quser.exe"
}

if (-not (Test-Path -LiteralPath $MsgPath)) {
    Write-Host ""
    Write-Host "msg.exe was not found on this computer." -ForegroundColor Red
    Write-Host "It is included in Windows Pro, Enterprise, and Education editions." -ForegroundColor Yellow
    exit 1
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
Write-Host "Send Message to User" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host ""

$ComputerInput = Read-Host "Enter the computer name"

if ([string]::IsNullOrWhiteSpace($ComputerInput)) {
    Write-Host ""
    Write-Host "Please enter a valid computer name." -ForegroundColor Yellow
    exit 1
}

$ComputerInput = $ComputerInput.Trim().TrimEnd('$')

try {
    $ADComputer = Get-ADComputer -Identity $ComputerInput -Properties DNSHostName -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "Computer '$ComputerInput' was not found in Active Directory." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    exit 1
}

$Target = $ADComputer.Name

# Show who is signed in.
Write-Host ""
Write-Host "Signed-in sessions on $Target" -ForegroundColor Cyan
Write-Host ("-" * (24 + $Target.Length)) -ForegroundColor Cyan

$SessionsFound = $false

if (Test-Path -LiteralPath $QuserPath) {
    $QuserOutput = & $QuserPath "/server:$Target" 2>&1
    $QuserExit = $LASTEXITCODE

    foreach ($Line in $QuserOutput) {
        Write-Host ([string]$Line)
    }

    if ($QuserExit -eq 0) {
        $SessionsFound = $true
    }
    else {
        Write-Host ""
        Write-Host "No sessions found, or the session list could not be read." -ForegroundColor Yellow
    }
}
else {
    Write-Host "quser.exe is not available. Skipping the session check." -ForegroundColor DarkGray
    $SessionsFound = $true
}

if (-not $SessionsFound) {
    Write-Host ""
    $ContinueChoice = Read-Host "Send the message anyway? (Y/N)"

    if (-not $ContinueChoice -or $ContinueChoice.Trim().ToUpper() -notin @("Y", "YES")) {
        Write-Host ""
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Choose the message.
Write-Host ""
Write-Host "Messages" -ForegroundColor Cyan
Write-Host "--------" -ForegroundColor Cyan

for ($Index = 0; $Index -lt $Templates.Count; $Index++) {
    Write-Host ("{0}. {1}" -f ($Index + 1), $Templates[$Index])
}

Write-Host "C. Write a custom message"
Write-Host ""

$MessageChoice = Read-Host "Select a message"

if ([string]::IsNullOrWhiteSpace($MessageChoice)) {
    Write-Host ""
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit 0
}

$MessageChoice = $MessageChoice.Trim()

if ($MessageChoice -match '^\d+$' -and [int]$MessageChoice -ge 1 -and [int]$MessageChoice -le $Templates.Count) {
    $Message = $Templates[[int]$MessageChoice - 1]
}
elseif ($MessageChoice -ieq "C") {
    $Message = Read-Host "Type the message"

    if ([string]::IsNullOrWhiteSpace($Message)) {
        Write-Host ""
        Write-Host "The message cannot be empty." -ForegroundColor Yellow
        exit 1
    }

    $Message = $Message.Trim()
}
else {
    Write-Host ""
    Write-Host "Invalid selection." -ForegroundColor Yellow
    exit 1
}

# Confirm.
Write-Host ""
Write-Host "Computer : $Target"
Write-Host "Sent to  : All signed-in sessions"
Write-Host "On screen: $DisplaySeconds seconds or until closed"
Write-Host "Message  :"
Write-Host "  $Message" -ForegroundColor Cyan
Write-Host ""

$Confirmation = Read-Host "Send this message? (Y/N)"

if (-not $Confirmation -or $Confirmation.Trim().ToUpper() -notin @("Y", "YES")) {
    Write-Host ""
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit 0
}

# Windows PowerShell 5.1 doesn't escape double quotes when passing arguments
# to programs like msg.exe, which would cut the message short.
$Message = $Message.Replace('"', "'")

# Send.
$MsgOutput = & $MsgPath "*" "/server:$Target" "/time:$DisplaySeconds" $Message 2>&1
$MsgExit = $LASTEXITCODE

if ($MsgExit -eq 0) {
    Write-Host ""
    Write-Host "Message sent to $Target." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "The message could not be sent." -ForegroundColor Red

foreach ($Line in $MsgOutput) {
    Write-Host ([string]$Line) -ForegroundColor DarkRed
}

Write-Host ""
Write-Host "Common causes:" -ForegroundColor Yellow
Write-Host "- Error 5 or 1722: the target does not allow remote messages (AllowRemoteRPC = 0)." -ForegroundColor Yellow
Write-Host "- Nobody is signed in to the computer." -ForegroundColor Yellow
Write-Host "- A firewall is blocking RPC/SMB to the computer." -ForegroundColor Yellow

exit 1
