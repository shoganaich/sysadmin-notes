<#
.SYNOPSIS
    Windows Cleanup and Optimization Script

.DESCRIPTION
    Performs Windows cleanup and optimization tasks, including:

    - Cleaning user and Windows temporary files
    - Emptying the Recycle Bin
    - Clearing the Windows Update download cache
    - Clearing the Delivery Optimization cache
    - Clearing Classic Teams and New Teams caches
    - Cleaning and analyzing the Windows Component Store
    - Optimizing the system drive
    - Enabling Storage Sense
    - Finding the 20 largest files
    - Generating cleanup and transcript reports

    Optional health checks include:

    - DISM RestoreHealth
    - System File Checker
    - CHKDSK online scan

.PARAMETER IncludeHealthChecks
    Runs DISM RestoreHealth, SFC, and CHKDSK.

.PARAMETER ResetBase
    Performs irreversible Windows Component Store cleanup.

    WARNING:
    This removes the ability to uninstall currently installed
    Windows updates.

.PARAMETER SkipLargestFilesScan
    Skips the scan for the 20 largest files on the system drive.

.PARAMETER RestartWhenDone
    Restarts the computer after the script completes.

.EXAMPLE
    .\Windows-Cleanup.ps1

.EXAMPLE
    .\Windows-Cleanup.ps1 -IncludeHealthChecks

.EXAMPLE
    .\Windows-Cleanup.ps1 -SkipLargestFilesScan

.EXAMPLE
    .\Windows-Cleanup.ps1 -IncludeHealthChecks -RestartWhenDone

.NOTES
    Run this script as Administrator.

    Run it in the affected user's Windows session to clean that user's:
    - Temporary files
    - Teams cache
    - Recycle Bin
    - Storage Sense settings
#>

[CmdletBinding()]
param (
    [switch]$IncludeHealthChecks,
    [switch]$ResetBase,
    [switch]$SkipLargestFilesScan,
    [switch]$RestartWhenDone,
    [switch]$Interactive
)

$ErrorActionPreference = "Continue"

# ============================================================
# Administrator validation
# ============================================================

$CurrentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()

$CurrentPrincipal = New-Object `
    Security.Principal.WindowsPrincipal($CurrentIdentity)

$AdministratorRole = `
    [System.Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $CurrentPrincipal.IsInRole($AdministratorRole)) {
    Write-Host ""
    Write-Host "This script must be run as Administrator." `
        -ForegroundColor Red

    Write-Host "Right-click PowerShell and select Run as administrator." `
        -ForegroundColor Yellow

    Write-Host ""
    exit 1
}

# ============================================================
# Variables
# ============================================================

$SystemDrive = $env:SystemDrive
$DriveLetter = $SystemDrive.TrimEnd(":")
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"

$ReportFolder = Join-Path `
    -Path $env:PUBLIC `
    -ChildPath "WindowsCleanupReports"

$LogFile = Join-Path `
    -Path $ReportFolder `
    -ChildPath "CleanupLog_$TimeStamp.txt"

$ReportFile = Join-Path `
    -Path $ReportFolder `
    -ChildPath "CleanupReport_$TimeStamp.txt"

$LargestFilesReport = Join-Path `
    -Path $ReportFolder `
    -ChildPath "LargestFiles_$TimeStamp.csv"

$ScriptStartTime = Get-Date

$StartFreeSpace = 0
$EndFreeSpace = 0
$RecoveredGB = 0

$Results = [System.Collections.Generic.List[object]]::new()

$WindowsUpdateServiceWasRunning = $false
$BitsServiceWasRunning = $false
$TranscriptStarted = $false

# ============================================================
# Create report folder
# ============================================================

try {
    if (-not (Test-Path -LiteralPath $ReportFolder)) {
        New-Item `
            -Path $ReportFolder `
            -ItemType Directory `
            -Force |
            Out-Null
    }
}
catch {
    Write-Host "Unable to create the report folder:" `
        -ForegroundColor Red

    Write-Host $ReportFolder -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}

# ============================================================
# Helper functions
# ============================================================

function Add-CleanupResult {
    param (
        [Parameter(Mandatory)]
        [string]$Task,

        [Parameter(Mandatory)]
        [ValidateSet("Completed", "Warning", "Failed", "Skipped")]
        [string]$Status,

        [string]$Details = ""
    )

    $Results.Add(
        [PSCustomObject]@{
            Time    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Task    = $Task
            Status  = $Status
            Details = $Details
        }
    )
}

function Write-Step {
    param (
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor DarkGray

    Write-Host $Message -ForegroundColor Cyan

    Write-Host "============================================================" `
        -ForegroundColor DarkGray
}

function Set-InteractiveOptions {
    if (-not $Interactive -and $PSBoundParameters.Count -gt 0) {
        return
    }

    Write-Host ""
    Write-Host "Interactive mode is enabled by default." -ForegroundColor Cyan
    Write-Host "Select the cleanup actions to run." -ForegroundColor Cyan

    $response = Read-Host "Run health checks (DISM / SFC / CHKDSK)? [Y/N]"
    $script:IncludeHealthChecks = ($response -match '^(Y|YES)$')

    $response = Read-Host "Run ResetBase cleanup? WARNING: this is irreversible [Y/N]"
    $script:ResetBase = ($response -match '^(Y|YES)$')

    $response = Read-Host "Skip the largest-files scan? [Y/N]"
    $script:SkipLargestFilesScan = ($response -match '^(Y|YES)$')

    $response = Read-Host "Restart the computer when finished? [Y/N]"
    $script:RestartWhenDone = ($response -match '^(Y|YES)$')

    $response = Read-Host "Proceed with cleanup now? [Y/N]"
    if ($response -notmatch '^(Y|YES)$') {
        Write-Host "Cleanup cancelled by user." -ForegroundColor Yellow
        exit 0
    }
}

function Clear-FolderContent {
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$TaskName
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "Path not found: $Path" -ForegroundColor Yellow

        Add-CleanupResult `
            -Task $TaskName `
            -Status "Skipped" `
            -Details "Path not found: $Path"

        return
    }

    try {
        $Items = Get-ChildItem `
            -LiteralPath $Path `
            -Force `
            -ErrorAction SilentlyContinue

        if (-not $Items) {
            Write-Host "The folder is already empty." `
                -ForegroundColor Green

            Add-CleanupResult `
                -Task $TaskName `
                -Status "Completed" `
                -Details "The folder was already empty."

            return
        }

        $Items |
            Remove-Item `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue

        Write-Host "Cleanup completed: $Path" `
            -ForegroundColor Green

        Add-CleanupResult `
            -Task $TaskName `
            -Status "Completed" `
            -Details (
                "Removed available files from $Path. " +
                "Files currently in use may have been skipped."
            )
    }
    catch {
        Write-Host "Unable to fully clean: $Path" `
            -ForegroundColor Yellow

        Write-Host $_.Exception.Message `
            -ForegroundColor Yellow

        Add-CleanupResult `
            -Task $TaskName `
            -Status "Warning" `
            -Details $_.Exception.Message
    }
}

function Invoke-NativeCommand {
    param (
        [Parameter(Mandatory)]
        [string]$TaskName,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    try {
        Write-Host "Running: $FilePath $($Arguments -join ' ')" `
            -ForegroundColor DarkGray

        & $FilePath @Arguments

        $ExitCode = $LASTEXITCODE

        if ($ExitCode -eq 0) {
            Add-CleanupResult `
                -Task $TaskName `
                -Status "Completed" `
                -Details "Exit code: $ExitCode"
        }
        elseif ($ExitCode -eq 3010) {
            Write-Host "$TaskName completed. A restart is required." `
                -ForegroundColor Yellow

            Add-CleanupResult `
                -Task $TaskName `
                -Status "Warning" `
                -Details "Exit code 3010. A restart is required."
        }
        else {
            Write-Host "$TaskName completed with exit code $ExitCode." `
                -ForegroundColor Yellow

            Add-CleanupResult `
                -Task $TaskName `
                -Status "Warning" `
                -Details "Command completed with exit code $ExitCode."
        }
    }
    catch {
        Write-Host "$TaskName failed." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red

        Add-CleanupResult `
            -Task $TaskName `
            -Status "Failed" `
            -Details $_.Exception.Message
    }
}

# ============================================================
# Start transcript logging
# ============================================================

try {
    Start-Transcript `
        -Path $LogFile `
        -Force |
        Out-Null

    $TranscriptStarted = $true
}
catch {
    Write-Host "Unable to start transcript logging." `
        -ForegroundColor Yellow

    Write-Host $_.Exception.Message `
        -ForegroundColor Yellow
}

Set-InteractiveOptions

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Green

Write-Host " WINDOWS CLEANUP AND OPTIMIZATION STARTED" `
    -ForegroundColor Green

Write-Host "============================================================" `
    -ForegroundColor Green

Write-Host "Computer : $env:COMPUTERNAME"
Write-Host "User     : $env:USERNAME"
Write-Host "Started  : $ScriptStartTime"
Write-Host "Reports  : $ReportFolder"

# ============================================================
# Record starting free space
# ============================================================

try {
    $StartFreeSpace = (Get-PSDrive -Name $DriveLetter).Free

    $StartFreeSpaceGB = [math]::Round(
        $StartFreeSpace / 1GB,
        2
    )

    Write-Host "Free space before cleanup: $StartFreeSpaceGB GB" `
        -ForegroundColor Cyan

    Add-CleanupResult `
        -Task "Check starting free space" `
        -Status "Completed" `
        -Details "Starting free space: $StartFreeSpaceGB GB"
}
catch {
    Write-Host "Unable to record starting free space." `
        -ForegroundColor Yellow

    Add-CleanupResult `
        -Task "Check starting free space" `
        -Status "Warning" `
        -Details $_.Exception.Message
}

# ============================================================
# 1. Stop Microsoft Teams
# ============================================================

Write-Step "1. Stopping Microsoft Teams"

try {
    $TeamsProcesses = Get-Process `
        -Name "Teams", "ms-teams" `
        -ErrorAction SilentlyContinue

    if ($TeamsProcesses) {
        $TeamsProcesses |
            Stop-Process `
                -Force `
                -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 2

        Write-Host "Microsoft Teams processes stopped." `
            -ForegroundColor Green

        Add-CleanupResult `
            -Task "Stop Microsoft Teams" `
            -Status "Completed" `
            -Details "Teams processes were stopped."
    }
    else {
        Write-Host "Microsoft Teams is not running." `
            -ForegroundColor Green

        Add-CleanupResult `
            -Task "Stop Microsoft Teams" `
            -Status "Completed" `
            -Details "No Teams processes were running."
    }
}
catch {
    Write-Host "Unable to stop all Teams processes." `
        -ForegroundColor Yellow

    Add-CleanupResult `
        -Task "Stop Microsoft Teams" `
        -Status "Warning" `
        -Details $_.Exception.Message
}

# ============================================================
# 2. Clean user temporary files
# ============================================================

Write-Step "2. Cleaning User Temporary Files"

Clear-FolderContent `
    -Path $env:TEMP `
    -TaskName "Clean user temporary files"

# ============================================================
# 3. Clean Windows temporary files
# ============================================================

Write-Step "3. Cleaning Windows Temporary Files"

$WindowsTempPath = Join-Path `
    -Path $env:windir `
    -ChildPath "Temp"

Clear-FolderContent `
    -Path $WindowsTempPath `
    -TaskName "Clean Windows temporary files"

# ============================================================
# 4. Empty Recycle Bin
# ============================================================

Write-Step "4. Emptying Recycle Bin"

try {
    Clear-RecycleBin `
        -Force `
        -ErrorAction Stop

    Write-Host "Recycle Bin emptied." `
        -ForegroundColor Green

    Add-CleanupResult `
        -Task "Empty Recycle Bin" `
        -Status "Completed" `
        -Details "Recycle Bin cleanup completed."
}
catch {
    $RecycleError = $_.Exception.Message

    if (
        $RecycleError -match "cannot find" -or
        $RecycleError -match "does not exist" -or
        $RecycleError -match "already empty"
    ) {
        Write-Host "The Recycle Bin is already empty." `
            -ForegroundColor Green

        Add-CleanupResult `
            -Task "Empty Recycle Bin" `
            -Status "Completed" `
            -Details "The Recycle Bin was already empty."
    }
    else {
        Write-Host "The Recycle Bin could not be fully emptied." `
            -ForegroundColor Yellow

        Write-Host $RecycleError `
            -ForegroundColor Yellow

        Add-CleanupResult `
            -Task "Empty Recycle Bin" `
            -Status "Warning" `
            -Details $RecycleError
    }
}

# ============================================================
# 5. Clear Windows Update cache
# ============================================================

Write-Step "5. Clearing Windows Update Cache"

try {
    $WindowsUpdateService = Get-Service `
        -Name "wuauserv" `
        -ErrorAction SilentlyContinue

    $BitsService = Get-Service `
        -Name "bits" `
        -ErrorAction SilentlyContinue

    if (
        $null -ne $WindowsUpdateService -and
        $WindowsUpdateService.Status -eq "Running"
    ) {
        $WindowsUpdateServiceWasRunning = $true
    }

    if (
        $null -ne $BitsService -and
        $BitsService.Status -eq "Running"
    ) {
        $BitsServiceWasRunning = $true
    }

    Write-Host "Stopping Windows Update services..."

    Stop-Service `
        -Name "wuauserv" `
        -Force `
        -ErrorAction SilentlyContinue

    Stop-Service `
        -Name "bits" `
        -Force `
        -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 3

    $UpdateCachePath = Join-Path `
        -Path $env:windir `
        -ChildPath "SoftwareDistribution\Download"

    Clear-FolderContent `
        -Path $UpdateCachePath `
        -TaskName "Clear Windows Update cache"
}
catch {
    Write-Host "Windows Update cache cleanup failed." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    Add-CleanupResult `
        -Task "Clear Windows Update cache" `
        -Status "Failed" `
        -Details $_.Exception.Message
}
finally {
    Write-Host "Restoring Windows Update service states..."

    try {
        if ($WindowsUpdateServiceWasRunning) {
            Start-Service `
                -Name "wuauserv" `
                -ErrorAction SilentlyContinue
        }

        if ($BitsServiceWasRunning) {
            Start-Service `
                -Name "bits" `
                -ErrorAction SilentlyContinue
        }

        Add-CleanupResult `
            -Task "Restore Windows Update services" `
            -Status "Completed" `
            -Details (
                "Services that were running before cleanup " +
                "were started again."
            )
    }
    catch {
        Write-Host "Unable to restore one or more update services." `
            -ForegroundColor Yellow

        Add-CleanupResult `
            -Task "Restore Windows Update services" `
            -Status "Warning" `
            -Details $_.Exception.Message
    }
}

# ============================================================
# 6. Clear Delivery Optimization cache
# ============================================================

Write-Step "6. Clearing Delivery Optimization Cache"

try {
    $DeliveryOptimizationCommand = Get-Command `
        -Name "Delete-DeliveryOptimizationCache" `
        -ErrorAction SilentlyContinue

    if ($DeliveryOptimizationCommand) {
        Delete-DeliveryOptimizationCache `
            -Force `
            -ErrorAction Stop

        Write-Host "Delivery Optimization cache cleared." `
            -ForegroundColor Green

        Add-CleanupResult `  -Task "Clear Delivery Optimization cache" `
            -Status "Completed" `
            -Details "Delivery Optimization cache cleanup completed."
    }
    else {
        Write-Host "Delivery Optimization command is not available." `
            -ForegroundColor Yellow

        Add-CleanupResult `
            -Task "Clear Delivery Optimization cache" `
            -Status "Skipped" `
            -Details (
                "Delete-DeliveryOptimizationCache is not available " +
                "on this system."
            )
    }
}
catch {
    Write-Host "Delivery Optimization cache could not be fully cleared." `
        -ForegroundColor Yellow

    Add-CleanupResult `
        -Task "Clear Delivery Optimization cache" `
        -Status "Warning" `
        -Details $_.Exception.Message
}

# ============================================================
# 7. Clear Classic Teams cache
# ============================================================

Write-Step "7. Clearing Classic Microsoft Teams Cache"

$ClassicTeamsCache = Join-Path `
    -Path $env:APPDATA `
    -ChildPath "Microsoft\Teams"

Clear-FolderContent `
    -Path $ClassicTeamsCache `
    -TaskName "Clear Classic Teams cache"

# ============================================================
# 8. Clear New Teams cache
# ============================================================

Write-Step "8. Clearing New Microsoft Teams Cache"

$NewTeamsCache = Join-Path `
    -Path $env:LOCALAPPDATA `
    -ChildPath "Packages\MSTeams_8wekyb3d8bbwe\LocalCache"

Clear-FolderContent `
    -Path $NewTeamsCache `
    -TaskName "Clear New Teams cache"

# ============================================================
# 9. Analyze Component Store before cleanup
# ============================================================

Write-Step "9. Analyzing Windows Component Store"

Invoke-NativeCommand `
    -TaskName "Analyze Component Store before cleanup" `
    -FilePath "dism.exe" `
    -Arguments @(
        "/Online",
        "/Cleanup-Image",
        "/AnalyzeComponentStore"
    )

# ============================================================
# 10. Clean Component Store
# ============================================================

Write-Step "10. Cleaning Windows Component Store"

Invoke-NativeCommand `
    -TaskName "Clean Windows Component Store" `
    -FilePath "dism.exe" `
    -Arguments @(
        "/Online",
        "/Cleanup-Image",
        "/StartComponentCleanup"
    )

# ============================================================
# 11. Optional ResetBase cleanup
# ============================================================

if ($ResetBase) {
    Write-Step "11. Running Irreversible ResetBase Cleanup"

    Write-Host "WARNING: ResetBase is irreversible." `
        -ForegroundColor Red

    Write-Host (
        "Existing Windows updates cannot be uninstalled afterward."
    ) -ForegroundColor Red

    Invoke-NativeCommand `
        -TaskName "DISM ResetBase cleanup" `
        -FilePath "dism.exe" `
        -Arguments @(
            "/Online",
            "/Cleanup-Image",
            "/StartComponentCleanup",
            "/ResetBase"
        )
}
else {
    Write-Step "11. ResetBase Cleanup Skipped"

    Write-Host "ResetBase was not requested." `
        -ForegroundColor Yellow

    Write-Host (
        "Use -ResetBase only when irreversible cleanup is required."
    ) -ForegroundColor Yellow

    Add-CleanupResult `
        -Task "DISM ResetBase cleanup" `
        -Status "Skipped" `
        -Details "The -ResetBase parameter was not specified."
}

# ============================================================
# 12. Analyze Component Store after cleanup
# ============================================================

Write-Step "12. Analyzing Component Store After Cleanup"

Invoke-NativeCommand `
    -TaskName "Analyze Component Store after cleanup" `
    -FilePath "dism.exe" `
    -Arguments @(
        "/Online",
        "/Cleanup-Image",
        "/AnalyzeComponentStore"
    )

# ============================================================
# 13. Optimize system drive
# ============================================================

Write-Step "13. Optimizing System Drive"

try {
    Optimize-Volume `
        -DriveLetter $DriveLetter `
        -Verbose `
        -ErrorAction Stop

    Write-Host "Drive optimization completed." `
        -ForegroundColor Green

    Add-CleanupResult `
        -Task "Optimize system drive" `
        -Status "Completed" `
        -Details (
            "Windows selected the appropriate optimization " +
            "method for the drive."
        )
}
catch {
    Write-Host "Drive optimization could not be completed." `
        -ForegroundColor Yellow

    Write-Host $_.Exception.Message `
        -ForegroundColor Yellow

    Add-CleanupResult `
        -Task "Optimize system drive" `
        -Status "Warning" `
        -Details $_.Exception.Message
}

# ============================================================
# 14. Enable Storage Sense
# ============================================================

Write-Step "14. Enabling Storage Sense"

try {
    $StorageSensePath = (
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\" +
        "StorageSense\Parameters\StoragePolicy"
    )

    if (-not (Test-Path -LiteralPath $StorageSensePath)) {
        New-Item `
            -Path $StorageSensePath `
            -Force |
            Out-Null
    }

    New-ItemProperty `
        -Path $StorageSensePath `
        -Name "01" `
        -PropertyType DWord `
        -Value 1 `
        -Force `
        -ErrorAction Stop |
        Out-Null

    Write-Host "Storage Sense enabled for the current user." `
        -ForegroundColor Green

    Add-CleanupResult `
        -Task "Enable Storage Sense" `
        -Status "Completed" `
        -Details "Storage Sense was enabled for $env:USERNAME."
}
catch {
    Write-Host "Storage Sense could not be enabled." `
        -ForegroundColor Yellow

    Add-CleanupResult `
        -Task "Enable Storage Sense" `
        -Status "Warning" `
        -Details $_.Exception.Message
}

# ============================================================
# 15. Optional system health checks
# ============================================================

if ($IncludeHealthChecks) {
    Write-Step "15A. Repairing Windows Component Store"

    Invoke-NativeCommand `
        -TaskName "DISM RestoreHealth" `
        -FilePath "dism.exe" `
        -Arguments @(
            "/Online",
            "/Cleanup-Image",
            "/RestoreHealth"
        )

    Write-Step "15B. Checking Windows System Files"

    Invoke-NativeCommand `
        -TaskName "System File Checker" `
        -FilePath "sfc.exe" `
        -Arguments @(
            "/scannow"
        )

    Write-Step "15C. Scanning System Drive"

    Invoke-NativeCommand `
        -TaskName "CHKDSK online scan" `
        -FilePath "chkdsk.exe" `
        -Arguments @(
            "$SystemDrive",
            "/scan"
        )
}
else {
    Write-Step "15. System Health Checks Skipped"

    Write-Host (
        "DISM RestoreHealth, SFC, and CHKDSK were not requested."
    ) -ForegroundColor Yellow

    Write-Host (
        "Use -IncludeHealthChecks to run the additional checks."
    ) -ForegroundColor Yellow

    Add-CleanupResult `
        -Task "DISM RestoreHealth" `
        -Status "Skipped" `
        -Details "The -IncludeHealthChecks parameter was not specified."

    Add-CleanupResult `
        -Task "System File Checker" `
        -Status "Skipped" `
        -Details "The -IncludeHealthChecks parameter was not specified."

    Add-CleanupResult `
        -Task "CHKDSK online scan" `
        -Status "Skipped" `
        -Details "The -IncludeHealthChecks parameter was not specified."
}

# ============================================================
# 16. Generate largest files report
# ============================================================

if (-not $SkipLargestFilesScan) {
    Write-Step "16. Finding the 20 Largest Files"

    Write-Host "This scan may take several minutes." `
        -ForegroundColor Yellow

    try {
        Get-ChildItem `
            -Path "$SystemDrive\" `
            -Recurse `
            -File `
            -Force `
            -ErrorAction SilentlyContinue |
            Sort-Object -Property Length -Descending |
            Select-Object `
                -First 20 `
                -Property FullName,
                @{
                    Name = "SizeGB"
                    Expression = {
                        [math]::Round($_.Length / 1GB, 2)
                    }
                },
                @{
                    Name = "LastModified"
                    Expression = {
                        $_.LastWriteTime
                    }
                } |
            Export-Csv `
                -Path $LargestFilesReport `
                -NoTypeInformation `
                -Encoding UTF8

        Write-Host "Largest files report created:" `
            -ForegroundColor Green

        Write-Host $LargestFilesReport `
            -ForegroundColor Cyan

        Add-CleanupResult `
            -Task "Generate largest files report" `
            -Status "Completed" `
            -Details $LargestFilesReport
    }
    catch {
        Write-Host "Unable to complete the largest-files scan." `
            -ForegroundColor Yellow

        Add-CleanupResult `
            -Task "Generate largest files report" `
            -Status "Warning" `
            -Details $_.Exception.Message
    }
}
else {
    Write-Step "16. Largest Files Scan Skipped"

    Write-Host "The largest-files scan was skipped." `
        -ForegroundColor Yellow

    Add-CleanupResult `
        -Task "Generate largest files report" `
        -Status "Skipped" `
        -Details "The -SkipLargestFilesScan parameter was specified."
}

# ============================================================
# 17. Calculate recovered disk space
# ============================================================

Write-Step "17. Calculating Recovered Disk Space"

try {
    $EndFreeSpace = (Get-PSDrive -Name $DriveLetter).Free

    $StartFreeSpaceGB = [math]::Round(
        $StartFreeSpace / 1GB,
        2
    )

    $EndFreeSpaceGB = [math]::Round(
        $EndFreeSpace / 1GB,
        2
    )

    $RecoveredGB = [math]::Round(
        ($EndFreeSpace - $StartFreeSpace) / 1GB,
        2
    )

    Write-Host "Free space before : $StartFreeSpaceGB GB"
    Write-Host "Free space after  : $EndFreeSpaceGB GB"

    Write-Host "Recovered space   : $RecoveredGB GB" `
        -ForegroundColor Cyan

    Add-CleanupResult `
        -Task "Calculate recovered space" `
        -Status "Completed" `
        -Details "Recovered space: $RecoveredGB GB"
}
catch {
    Write-Host "Unable to calculate recovered disk space." `
        -ForegroundColor Yellow

    Add-CleanupResult `
        -Task "Calculate recovered space" `
        -Status "Warning" `
        -Details $_.Exception.Message
}

# ============================================================
# 18. Generate cleanup report
# ============================================================

Write-Step "18. Generating Cleanup Report"

$ScriptEndTime = Get-Date
$Duration = $ScriptEndTime - $ScriptStartTime

$CompletedCount = @(
    $Results |
        Where-Object {
            $_.Status -eq "Completed"
        }
).Count

$WarningCount = @(
    $Results |
        Where-Object {
            $_.Status -eq "Warning"
        }
).Count

$FailedCount = @(
    $Results |
        Where-Object {
            $_.Status -eq "Failed"
        }
).Count

$SkippedCount = @(
    $Results |
        Where-Object {
            $_.Status -eq "Skipped"
        }
).Count

$ResultText = $Results |
    ForEach-Object {
        "[{0}] {1}: {2} - {3}" -f `
            $_.Time,
            $_.Status,
            $_.Task,
            $_.Details
    } |
    Out-String

if (Test-Path -LiteralPath $LargestFilesReport) {
    $LargestFilesReportValue = $LargestFilesReport
}
else {
    $LargestFilesReportValue = "Not generated"
}

$StartFreeSpaceReportGB = [math]::Round(
    $StartFreeSpace / 1GB,
    2
)

$EndFreeSpaceReportGB = [math]::Round(
    $EndFreeSpace / 1GB,
    2
)

$Report = @"
============================================================
WINDOWS CLEANUP AND OPTIMIZATION REPORT
============================================================

Computer Name       : $env:COMPUTERNAME
Current User        : $env:USERNAME
User Profile        : $env:USERPROFILE
System Drive        : $SystemDrive
Start Time          : $ScriptStartTime
End Time            : $ScriptEndTime
Duration            : $($Duration.ToString())

Free Space Before   : $StartFreeSpaceReportGB GB
Free Space After    : $EndFreeSpaceReportGB GB
Recovered Space     : $RecoveredGB GB

Completed Tasks     : $CompletedCount
Warnings            : $WarningCount
Failed Tasks        : $FailedCount
Skipped Tasks       : $SkippedCount

Health Checks       : $IncludeHealthChecks
ResetBase Used      : $ResetBase
Automatic Restart   : $RestartWhenDone

Transcript Log:
$LogFile

Largest Files Report:
$LargestFilesReportValue

============================================================
TASK RESULTS
============================================================

$ResultText
============================================================
END OF REPORT
============================================================
"@

try {
    $Report |
        Out-File `
            -FilePath $ReportFile `
            -Encoding UTF8 `
            -Force

    Write-Host "Cleanup report created:" `
        -ForegroundColor Green

    Write-Host $ReportFile `
        -ForegroundColor Cyan
}
catch {
    Write-Host "Unable to save the cleanup report." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red
}

# ============================================================
# Completion summary
# ============================================================

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Green

Write-Host " CLEANUP AND OPTIMIZATION COMPLETE" `
    -ForegroundColor Green

Write-Host "============================================================" `
    -ForegroundColor Green

Write-Host "Recovered space : $RecoveredGB GB" `
    -ForegroundColor Cyan

Write-Host "Completed tasks : $CompletedCount"

Write-Host "Warnings        : $WarningCount" `
    -ForegroundColor Yellow

Write-Host "Failed tasks    : $FailedCount" `
    -ForegroundColor Red

Write-Host "Skipped tasks   : $SkippedCount"

Write-Host ""

Write-Host "Report          : $ReportFile" `
    -ForegroundColor Cyan

Write-Host "Transcript      : $LogFile" `
    -ForegroundColor Cyan

if (Test-Path -LiteralPath $LargestFilesReport) {
    Write-Host "Largest files   : $LargestFilesReport" `
        -ForegroundColor Cyan
}

Write-Host ""

# ============================================================
# Stop transcript
# ============================================================

if ($TranscriptStarted) {
    try {
        Stop-Transcript | Out-Null
    }
    catch {
        # The transcript may already have stopped.
    }
}

# ============================================================
# Optional restart
# ============================================================

if ($RestartWhenDone) {
    Write-Host "The computer will restart in 10 seconds." `
        -ForegroundColor Yellow

    Write-Host "Press Ctrl+C to cancel the restart." `
        -ForegroundColor Yellow

    Start-Sleep -Seconds 10
    Restart-Computer -Force
}
else {
    Write-Host "A restart is recommended." `
        -ForegroundColor Yellow

    Write-Host (
        "Use -RestartWhenDone to restart automatically next time."
    ) -ForegroundColor Yellow
}