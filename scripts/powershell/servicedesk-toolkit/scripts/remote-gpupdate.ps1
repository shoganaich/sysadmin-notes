#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Runs a Group Policy update on a remote computer.

.DESCRIPTION
    Runs the equivalent of "gpupdate /force" on a remote computer, so new
    group memberships, drive mappings, or policy changes apply without
    remoting in.

    Uses Invoke-GPUpdate (GroupPolicy module) when it is installed. This
    refreshes computer policy and the policy of every signed-in user.

    If the GroupPolicy module is not installed, it falls back to
    PowerShell remoting (WinRM). In that case only COMPUTER policy can be
    refreshed, because a remote session runs as the technician, not as
    the signed-in user.

.NOTES
    Requires administrator rights on the target computer.

    Invoke-GPUpdate needs the "Remote Scheduled Tasks Management" firewall
    rules enabled on the target, because it runs the update as a scheduled task.
#>

$ErrorActionPreference = "Stop"

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

$HasGPModule = $false

try {
    Import-Module GroupPolicy -ErrorAction Stop
    $HasGPModule = [bool](Get-Command -Name Invoke-GPUpdate -ErrorAction SilentlyContinue)
}
catch {
    $HasGPModule = $false
}

Write-Host ""
Write-Host "Remote Group Policy Update" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

$ComputerInput = Read-Host "Enter the computer name"

if ([string]::IsNullOrWhiteSpace($ComputerInput)) {
    Write-Host ""
    Write-Host "Please enter a valid computer name." -ForegroundColor Yellow
    exit 1
}

$ComputerInput = $ComputerInput.Trim().TrimEnd('$')

try {
    $ADComputer = Get-ADComputer -Identity $ComputerInput -Properties DNSHostName, Enabled -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "Computer '$ComputerInput' was not found in Active Directory." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    exit 1
}

$Target = if ($ADComputer.DNSHostName) { $ADComputer.DNSHostName } else { $ADComputer.Name }

if (-not $ADComputer.Enabled) {
    Write-Host ""
    Write-Host "[WARNING] This computer is disabled in Active Directory." -ForegroundColor Yellow
}

# Choose what to refresh.
if ($HasGPModule) {
    Write-Host ""
    Write-Host "Method: Invoke-GPUpdate (GroupPolicy module)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "1. Computer and user policy (recommended)"
    Write-Host "2. Computer policy only"
    Write-Host "3. User policy only (signed-in users)"
    Write-Host ""

    $TargetChoice = Read-Host "Select an option (Enter = 1)"

    switch (($TargetChoice + "").Trim()) {
        ""  { $PolicyTarget = $null;       $TargetText = "Computer and user" }
        "1" { $PolicyTarget = $null;       $TargetText = "Computer and user" }
        "2" { $PolicyTarget = "Computer";  $TargetText = "Computer only" }
        "3" { $PolicyTarget = "User";      $TargetText = "User only" }
        default {
            Write-Host ""
            Write-Host "Invalid selection." -ForegroundColor Yellow
            exit 1
        }
    }
}
else {
    Write-Host ""
    Write-Host "[INFO] The GroupPolicy module is not installed on this computer." -ForegroundColor Yellow
    Write-Host "Falling back to PowerShell remoting. Only COMPUTER policy will be refreshed." -ForegroundColor Yellow
    Write-Host "Install RSAT: Group Policy Management Tools to also refresh user policy." -ForegroundColor DarkGray
    $PolicyTarget = "Computer"
    $TargetText = "Computer only"
}

Write-Host ""
Write-Host "Computer : $Target"
Write-Host "Policy   : $TargetText"
Write-Host ""

$Confirmation = Read-Host "Run the Group Policy update now? (Y/N)"

if (-not $Confirmation -or $Confirmation.Trim().ToUpper() -notin @("Y", "YES")) {
    Write-Host ""
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Running the Group Policy update on $Target..." -ForegroundColor DarkGray

try {
    if ($HasGPModule) {
        $Parameters = @{
            Computer              = $Target
            Force                 = $true
            RandomDelayInMinutes  = 0
            ErrorAction           = "Stop"
        }

        if ($PolicyTarget) {
            $Parameters.Target = $PolicyTarget
        }

        Invoke-GPUpdate @Parameters

        Write-Host ""
        Write-Host "The Group Policy update was started on $Target." -ForegroundColor Green
        Write-Host "It runs on the computer in the background and usually finishes within a minute." -ForegroundColor DarkGray
    }
    else {
        $Output = Invoke-Command -ComputerName $Target -ErrorAction Stop -ScriptBlock {
            gpupdate.exe /target:computer /force 2>&1
        }

        Write-Host ""

        foreach ($Line in $Output) {
            if (-not [string]::IsNullOrWhiteSpace([string]$Line)) {
                Write-Host ([string]$Line)
            }
        }

        Write-Host ""
        Write-Host "Computer policy was refreshed on $Target." -ForegroundColor Green
    }
}
catch {
    Write-Host ""
    Write-Host "The Group Policy update failed." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "Common causes:" -ForegroundColor Yellow

    if ($HasGPModule) {
        Write-Host "- The 'Remote Scheduled Tasks Management' firewall rules are disabled on the target." -ForegroundColor Yellow
    }
    else {
        Write-Host "- WinRM (TCP 5985) is not enabled or is blocked on the target." -ForegroundColor Yellow
    }

    Write-Host "- Your account is not an administrator on the target." -ForegroundColor Yellow
    Write-Host "- The computer is off or not reachable." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Notes" -ForegroundColor Cyan
Write-Host "-----" -ForegroundColor Cyan
Write-Host "- New group memberships still need the user to sign out and back in (or run 'klist purge')."
Write-Host "- Some policies (software installation, folder redirection) only apply at restart or sign-in."
Write-Host "- To check what applied: gpresult /s $($ADComputer.Name) /r /scope computer"

exit 0
