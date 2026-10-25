#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Quick health check of a remote computer.

.DESCRIPTION
    Shows, in one screen:

    - Signed-in user
    - Model and serial number
    - Operating system and build
    - Last boot time and uptime
    - CPU load and memory use
    - Free space on every local disk
    - Whether a restart is pending

    It connects with CIM over WinRM first and falls back to DCOM (RPC)
    when WinRM is not available.

.NOTES
    Requires administrator rights on the target computer.

    This script is read-only.
#>

$ErrorActionPreference = "Stop"

# Thresholds for warnings.
$UptimeWarningDays = 7
$DiskWarningPercent = 10
$DiskWarningGB = 10
$MemoryWarningPercent = 90
$CpuWarningPercent = 90

# Registry root for StdRegProv calls.
$HKLM = [uint32]2147483650

function Test-RemoteRegistryKey {
    param(
        [Parameter(Mandatory = $true)]
        $CimSession,

        [Parameter(Mandatory = $true)]
        [string]$KeyPath
    )

    try {
        $Result = Invoke-CimMethod `
            -CimSession $CimSession `
            -Namespace "root/default" `
            -ClassName "StdRegProv" `
            -MethodName "EnumKey" `
            -Arguments @{ hDefKey = $HKLM; sSubKeyName = $KeyPath } `
            -ErrorAction Stop

        # ReturnValue 0 means the key exists.
        return ($Result.ReturnValue -eq 0)
    }
    catch {
        return $null
    }
}

function Write-Check {
    param(
        [string]$Label,
        [string]$Value,
        [bool]$Warning = $false
    )

    $Color = if ($Warning) { "Yellow" } else { "Green" }
    Write-Host ("{0,-22}: {1}" -f $Label, $Value) -ForegroundColor $Color
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
Write-Host "PC Health Check" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan
Write-Host ""

$ComputerInput = Read-Host "Enter the computer name"

if ([string]::IsNullOrWhiteSpace($ComputerInput)) {
    Write-Host ""
    Write-Host "Please enter a valid computer name." -ForegroundColor Yellow
    exit 1
}

$ComputerInput = $ComputerInput.Trim().TrimEnd('$')

# Confirm the computer exists in Active Directory.
try {
    $ADComputer = Get-ADComputer `
        -Identity $ComputerInput `
        -Properties DNSHostName, Enabled `
        -ErrorAction Stop
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

# Connect: WinRM first, then DCOM.
Write-Host ""
Write-Host "Connecting to $Target..." -ForegroundColor DarkGray

$Session = $null
$Protocol = $null

try {
    $Session = New-CimSession -ComputerName $Target -OperationTimeoutSec 15 -ErrorAction Stop
    $Protocol = "WinRM"
}
catch {
    $WinRMError = $_.Exception.Message

    try {
        $DcomOption = New-CimSessionOption -Protocol Dcom
        $Session = New-CimSession -ComputerName $Target -SessionOption $DcomOption -OperationTimeoutSec 15 -ErrorAction Stop
        $Protocol = "DCOM"
    }
    catch {
        Write-Host ""
        Write-Host "Unable to connect to $Target." -ForegroundColor Red
        Write-Host "WinRM: $WinRMError" -ForegroundColor DarkRed
        Write-Host "DCOM : $($_.Exception.Message)" -ForegroundColor DarkRed
        Write-Host ""
        Write-Host "Check that the computer is on, reachable, and that you are an administrator on it." -ForegroundColor Yellow
        exit 1
    }
}

$Warnings = New-Object System.Collections.Generic.List[string]

try {
    $OS = Get-CimInstance -CimSession $Session -ClassName Win32_OperatingSystem -ErrorAction Stop
    $System = Get-CimInstance -CimSession $Session -ClassName Win32_ComputerSystem -ErrorAction Stop
    $BIOS = Get-CimInstance -CimSession $Session -ClassName Win32_BIOS -ErrorAction SilentlyContinue
    $CPUs = @(Get-CimInstance -CimSession $Session -ClassName Win32_Processor -ErrorAction SilentlyContinue)
    $Disks = @(Get-CimInstance -CimSession $Session -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue)

    # ----------------------------------------------------------
    # General
    # ----------------------------------------------------------
    Write-Host ""
    Write-Host "General" -ForegroundColor Cyan
    Write-Host "-------" -ForegroundColor Cyan

    Write-Host ("{0,-22}: {1}" -f "Computer", $OS.CSName)
    Write-Host ("{0,-22}: {1}" -f "Connected using", $Protocol)

    $SignedIn = if ($System.UserName) { $System.UserName } else { "Nobody at the console" }
    Write-Host ("{0,-22}: {1}" -f "Signed-in user", $SignedIn)

    Write-Host ("{0,-22}: {1} {2}" -f "Model", $System.Manufacturer, $System.Model)

    if ($BIOS -and $BIOS.SerialNumber) {
        Write-Host ("{0,-22}: {1}" -f "Serial number", $BIOS.SerialNumber)
    }

    Write-Host ("{0,-22}: {1} (build {2})" -f "Operating system", $OS.Caption, $OS.BuildNumber)

    # ----------------------------------------------------------
    # Uptime
    # ----------------------------------------------------------
    $Uptime = (Get-Date) - $OS.LastBootUpTime
    $UptimeText = "{0}d {1}h {2}m" -f $Uptime.Days, $Uptime.Hours, $Uptime.Minutes
    $UptimeWarning = $Uptime.TotalDays -ge $UptimeWarningDays

    Write-Host ""
    Write-Host "Uptime" -ForegroundColor Cyan
    Write-Host "------" -ForegroundColor Cyan
    Write-Host ("{0,-22}: {1}" -f "Last boot", $OS.LastBootUpTime.ToString("dd-MM-yyyy HH:mm"))
    Write-Check -Label "Uptime" -Value $UptimeText -Warning $UptimeWarning

    if ($UptimeWarning) {
        $Warnings.Add("Not restarted for $($Uptime.Days) days.")
    }

    # Pending restart.
    $CbsPending = Test-RemoteRegistryKey -CimSession $Session -KeyPath "SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
    $WuPending = Test-RemoteRegistryKey -CimSession $Session -KeyPath "SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"

    if ($null -eq $CbsPending -and $null -eq $WuPending) {
        Write-Host ("{0,-22}: {1}" -f "Restart pending", "Unable to check") -ForegroundColor DarkGray
    }
    elseif ($CbsPending -or $WuPending) {
        Write-Check -Label "Restart pending" -Value "Yes (Windows Update / servicing)" -Warning $true
        $Warnings.Add("A restart is pending to finish installing updates.")
    }
    else {
        Write-Check -Label "Restart pending" -Value "No"
    }

    # ----------------------------------------------------------
    # CPU and memory
    # ----------------------------------------------------------
    Write-Host ""
    Write-Host "Performance" -ForegroundColor Cyan
    Write-Host "-----------" -ForegroundColor Cyan

    $CpuLoads = @($CPUs | Where-Object { $null -ne $_.LoadPercentage } | ForEach-Object { $_.LoadPercentage })

    if ($CpuLoads.Count -gt 0) {
        $CpuLoad = [math]::Round(($CpuLoads | Measure-Object -Average).Average)
        $CpuWarning = $CpuLoad -ge $CpuWarningPercent
        Write-Check -Label "CPU load" -Value "$CpuLoad %" -Warning $CpuWarning

        if ($CpuWarning) {
            $Warnings.Add("CPU load is $CpuLoad %. Check Task Manager for the process using it.")
        }
    }
    else {
        Write-Host ("{0,-22}: {1}" -f "CPU load", "N/A") -ForegroundColor DarkGray
    }

    # Win32_OperatingSystem reports memory in KB.
    $TotalMemGB = [math]::Round($OS.TotalVisibleMemorySize / 1MB, 1)
    $FreeMemGB = [math]::Round($OS.FreePhysicalMemory / 1MB, 1)
    $UsedPercent = [math]::Round((1 - ($OS.FreePhysicalMemory / $OS.TotalVisibleMemorySize)) * 100)
    $MemoryWarning = $UsedPercent -ge $MemoryWarningPercent

    Write-Check -Label "Memory used" -Value ("{0} % ({1} GB free of {2} GB)" -f $UsedPercent, $FreeMemGB, $TotalMemGB) -Warning $MemoryWarning

    if ($MemoryWarning) {
        $Warnings.Add("Memory use is $UsedPercent %.")
    }

    # ----------------------------------------------------------
    # Disks
    # ----------------------------------------------------------
    Write-Host ""
    Write-Host "Disks" -ForegroundColor Cyan
    Write-Host "-----" -ForegroundColor Cyan

    if ($Disks.Count -eq 0) {
        Write-Host "No local disks returned." -ForegroundColor DarkGray
    }

    foreach ($Disk in $Disks | Sort-Object DeviceID) {
        if (-not $Disk.Size -or $Disk.Size -eq 0) {
            continue
        }

        $SizeGB = [math]::Round($Disk.Size / 1GB, 1)
        $FreeGB = [math]::Round($Disk.FreeSpace / 1GB, 1)
        $FreePercent = [math]::Round(($Disk.FreeSpace / $Disk.Size) * 100)
        $DiskWarning = ($FreePercent -lt $DiskWarningPercent) -or ($FreeGB -lt $DiskWarningGB)

        Write-Check `
            -Label ("Drive {0}" -f $Disk.DeviceID) `
            -Value ("{0} GB free of {1} GB ({2} %)" -f $FreeGB, $SizeGB, $FreePercent) `
            -Warning $DiskWarning

        if ($DiskWarning) {
            $Warnings.Add("Drive $($Disk.DeviceID) is low on space ($FreeGB GB free).")
        }
    }
}
catch {
    Write-Host ""
    Write-Host "Unable to read information from $Target." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    exit 1
}
finally {
    if ($Session) {
        Remove-CimSession -CimSession $Session -ErrorAction SilentlyContinue
    }
}

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
Write-Host ""
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "=======" -ForegroundColor Cyan
Write-Host ""

if ($Warnings.Count -eq 0) {
    Write-Host "No obvious problems found." -ForegroundColor Green
}
else {
    foreach ($Warning in $Warnings) {
        Write-Host "[WARNING] $Warning" -ForegroundColor Yellow
    }

    if ($Warnings -match "restart|Not restarted") {
        Write-Host ""
        Write-Host "A restart is the first step. Agree a time with the user before restarting." -ForegroundColor DarkGray
    }
}

exit 0
