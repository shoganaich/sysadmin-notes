#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Resets an Active Directory user password.

.DESCRIPTION
    Displays the selected account, requests confirmation, and resets
    the password.

    The operator can choose whether the password is visible or hidden
    while typing.

    The script can also require the user to change the password at the
    next sign-in.

.NOTES
    The operator must have permission to reset Active Directory passwords.

    Passwords are not written to files or included in the output.
#>

$ErrorActionPreference = "Stop"

function Compare-SecureString {
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$First,

        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$Second
    )

    $FirstPointer = [System.IntPtr]::Zero
    $SecondPointer = [System.IntPtr]::Zero
    $FirstText = $null
    $SecondText = $null

    try {
        $FirstPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
            $First
        )

        $SecondPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
            $Second
        )

        $FirstText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
            $FirstPointer
        )

        $SecondText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
            $SecondPointer
        )

        return $FirstText -ceq $SecondText
    }
    finally {
        if ($FirstPointer -ne [System.IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR(
                $FirstPointer
            )
        }

        if ($SecondPointer -ne [System.IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR(
                $SecondPointer
            )
        }

        $FirstText = $null
        $SecondText = $null
    }
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

Write-Host ""
Write-Host "Reset Active Directory Password" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

# Request the exact username.
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
        -Properties DisplayName,
                    Enabled,
                    LockedOut,
                    PasswordExpired,
                    PasswordNeverExpires,
                    PasswordLastSet,
                    AccountExpirationDate `
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

# Format account information.
if ($User.DisplayName) {
    $DisplayName = $User.DisplayName
}
else {
    $DisplayName = "N/A"
}

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

if ($User.PasswordExpired) {
    $PasswordStatus = "Expired"
}
elseif ($User.PasswordNeverExpires) {
    $PasswordStatus = "Never expires"
}
else {
    $PasswordStatus = "Valid"
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

# Display the selected account.
Write-Host ""
Write-Host "Account Information" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host ""

Write-Host ("{0,-22}: {1}" -f "Display name", $DisplayName)
Write-Host ("{0,-22}: {1}" -f "Username", $User.SamAccountName)

if ($User.Enabled) {
    Write-Host (
        "{0,-22}: {1}" -f "Account status", $AccountStatus
    ) -ForegroundColor Green
}
else {
    Write-Host (
        "{0,-22}: {1}" -f "Account status", $AccountStatus
    ) -ForegroundColor Red
}

if ($User.LockedOut) {
    Write-Host (
        "{0,-22}: {1}" -f "Lock status", $LockStatus
    ) -ForegroundColor Yellow
}
else {
    Write-Host (
        "{0,-22}: {1}" -f "Lock status", $LockStatus
    ) -ForegroundColor Green
}

if ($User.PasswordExpired) {
    Write-Host (
        "{0,-22}: {1}" -f "Password status", $PasswordStatus
    ) -ForegroundColor Red
}
else {
    Write-Host (
        "{0,-22}: {1}" -f "Password status", $PasswordStatus
    ) -ForegroundColor Green
}

Write-Host (
    "{0,-22}: {1}" -f "Password last set", $PasswordLastSet
)

Write-Host (
    "{0,-22}: {1}" -f "Account expiration", $AccountExpiration
)

# Display relevant warnings.
if (-not $User.Enabled) {
    Write-Host ""
    Write-Host (
        "[WARNING] The account is disabled. Resetting the password will not enable it."
    ) -ForegroundColor Yellow
}

if ($User.LockedOut) {
    Write-Host ""
    Write-Host (
        "[WARNING] The account is currently locked. Resetting the password may not unlock it."
    ) -ForegroundColor Yellow
}

# Confirm the selected account.
Write-Host ""
$ResetConfirmation = Read-Host "Reset this account's password? (Y/N)"

if (
    -not $ResetConfirmation -or
    $ResetConfirmation.Trim().ToUpper() -notin @("Y", "YES")
) {
    Write-Host ""
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit 0
}

# Ask whether the password should be visible.
Write-Host ""
$VisibilityChoice = Read-Host "Show the password while typing? (Y/N)"

$ShowPassword = (
    $VisibilityChoice -and
    $VisibilityChoice.Trim().ToUpper() -in @("Y", "YES")
)

$NewPassword = $null
$ConfirmedPassword = $null
$NewPasswordText = $null
$ConfirmedPasswordText = $null

if ($ShowPassword) {
    Write-Host ""
    Write-Host (
        "[WARNING] The password will be visible on the screen."
    ) -ForegroundColor Yellow

    Write-Host (
        "Do not use this option during screen sharing or recorded sessions."
    ) -ForegroundColor Yellow

    Write-Host ""

    $NewPasswordText = Read-Host "Enter the new password"

    if (
        -not $NewPasswordText -or
        $NewPasswordText.Length -eq 0
    ) {
        Write-Host ""
        Write-Host "The password cannot be empty." `
            -ForegroundColor Yellow

        exit 1
    }

    $ConfirmedPasswordText = Read-Host "Confirm the new password"

    if ($NewPasswordText -cne $ConfirmedPasswordText) {
        Write-Host ""
        Write-Host "The passwords do not match." `
            -ForegroundColor Yellow

        $NewPasswordText = $null
        $ConfirmedPasswordText = $null

        exit 1
    }

    $NewPassword = ConvertTo-SecureString `
        -String $NewPasswordText `
        -AsPlainText `
        -Force

    # Clear the plain-text variables after conversion.
    $NewPasswordText = $null
    $ConfirmedPasswordText = $null
}
else {
    Write-Host ""
    Write-Host "The password will be hidden while typing." `
        -ForegroundColor DarkGray

    Write-Host ""

    $NewPassword = Read-Host "Enter the new password" `
        -AsSecureString

    if ($NewPassword.Length -eq 0) {
        Write-Host ""
        Write-Host "The password cannot be empty." `
            -ForegroundColor Yellow

        exit 1
    }

    $ConfirmedPassword = Read-Host "Confirm the new password" `
        -AsSecureString

    if ($ConfirmedPassword.Length -eq 0) {
        Write-Host ""
        Write-Host "The confirmation password cannot be empty." `
            -ForegroundColor Yellow

        $NewPassword = $null
        $ConfirmedPassword = $null

        exit 1
    }

    $PasswordsMatch = Compare-SecureString `
        -First $NewPassword `
        -Second $ConfirmedPassword

    if (-not $PasswordsMatch) {
        Write-Host ""
        Write-Host "The passwords do not match." `
            -ForegroundColor Yellow

        $NewPassword = $null
        $ConfirmedPassword = $null

        exit 1
    }

    $ConfirmedPassword = $null
}

# Ask whether the user must change the password at next sign-in.
Write-Host ""
$ChangeChoice = Read-Host "Require password change at next sign-in? (Y/N)"

$SkippedNeverExpires = $false

$ChangeAtNextLogon = (
    $ChangeChoice -and
    $ChangeChoice.Trim().ToUpper() -in @("Y", "YES")
)

# Active Directory does not allow "change password at next sign-in" while
# "password never expires" is set. Catch this before the reset so the
# technician is not told the reset failed when it actually succeeded.
if ($ChangeAtNextLogon -and $User.PasswordNeverExpires) {
    Write-Host ""
    Write-Host (
        "[WARNING] This account is set to 'Password never expires', so AD will not"
    ) -ForegroundColor Yellow
    Write-Host (
        "allow 'Change password at next sign-in'. The password will be reset without it."
    ) -ForegroundColor Yellow

    $ContinueChoice = Read-Host "Continue with the reset? (Y/N)"

    if (
        -not $ContinueChoice -or
        $ContinueChoice.Trim().ToUpper() -notin @("Y", "YES")
    ) {
        Write-Host ""
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        $NewPassword = $null
        exit 0
    }

    $ChangeAtNextLogon = $false
    $SkippedNeverExpires = $true
}

# Reset the password.
try {
    Set-ADAccountPassword `
        -Identity $User.DistinguishedName `
        -Reset `
        -NewPassword $NewPassword `
        -Confirm:$false `
        -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host (
        "Failed to reset the password for '$($User.SamAccountName)'."
    ) -ForegroundColor Red

    Write-Host "Details: $($_.Exception.Message)" `
        -ForegroundColor DarkRed

    exit 1
}
finally {
    $NewPassword = $null
    $ConfirmedPassword = $null
    $NewPasswordText = $null
    $ConfirmedPasswordText = $null
}

Write-Host ""
Write-Host (
    "The password for '$($User.SamAccountName)' was reset successfully."
) -ForegroundColor Green

# Set "change at next sign-in" separately, so a failure here is not
# reported as a failed password reset.
# A reset already clears any previous "must change" flag, so nothing needs
# to be done when the technician answered No.
$ChangeAtLogonText = if ($SkippedNeverExpires) {
    "Not set (password never expires)"
}
else {
    "Not required"
}
$ChangeAtLogonFailed = $false

if ($ChangeAtNextLogon) {
    try {
        Set-ADUser `
            -Identity $User.DistinguishedName `
            -ChangePasswordAtLogon $true `
            -ErrorAction Stop

        $ChangeAtLogonText = "Required"
    }
    catch {
        $ChangeAtLogonFailed = $true
        $ChangeAtLogonText = "FAILED to set"

        Write-Host ""
        Write-Host (
            "[WARNING] The password was reset, but 'Change password at next sign-in' could not be set."
        ) -ForegroundColor Yellow

        Write-Host "Details: $($_.Exception.Message)" `
            -ForegroundColor DarkYellow

        Write-Host "Do NOT reset the password again. Set the option manually in ADUC." `
            -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Ticket Summary" -ForegroundColor Cyan
Write-Host "==============" -ForegroundColor Cyan
Write-Host ""

Write-Host "User              : $($User.SamAccountName)"
Write-Host "Action performed  : Password reset"
Write-Host "Result            : Successful"

if ($ChangeAtLogonFailed) {
    Write-Host "Change at sign-in : $ChangeAtLogonText" -ForegroundColor Yellow
}
else {
    Write-Host "Change at sign-in : $ChangeAtLogonText"
}

if ($User.LockedOut) {
    Write-Host "Additional issue  : Account was locked" `
        -ForegroundColor Yellow
}
else {
    Write-Host "Additional issue  : None"
}

exit 0
