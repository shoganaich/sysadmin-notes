#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Checks and unlocks an Active Directory user account.

.DESCRIPTION
    Displays relevant account information, checks the lockout and
    password status, requests confirmation, unlocks the account,
    and verifies the result.

.NOTES
    This script does not enable disabled accounts or reset passwords.
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

Write-Host ""
Write-Host "Unlock Active Directory Account" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

# Request the username.
$Username = Read-Host "Enter the username to check"

if (-not $Username -or $Username.Trim().Length -eq 0) {
    Write-Host ""
    Write-Host "Please enter a valid username." `
        -ForegroundColor Yellow

    exit 1
}

$Username = $Username.Trim()

# Retrieve the account.
try {
    $User = Get-ADUser `
        -Identity $Username `
        -Properties DisplayName,
                    Enabled,
                    LockedOut,
                    Description,
                    LastLogonDate,
                    PasswordExpired,
                    PasswordNeverExpires,
                    PasswordLastSet,
                    AccountExpirationDate,
                    msDS-UserPasswordExpiryTimeComputed,
                    extensionAttribute5 `
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

# Format optional properties.
if ($User.DisplayName) {
    $DisplayName = $User.DisplayName
}
else {
    $DisplayName = "N/A"
}

if ($User.Description) {
    $Description = $User.Description
}
else {
    $Description = "N/A"
}

if ($User.extensionAttribute5) {
    $Attribute5 = $User.extensionAttribute5
}
else {
    $Attribute5 = "N/A"
}

if ($User.LastLogonDate) {
    $LastLogon = $User.LastLogonDate.ToString("dd-MM-yyyy HH:mm")
}
else {
    $LastLogon = "N/A"
}

if ($User.PasswordLastSet) {
    $PasswordLastSet = $User.PasswordLastSet.ToString(
        "dd-MM-yyyy HH:mm"
    )
}
else {
    $PasswordLastSet = "N/A"
}

if ($User.AccountExpirationDate) {
    $AccountExpiration = $User.AccountExpirationDate.ToString(
        "dd-MM-yyyy HH:mm"
    )
}
else {
    $AccountExpiration = "Never"
}

# Determine password expiration.
$PasswordExpiryRaw = $User."msDS-UserPasswordExpiryTimeComputed"
$PasswordExpiryDate = $null

if (
    $null -ne $PasswordExpiryRaw -and
    [long]$PasswordExpiryRaw -gt 0
) {
    try {
        $PasswordExpiryDate =
            [System.DateTimeOffset]::FromFileTime(
                [long]$PasswordExpiryRaw
            ).LocalDateTime
    }
    catch {
        $PasswordExpiryDate = $null
    }
}

if ($User.PasswordNeverExpires) {
    $PasswordExpiration = "Never expires"
    $PasswordHasExpired = $false
}
elseif ($User.PasswordExpired) {
    $PasswordExpiration = "Expired"
    $PasswordHasExpired = $true
}
elseif ($PasswordExpiryDate) {
    $PasswordExpiration = $PasswordExpiryDate.ToString(
        "dd-MM-yyyy HH:mm"
    )

    $PasswordHasExpired = $PasswordExpiryDate -lt (Get-Date)
}
else {
    $PasswordExpiration = "N/A"
    $PasswordHasExpired = $false
}

# Format account states.
if ($User.Enabled) {
    $AccountStatus = "Enabled"
}
else {
    $AccountStatus = "Disabled"
}

if ($User.LockedOut) {
    $LockStatus = "Locked"
}
else {
    $LockStatus = "Not locked"
}

# Display account information.
Write-Host ""
Write-Host "Account Information" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host ""

Write-Host ("{0,-25}: {1}" -f "Display name", $DisplayName)
Write-Host ("{0,-25}: {1}" -f "Username", $User.SamAccountName)
Write-Host ("{0,-25}: {1}" -f "Description", $Description)
Write-Host ("{0,-25}: {1}" -f "Attribute 5", $Attribute5)
Write-Host ""

if ($User.Enabled) {
    Write-Host (
        "{0,-25}: {1}" -f "Account status", $AccountStatus
    ) -ForegroundColor Green
}
else {
    Write-Host (
        "{0,-25}: {1}" -f "Account status", $AccountStatus
    ) -ForegroundColor Red
}

if ($User.LockedOut) {
    Write-Host (
        "{0,-25}: {1}" -f "Lock status", $LockStatus
    ) -ForegroundColor Red
}
else {
    Write-Host (
        "{0,-25}: {1}" -f "Lock status", $LockStatus
    ) -ForegroundColor Green
}

if ($PasswordHasExpired) {
    Write-Host (
        "{0,-25}: {1}" -f
        "Password expiration",
        $PasswordExpiration
    ) -ForegroundColor Red
}
else {
    Write-Host (
        "{0,-25}: {1}" -f
        "Password expiration",
        $PasswordExpiration
    ) -ForegroundColor Green
}

Write-Host (
    "{0,-25}: {1}" -f
    "Password last set",
    $PasswordLastSet
)

Write-Host (
    "{0,-25}: {1}" -f
    "Account expiration",
    $AccountExpiration
)

Write-Host ("{0,-25}: {1}" -f "Last logon", $LastLogon)

# Report relevant conditions.
if (-not $User.Enabled) {
    Write-Host ""
    Write-Host (
        "[WARNING] The account is disabled. Unlocking it will not enable it."
    ) -ForegroundColor Yellow
}

if ($PasswordHasExpired) {
    Write-Host ""
    Write-Host (
        "[WARNING] The password is expired. Unlocking the account will not reset it."
    ) -ForegroundColor Yellow
}

# Stop when no unlock is required.
if (-not $User.LockedOut) {
    Write-Host ""
    Write-Host "No action required. The account is not locked." `
        -ForegroundColor Green

    exit 0
}

# Request confirmation.
Write-Host ""
Write-Host (
    "This action will unlock '$($User.SamAccountName)'."
) -ForegroundColor Yellow

$Confirmation = Read-Host "Unlock this account? (Y/N)"

if ($Confirmation.Trim().ToUpper() -notin @("Y", "YES")) {
    Write-Host ""
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit 0
}

# Unlock and verify the account.
try {
    Unlock-ADAccount `
        -Identity $User.DistinguishedName `
        -Confirm:$false `
        -ErrorAction Stop

    Start-Sleep -Milliseconds 500

    $UpdatedUser = Get-ADUser `
        -Identity $User.DistinguishedName `
        -Properties LockedOut `
        -ErrorAction Stop

    Write-Host ""

    if (-not $UpdatedUser.LockedOut) {
        Write-Host (
            "Account '$($User.SamAccountName)' was unlocked successfully."
        ) -ForegroundColor Green

        Write-Host ""
        Write-Host "Ticket Summary" -ForegroundColor Cyan
        Write-Host "==============" -ForegroundColor Cyan
        Write-Host "User             : $($User.SamAccountName)"
        Write-Host "Previous status  : Locked"
        Write-Host "Action performed : Account unlocked"
        Write-Host "Result            : Successful"

        if ($PasswordHasExpired) {
            Write-Host "Additional issue : Password expired" `
                -ForegroundColor Yellow
        }
        else {
            Write-Host "Additional issue : None"
        }
    }
    else {
        Write-Host (
            "The unlock command completed, but the account still appears locked."
        ) -ForegroundColor Yellow
    }
}
catch {
    Write-Host ""
    Write-Host (
        "Failed to unlock account '$($User.SamAccountName)'."
    ) -ForegroundColor Red

    Write-Host "Details: $($_.Exception.Message)" `
        -ForegroundColor DarkRed

    exit 1
}

exit 0