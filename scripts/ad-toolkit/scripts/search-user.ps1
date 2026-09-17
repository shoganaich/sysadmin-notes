#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Searches Active Directory users by username or display name.

.DESCRIPTION
    Displays the following information:
    - Username
    - Display name
    - Job title
    - Enabled status
    - Lockout status
    - Password expiration
    - Extension Attribute 5
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

# Request a username or display name.
$SearchInput = Read-Host "Enter a username or name to search"

if (-not $SearchInput -or $SearchInput.Trim().Length -eq 0) {
    Write-Host ""
    Write-Host "Please enter a valid username or name." `
        -ForegroundColor Yellow

    exit 1
}

try {
    # Escape apostrophes before using the input in the AD filter.
    $SafeSearchInput = $SearchInput.Trim().Replace("'", "''")

    # Search both the username and display name properties.
    $Users = Get-ADUser `
        -Filter "SamAccountName -like '*$SafeSearchInput*' -or DisplayName -like '*$SafeSearchInput*'" `
        -Properties SamAccountName,
                    DisplayName,
                    Title,
                    Enabled,
                    LockedOut,
                    PasswordNeverExpires,
                    PasswordExpired,
                    msDS-UserPasswordExpiryTimeComputed,
                    extensionAttribute5 `
        -ErrorAction Stop

    if (-not $Users) {
        Write-Host ""
        Write-Host "No users matching '$SearchInput' were found." `
            -ForegroundColor Yellow

        exit 0
    }

    Write-Host ""

    $TableFormat = (
        "{0,-25} {1,-35} {2,-40} {3,-8} " +
        "{4,-10} {5,-23} {6,-20}"
    )

    Write-Host (
        $TableFormat -f `
            "Username",
            "Display Name",
            "Title",
            "Enabled",
            "Locked",
            "Password Expiration",
            "Attribute 5"
    ) -ForegroundColor Cyan

    Write-Host ("-" * 175) -ForegroundColor DarkGray

    foreach ($User in $Users | Sort-Object DisplayName) {
        $Username = $User.SamAccountName
        $DisplayName = $User.DisplayName
        $Title = $User.Title
        $Enabled = $User.Enabled
        $LockedOut = $User.LockedOut
        $Attribute5 = $User.extensionAttribute5

        # Replace empty values to preserve the table layout.
        if (-not $DisplayName -or $DisplayName.Trim().Length -eq 0) {
            $DisplayName = "N/A"
        }

        if (-not $Title -or $Title.Trim().Length -eq 0) {
            $Title = "N/A"
        }

        if (-not $Attribute5 -or $Attribute5.Trim().Length -eq 0) {
            $Attribute5 = "N/A"
        }

        $ExpiryRaw = $User."msDS-UserPasswordExpiryTimeComputed"

        # Determine password expiration status.
        if ($User.PasswordNeverExpires) {
            $ExpiryText = "Never expires"
            $ExpiryProblem = $false
        }
        elseif ($User.PasswordExpired) {
            $ExpiryText = "Expired"
            $ExpiryProblem = $true
        }
        elseif ($null -ne $ExpiryRaw -and [long]$ExpiryRaw -gt 0) {
            try {
                $ExpiryDate = :FromFileTime(
                    [long]$ExpiryRaw
                )

                $ExpiryText = $ExpiryDate.ToString(
                    "dd-MM-yyyy HH:mm"
                )

                $ExpiryProblem = $ExpiryDate -lt (Get-Date)
            }
            catch {
                $ExpiryText = "N/A"
                $ExpiryProblem = $false
            }
        }
        else {
            $ExpiryText = "N/A"
            $ExpiryProblem = $false
        }

        # Determine whether the account has a visible problem.
        $EnabledProblem = -not $Enabled
        $LockedProblem = $LockedOut

        $HasProblem = (
            $EnabledProblem -or
            $LockedProblem -or
            $ExpiryProblem
        )

        $BaseColor = if ($HasProblem) {
            "Yellow"
        }
        else {
            "Green"
        }

        # Username, display name, and title.
        Write-Host (
            "{0,-25} {1,-35} {2,-40}" -f `
                $Username,
                $DisplayName,
                $Title
        ) -ForegroundColor $BaseColor -NoNewline

        # Enabled status.
        $EnabledColor = if ($EnabledProblem) {
            "Red"
        }
        else {
            $BaseColor
        }

        Write-Host (
            " {0,-8}" -f $Enabled
        ) -ForegroundColor $EnabledColor -NoNewline

        # Lockout status.
        $LockedColor = if ($LockedProblem) {
            "Red"
        }
        else {
            $BaseColor
        }

        Write-Host (
            " {0,-10}" -f $LockedOut
        ) -ForegroundColor $LockedColor -NoNewline

        # Password expiration.
        $ExpiryColor = if ($ExpiryProblem) {
            "Red"
        }
        else {
            $BaseColor
        }

        Write-Host (
            " {0,-23}" -f $ExpiryText
        ) -ForegroundColor $ExpiryColor -NoNewline

        # Extension Attribute 5.
        Write-Host (
            " {0,-20}" -f $Attribute5
        ) -ForegroundColor $BaseColor
    }

    Write-Host ""
    Write-Host "Users found: $(@($Users).Count)" `
        -ForegroundColor DarkGray
}
catch {
    Write-Host ""
    Write-Host "An error occurred while searching for users." `
        -ForegroundColor Red

    Write-Host "Details: $($_.Exception.Message)" `
        -ForegroundColor DarkRed

    exit 1
}

exit 0