#Requires -Version 5.1

<#
.SYNOPSIS
    Service Desk Toolkit main menu.

.DESCRIPTION
    Runs every tool inside one PowerShell session, so the Active Directory
    module is loaded once instead of every time a tool is opened.

    Each tool is a separate script in the "scripts" folder. To add a tool,
    create the script and add one line to the $MenuItems list below.

    Start it with servicedesk-toolkit.bat, or from PowerShell:
        .\servicedesk-toolkit.ps1
#>

$ScriptsFolder = Join-Path -Path $PSScriptRoot -ChildPath "scripts"

# ============================================================
# Menu definition
# ============================================================
# Key     = what the technician types
# Section = heading the item is shown under
# Name    = text shown in the menu
# Script  = file name in the scripts folder ($null = shown as "planned")

$MenuItems = @(
    [PSCustomObject]@{ Key = "1";  Section = "User tools";             Name = "Search user";                Script = "search-user.ps1" }
    [PSCustomObject]@{ Key = "2";  Section = "User tools";             Name = "Check account status";       Script = "check-account-status.ps1" }
    [PSCustomObject]@{ Key = "3";  Section = "User tools";             Name = "Find lockout source";        Script = "find-lockout-source.ps1" }
    [PSCustomObject]@{ Key = "4";  Section = "User tools";             Name = "View group memberships";     Script = "view-user-groups.ps1" }
    [PSCustomObject]@{ Key = "5";  Section = "User tools";             Name = "Find group approver";        Script = "find-group-approver.ps1" }

    [PSCustomObject]@{ Key = "6";  Section = "Computer tools";         Name = "Search computer";            Script = "search-computer.ps1" }
    [PSCustomObject]@{ Key = "7";  Section = "Computer tools";         Name = "Test computer connectivity"; Script = "test-computer-connectivity.ps1" }
    [PSCustomObject]@{ Key = "8";  Section = "Computer tools";         Name = "View computer details";      Script = "view-computer-details.ps1" }
    [PSCustomObject]@{ Key = "9";  Section = "Computer tools";         Name = "PC health check";            Script = "pc-health-check.ps1" }
    [PSCustomObject]@{ Key = "10"; Section = "Computer tools";         Name = "Check LAPS information";     Script = "check-laps-information.ps1" }

    [PSCustomObject]@{ Key = "11"; Section = "Remote actions";         Name = "Send message to user";       Script = "send-user-message.ps1" }
    [PSCustomObject]@{ Key = "12"; Section = "Remote actions";         Name = "Remote Group Policy update"; Script = "remote-gpupdate.ps1" }

    [PSCustomObject]@{ Key = "13"; Section = "Network / DNS-DHCP";     Name = "Check DNS and DHCP records"; Script = "check-dns-dhcp.ps1" }

    [PSCustomObject]@{ Key = "14"; Section = "Administrative actions"; Name = "Unlock account";             Script = "unlock-account.ps1" }
    [PSCustomObject]@{ Key = "15"; Section = "Administrative actions"; Name = "Reset password";             Script = "reset-password.ps1" }
)

# ============================================================
# Helper functions
# ============================================================

function Wait-ForKey {
    param(
        [string]$Message = "Press any key to return to the menu..."
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor DarkGray
    Write-Host $Message -ForegroundColor DarkGray
    Write-Host "========================================" -ForegroundColor DarkGray

    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    catch {
        # Some hosts (for example PowerShell ISE) don't support ReadKey.
        $null = Read-Host
    }
}

function Show-Menu {
    param(
        [string]$ModuleStatus
    )

    Clear-Host

    Write-Host "Service Desk Toolkit" -ForegroundColor Cyan
    Write-Host "====================" -ForegroundColor Cyan
    Write-Host ("Technician: {0}\{1}" -f $env:USERDOMAIN, $env:USERNAME) -ForegroundColor DarkGray
    Write-Host $ModuleStatus -ForegroundColor DarkGray

    $CurrentSection = $null

    foreach ($Item in $MenuItems) {
        if ($Item.Section -ne $CurrentSection) {
            $CurrentSection = $Item.Section
            Write-Host ""
            Write-Host $CurrentSection -ForegroundColor Cyan
            Write-Host ("-" * $CurrentSection.Length) -ForegroundColor DarkGray
        }

        $Label = "{0,3}. {1}" -f $Item.Key, $Item.Name

        if ($Item.Script) {
            Write-Host $Label
        }
        else {
            Write-Host ("{0}  (planned)" -f $Label) -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "  Q. Exit"
    Write-Host ""
}

function Invoke-ToolkitScript {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Item
    )

    Clear-Host

    if (-not $Item.Script) {
        Write-Host "[INFO] '$($Item.Name)' is planned but not available yet." -ForegroundColor Yellow
        return
    }

    $ScriptPath = Join-Path -Path $ScriptsFolder -ChildPath $Item.Script

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        Write-Host "[ERROR] Script not found:" -ForegroundColor Red
        Write-Host ""
        Write-Host $ScriptPath
        return
    }

    $Host.UI.RawUI.WindowTitle = "Service Desk Toolkit - $($Item.Name)"

    # Run the tool in this session. "exit" inside a tool ends that tool only,
    # not the menu, and the exit code is available in $LASTEXITCODE.
    $global:LASTEXITCODE = 0

    try {
        & $ScriptPath

        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "[WARNING] The tool finished with an error (exit code $LASTEXITCODE)." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] The tool stopped unexpectedly." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    }
    finally {
        $Host.UI.RawUI.WindowTitle = "Service Desk Toolkit"
    }
}

# ============================================================
# Start-up
# ============================================================

$Host.UI.RawUI.WindowTitle = "Service Desk Toolkit"

Write-Host ""
Write-Host "Loading the Active Directory module..." -ForegroundColor DarkGray

try {
    Import-Module ActiveDirectory -ErrorAction Stop -WarningAction SilentlyContinue
    $ModuleStatus = "Active Directory module: loaded"
}
catch {
    $ModuleStatus = "Active Directory module: NOT available - most tools will not work"
    Write-Host ""
    Write-Host "[WARNING] The Active Directory module could not be loaded." -ForegroundColor Yellow
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkYellow
    Write-Host "Install RSAT: Active Directory Domain Services and Lightweight Directory Tools." -ForegroundColor Yellow
    Wait-ForKey -Message "Press any key to open the menu anyway..."
}

# ============================================================
# Main loop
# ============================================================

while ($true) {
    Show-Menu -ModuleStatus $ModuleStatus

    $Choice = Read-Host "Select an option"

    if ($null -eq $Choice) {
        continue
    }

    $Choice = $Choice.Trim()

    if ($Choice -match '^(q|quit|exit)$') {
        break
    }

    $SelectedItem = $MenuItems | Where-Object { $_.Key -eq $Choice } | Select-Object -First 1

    if (-not $SelectedItem) {
        Write-Host ""
        Write-Host "[ERROR] Invalid option." -ForegroundColor Red
        Start-Sleep -Seconds 1
        continue
    }

    Invoke-ToolkitScript -Item $SelectedItem
    Wait-ForKey
}

Clear-Host
Write-Host "Service Desk Toolkit closed." -ForegroundColor DarkGray
