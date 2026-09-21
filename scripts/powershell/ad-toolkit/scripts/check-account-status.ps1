#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Displays detailed Active Directory account information.

.DESCRIPTION
    Searches for one user by username and displays:
    - Display name
    - Username
    - User principal name
    - Email address
    - Job title
    - Department
    - Manager
    - Enabled status
    - Lockout status
    - Password status and expiration
    - Account expiration
    - Last logon
    - Last bad password attempt
    - Bad logon count
    - Distinguished name
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

$Username = Read-Host "Enter the username"

if (-not $Username -or $Username.Trim().Length -eq 0) {
    Write-Host ""
    Write-Host "Please enter a valid username." `
        -ForegroundColor Yellow

    exit 1
}

$Username = $Username.Trim()

try {
    $User = Get-ADUser `
        -Identity $Username `
        -Properties DisplayName,
                    UserPrincipalName,
                    Mail,
                    Title,
                    Department,
                    Manager,
                    Description,
                    Enabled,
                    LockedOut,
                    PasswordExpired,
                    PasswordNeverExpires,
                    PasswordLastSet,
                    msDS-UserPasswordExpiryTimeComputed,
                    AccountExpirationDate,
                    LastLogonDate,
                    LastBadPasswordAttempt,
                    BadLogonCount,
                    WhenCreated,
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

# Resolve the user's manager.
$ManagerName = "N/A"

if ($User.Manager) {
    try {
        $Manager = Get-ADUser `
            -Identity $User.Manager `
            -Properties DisplayName `
            -ErrorAction Stop

        if ($Manager.DisplayName) {
            $ManagerName = $Manager.DisplayName
        }
    }
    catch {
        $ManagerName = "Unable to retrieve"
    }
}

# Determine password expiration.
$PasswordExpiryRaw =
    $User."msDS-UserPasswordExpiryTimeComputed"

if ($User.PasswordNeverExpires) {
    $PasswordExpiration = "Never expires"
    $PasswordHasProblem = $false
}
elseif ($User.PasswordExpired) {
    $PasswordExpiration = "Expired"
    $PasswordHasProblem = $true
}
elseif (
    $null -ne $PasswordExpiryRaw -and
    [long]$PasswordExpiryRaw -gt 0 -and
    [long]$PasswordExpiryRaw -ne [long]::MaxValue
) {
    try {
        $PasswordExpiryDate = [DateTime]::FromFileTime(
            [long]$PasswordExpiryRaw
        )

        $PasswordExpiration =
            $PasswordExpiryDate.ToString("dd-MM-yyyy HH:mm")

        $PasswordHasProblem =
            $PasswordExpiryDate -lt (Get-Date)
    }
    catch {
        $PasswordExpiration = "N/A"
        $PasswordHasProblem = $false
    }
}
else {
    $PasswordExpiration = "N/A"
    $PasswordHasProblem = $false
}

# Format optional values.
$DisplayName = if ($User.DisplayName) {
    $User.DisplayName
}
else {
    "N/A"
}

$UPN = if ($User.UserPrincipalName) {
    $User.UserPrincipalName
}
else {
    "N/A"
}

$Email = if ($User.Mail) {
    $User.Mail
}
else {
    "N/A"
}

$Title = if ($User.Title) {
    $User.Title
}
else {
    "N/A"
}

$Department = if ($User.Department) {
    $User.Department
}
else {
    "N/A"
}

$Description = if ($User.Description) {
    $User.Description
}
else {
    "N/A"
}

$Attribute5 = if ($User.extensionAttribute5) {
    $User.extensionAttribute5
}
else {
    "N/A"
}

$PasswordLastSet = if ($User.PasswordLastSet) {
    $User.PasswordLastSet.ToString("dd-MM-yyyy HH:mm")
}
else {
    "N/A"
}

$AccountExpiration = if ($User.AccountExpirationDate) {
    $User.AccountExpirationDate.ToString("dd-MM-yyyy HH:mm")
}
else {
    "Never"
}

$LastLogon = if ($User.LastLogonDate) {
    $User.LastLogonDate.ToString("dd-MM-yyyy HH:mm")
}
else {
    "N/A"
}

$LastBadPassword = if ($User.LastBadPasswordAttempt) {
    $User.LastBadPasswordAttempt.ToString("dd-MM-yyyy HH:mm")
}
else {
    "N/A"
}

$Created = if ($User.WhenCreated) {
    $User.WhenCreated.ToString("dd-MM-yyyy HH:mm")
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

$LockedText = if ($User.LockedOut) {
    "Yes"
}
else {
    "No"
}

$PasswordExpiredText = if ($User.PasswordExpired) {
    "Yes"
}
else {
    "No"
}

$PasswordNeverExpiresText = if ($User.PasswordNeverExpires) {
    "Yes"
}
else {
    "No"
}

Write-Host ""
Write-Host "Account Status" -ForegroundColor Cyan
Write-Host "==============" -ForegroundColor Cyan
Write-Host ""

Write-Host ("{0,-28}: {1}" -f "Display name", $DisplayName)
Write-Host ("{0,-28}: {1}" -f "Username", $User.SamAccountName)
Write-Host ("{0,-28}: {1}" -f "User principal name", $UPN)
Write-Host ("{0,-28}: {1}" -f "Email", $Email)
Write-Host ("{0,-28}: {1}" -f "Job title", $Title)
Write-Host ("{0,-28}: {1}" -f "Department", $Department)
Write-Host ("{0,-28}: {1}" -f "Manager", $ManagerName)
Write-Host ("{0,-28}: {1}" -f "Description", $Description)
Write-Host ("{0,-28}: {1}" -f "Attribute 5", $Attribute5)

Write-Host ""

if ($User.Enabled) {
    Write-Host ("{0,-28}: {1}" -f "Account enabled", $EnabledText) `
        -ForegroundColor Green
}
else {
    Write-Host ("{0,-28}: {1}" -f "Account enabled", $EnabledText) `
        -ForegroundColor Red
}

if ($User.LockedOut) {
    Write-Host ("{0,-28}: {1}" -f "Account locked", $LockedText) `
        -ForegroundColor Red
}
else {
    Write-Host ("{0,-28}: {1}" -f "Account locked", $LockedText) `
        -ForegroundColor Green
}

if ($User.PasswordExpired) {
    Write-Host (
        "{0,-28}: {1}" -f
        "Password expired",
        $PasswordExpiredText
    ) -ForegroundColor Red
}
else {
    Write-Host (
        "{0,-28}: {1}" -f
        "Password expired",
        $PasswordExpiredText
    ) -ForegroundColor Green
}

Write-Host (
    "{0,-28}: {1}" -f
    "Password never expires",
    $PasswordNeverExpiresText
)

Write-Host (
    "{0,-28}: {1}" -f
    "Password last set",
    $PasswordLastSet
)

if ($PasswordHasProblem) {
    Write-Host (
        "{0,-28}: {1}" -f
        "Password expiration",
        $PasswordExpiration
    ) -ForegroundColor Red
}
else {
    Write-Host (
        "{0,-28}: {1}" -f
        "Password expiration",
        $PasswordExpiration
    ) -ForegroundColor Green
}

Write-Host ""
Write-Host ("{0,-28}: {1}" -f "Account expiration", $AccountExpiration)
Write-Host ("{0,-28}: {1}" -f "Last logon", $LastLogon)
Write-Host ("{0,-28}: {1}" -f "Last bad password", $LastBadPassword)
Write-Host ("{0,-28}: {1}" -f "Bad logon count", $User.BadLogonCount)
Write-Host ("{0,-28}: {1}" -f "Account created", $Created)

Write-Host ""
Write-Host "Distinguished name:" -ForegroundColor DarkGray
Write-Host $User.DistinguishedName -ForegroundColor DarkGray

Write-Host ""
Write-Host "Status Summary" -ForegroundColor Cyan
Write-Host "=============="

$Problems = @()

if (-not $User.Enabled) {
    $Problems += "The account is disabled."
}

if ($User.LockedOut) {
    $Problems += "The account is locked."
}

if ($User.PasswordExpired -or $PasswordHasProblem) {
    $Problems += "The password is expired."
}

if (
    $User.AccountExpirationDate -and
    $User.AccountExpirationDate -lt (Get-Date)
) {
    $Problems += "The account has expired."
}

if ($Problems.Count -eq 0) {
    Write-Host ""
    Write-Host "No obvious account problems were found." `
        -ForegroundColor Green
}
else {
    Write-Host ""

    foreach ($Problem in $Problems) {
        Write-Host "[WARNING] $Problem" -ForegroundColor Yellow
    }
}

exit 0