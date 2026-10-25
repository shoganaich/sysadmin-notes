#Requires -Version 5.1

<#
.SYNOPSIS
    Retrieves Windows LAPS information for an Active Directory computer.

.DESCRIPTION
    Validates the computer in Active Directory and displays available
    Windows LAPS metadata.

    The password is retrieved as plain text only after the technician
    explicitly chooses to copy or display it.

.NOTES
    The current technician must have permission to read the LAPS password.

    This script does not rotate passwords, change expiration dates,
    modify LAPS policy, or grant LAPS permissions.
#>

$ErrorActionPreference = "Stop"

function Wait-ForKey {
    param(
        [string]$Message = "Press any key to continue..."
    )

    Write-Host ""
    Write-Host $Message -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

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

function Clear-PasswordClipboard {
    try {
        $ExistingText = $null

        if (Get-Command -Name Get-Clipboard -ErrorAction SilentlyContinue) {
            $ExistingText = Get-Clipboard -ErrorAction SilentlyContinue
        }

        if ($null -eq $ExistingText -or [string]::IsNullOrEmpty([string]$ExistingText)) {
            Write-Host ""
            Write-Host "Clipboard already empty." -ForegroundColor DarkGray
            return
        }
    }
    catch {
        # If the clipboard is already empty or unavailable, avoid treating it as a failure.
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.Clipboard]::Clear()
        Write-Host ""
        Write-Host "Clipboard cleared." -ForegroundColor Green
    }
    catch {
        $ExceptionMessage = $_.Exception.Message

        if ($ExceptionMessage -match "Value cannot be null|Parameter name: text") {
            Write-Host ""
            Write-Host "Clipboard already empty." -ForegroundColor DarkGray
            return
        }

        Write-Host ""
        Write-Host "Unable to clear the clipboard." -ForegroundColor Yellow
        Write-Host "Details: $ExceptionMessage" -ForegroundColor DarkYellow
    }
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

# Import the Windows LAPS module.
try {
    Import-Module LAPS -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "Failed to import the Windows LAPS module." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "Run this option from a computer with the Windows LAPS" -ForegroundColor Yellow
    Write-Host "management tools installed." -ForegroundColor Yellow
    exit 1
}

# Confirm that the required command exists.
if (-not (Get-Command -Name Get-LapsADPassword -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "Get-LapsADPassword is not available." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Check LAPS Information" -ForegroundColor Cyan
Write-Host "======================"
Write-Host ""

$ComputerInput = Read-Host "Enter the computer name"

if (-not $ComputerInput -or $ComputerInput.Trim().Length -eq 0) {
    Write-Host ""
    Write-Host "Please enter a valid computer name." -ForegroundColor Yellow
    exit 1
}

$ComputerInput = $ComputerInput.Trim()

# Accept COMPUTER$ format.
if ($ComputerInput.EndsWith('$')) {
    $ComputerInput = $ComputerInput.TrimEnd('$')
}

# Validate the computer in Active Directory.
try {
    $Computer = Get-ADComputer `
        -Identity $ComputerInput `
        -Properties DNSHostName, Enabled, OperatingSystem, Description `
        -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "Computer '$ComputerInput' was not found in Active Directory." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    exit 1
}

$DNSHostName = if ($Computer.DNSHostName) { $Computer.DNSHostName } else { "N/A" }
$OperatingSystem = if ($Computer.OperatingSystem) { $Computer.OperatingSystem } else { "N/A" }
$Description = if ($Computer.Description) { $Computer.Description } else { "N/A" }

if ($Computer.Enabled) {
    $EnabledText = "Yes"
    $EnabledColor = "Green"
}
else {
    $EnabledText = "No"
    $EnabledColor = "Red"
}

Write-Host ""
Write-Host "Computer Information" -ForegroundColor Cyan
Write-Host "===================="
Write-Host ""
Write-Host ("{0,-24}: {1}" -f "Computer", $Computer.Name)
Write-Host ("{0,-24}: {1}" -f "DNS hostname", $DNSHostName)
Write-Host ("{0,-24}: {1}" -f "Enabled in AD", $EnabledText) -ForegroundColor $EnabledColor
Write-Host ("{0,-24}: {1}" -f "Operating system", $OperatingSystem)
Write-Host ("{0,-24}: {1}" -f "Description", $Description)

# Retrieve metadata without requesting a plain-text password.
try {
    $LapsMetadata = Get-LapsADPassword `
        -Identity $Computer.Name `
        -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "Unable to retrieve Windows LAPS information." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "The current account may not have permission to read" -ForegroundColor Yellow
    Write-Host "the LAPS information for this computer." -ForegroundColor Yellow
    exit 1
}

if (-not $LapsMetadata) {
    Write-Host ""
    Write-Host "No Windows LAPS information was returned." -ForegroundColor Yellow
    exit 0
}

if ($LapsMetadata.Account) {
    $ManagedAccount = [string]$LapsMetadata.Account
}
elseif ([string]$LapsMetadata.Source -eq "LegacyLapsCleartextPassword") {
    $ManagedAccount = "Not stored by legacy LAPS"
}
else {
    $ManagedAccount = "N/A"
}

$PasswordUpdated = Format-DateValue -Value $LapsMetadata.PasswordUpdateTime
$PasswordExpiration = Format-DateValue -Value $LapsMetadata.ExpirationTimestamp
$StorageSource = if ($LapsMetadata.Source) { [string]$LapsMetadata.Source } else { "N/A" }
$DecryptionStatus = if ($LapsMetadata.DecryptionStatus) { [string]$LapsMetadata.DecryptionStatus } else { "Not applicable" }
$AuthorizedDecryptor = if ($LapsMetadata.AuthorizedDecryptor) { [string]$LapsMetadata.AuthorizedDecryptor } else { "Not applicable" }

Write-Host ""
Write-Host "LAPS Information" -ForegroundColor Cyan
Write-Host "================"
Write-Host ""
Write-Host ("{0,-24}: {1}" -f "LAPS implementation", "Windows LAPS")
Write-Host ("{0,-24}: {1}" -f "Managed account", $ManagedAccount)
Write-Host ("{0,-24}: {1}" -f "Password updated", $PasswordUpdated)
Write-Host ("{0,-24}: {1}" -f "Password expiration", $PasswordExpiration)
Write-Host ("{0,-24}: {1}" -f "Storage source", $StorageSource)
Write-Host ("{0,-24}: {1}" -f "Decryption status", $DecryptionStatus)
Write-Host ("{0,-24}: {1}" -f "Authorized decryptor", $AuthorizedDecryptor)

while ($true) {
    Write-Host ""
    Write-Host "LAPS Actions" -ForegroundColor Cyan
    Write-Host "============"
    Write-Host ""
    Write-Host "1. Copy password to clipboard"
    Write-Host "2. Display password on screen"
    Write-Host "3. Clear clipboard"
    Write-Host "4. Return"
    Write-Host ""

    $Choice = Read-Host "Select an option"

    if ($Choice -eq "4") {
        Clear-PasswordClipboard
        $LapsMetadata = $null
        exit 0
    }

    if ($Choice -eq "3") {
        Clear-PasswordClipboard
        continue
    }

    if ($Choice -notin @("1", "2")) {
        Write-Host ""
        Write-Host "Invalid option." -ForegroundColor Yellow
        continue
    }

    # Retrieve readable output only after explicit selection.
    try {
        $ReadableResult = Get-LapsADPassword `
            -Identity $Computer.Name `
            -AsPlainText `
            -ErrorAction Stop

        $PlainTextPassword = [string]$ReadableResult.Password
    }
    catch {
        Write-Host ""
        Write-Host "Unable to retrieve the readable LAPS password." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
        Write-Host ""
        Write-Host "The current account may not have permission to read" -ForegroundColor Yellow
        Write-Host "or decrypt the LAPS password." -ForegroundColor Yellow
        $ReadableResult = $null
        $PlainTextPassword = $null
        continue
    }

    if (-not $PlainTextPassword -or $PlainTextPassword.Length -eq 0) {
        Write-Host ""
        Write-Host "No readable password was returned." -ForegroundColor Yellow
        $ReadableResult = $null
        $PlainTextPassword = $null
        continue
    }

    if ($Choice -eq "1") {
        try {
            Set-Clipboard -Value $PlainTextPassword
            Write-Host ""
            Write-Host "Password copied to the clipboard." -ForegroundColor Green
            Write-Host ""
            Write-Host "Press any key after using the password." -ForegroundColor Yellow
            Write-Host "The clipboard will then be cleared." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-PasswordClipboard
        }
        catch {
            Write-Host ""
            Write-Host "Unable to copy the password." -ForegroundColor Red
            Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
        }
    }

    if ($Choice -eq "2") {
        Write-Host ""
        Write-Host "[WARNING] The password will be visible on screen." -ForegroundColor Yellow
        Write-Host "Do not continue during screen sharing or recording." -ForegroundColor Yellow
        Write-Host ""

        $Confirmation = Read-Host "Display it? (Y/N)"

        if ($Confirmation -and $Confirmation.Trim().ToUpperInvariant() -in @("Y", "YES")) {
            Clear-Host
            Write-Host "LAPS Password" -ForegroundColor Cyan
            Write-Host "============="
            Write-Host ""
            Write-Host ("{0,-16}: {1}" -f "Computer", $Computer.Name)

            if ($ReadableResult.Account) {
                Write-Host ("{0,-16}: {1}" -f "Account", $ReadableResult.Account)
            }

            Write-Host ("{0,-16}: " -f "Password") -NoNewline
            Write-Host $PlainTextPassword -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to clear the password from the screen." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-Host
            Write-Host "Check LAPS Information" -ForegroundColor Cyan
            Write-Host "======================"
            Write-Host ""
            Write-Host "The displayed password was cleared from the screen." -ForegroundColor Green
        }
        else {
            Write-Host ""
            Write-Host "Display cancelled." -ForegroundColor Yellow
        }
    }

    $PlainTextPassword = $null
    $ReadableResult = $null
}
