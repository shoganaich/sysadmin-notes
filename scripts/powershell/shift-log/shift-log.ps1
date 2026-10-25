#Requires -Version 5.1

<#
.SYNOPSIS
    Terminal-based shift report editor with planned work and handover carry-over.

.DESCRIPTION
    Creates and resumes shift reports directly in Windows PowerShell.

    Each report uses:
    - A TXT file containing the readable report
    - A JSON file containing the editable state

    Features:
    - T1, T2, T3, or custom shift
    - Separate Planned Work and Shift Entries sections
    - Carry open items over from the previous report
    - Entries kept in time order, including shifts that pass midnight
    - Add, edit, delete, and reorder items
    - Convert planned work into a shift entry
    - Autosave after every change, written safely so a crash cannot corrupt a report
    - Validate, preview, and copy reports
    - Resume existing reports

.PARAMETER ReportDirectory
    Folder where reports are stored. Defaults to a "reports" folder next to the script.

.NOTES
    Compatible with Windows PowerShell 5.1.
#>

param(
    [string]$ReportDirectory
)

$ErrorActionPreference = "Stop"

$ShiftNames = @("T1", "T2", "T3")
$EntryCategories = @("Incident", "Request", "Planned work", "Escalation", "Information")
$EntryStatuses = @("Completed", "Pending", "Escalated", "Monitoring", "Information only")
$PlannedStatuses = @("Scheduled", "Pending", "In progress", "Blocked", "Cancelled")

# Entry statuses that still need attention, and the planned status they carry over as
$CarryOverStatuses = @{
    "Pending"    = "Pending"
    "Escalated"  = "Pending"
    "Monitoring" = "In progress"
}

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

function Wait-ForKey {
    param([string]$Message = "Press any key to continue...")

    Write-Host ""
    Write-Host $Message -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Write-Title {
    param([Parameter(Mandatory = $true)][string]$Text)

    Clear-Host
    Write-Host $Text -ForegroundColor Cyan
    Write-Host ("=" * $Text.Length)
    Write-Host ""
}

function Read-Text {
    <#
        Enter keeps the current value. With -AllowClear, "-" clears it.
        With -Required, an empty answer is only accepted when a current value exists.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [string]$Current = "",
        [switch]$Required,
        [switch]$AllowClear
    )

    $Label = $Prompt
    if ($Current) { $Label = "$Prompt [$Current]" }

    while ($true) {
        $Answer = Read-Host $Label
        if ($null -eq $Answer) { $Answer = "" }
        $Answer = $Answer.Trim()

        if ($AllowClear -and $Answer -eq "-") { return "" }
        if ($Answer) { return $Answer }
        if ($Current) { return $Current }
        if (-not $Required) { return "" }

        Write-Host "This field cannot be empty." -ForegroundColor Yellow
    }
}

function Read-Choice {
    <#
        Shows a numbered list. Accepts the number or the option text.
        Enter keeps the current value. -AllowOther adds a free-text option.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string[]]$Options,
        [string]$Current = "",
        [switch]$AllowOther
    )

    $OtherNumber = $Options.Count + 1

    while ($true) {
        Write-Host ""
        Write-Host $Title -ForegroundColor Cyan

        for ($Index = 0; $Index -lt $Options.Count; $Index++) {
            Write-Host ("  {0}. {1}" -f ($Index + 1), $Options[$Index])
        }
        if ($AllowOther) { Write-Host ("  {0}. Other" -f $OtherNumber) }

        if ($Current) {
            Write-Host "  Current: $Current (press Enter to keep it)" -ForegroundColor DarkGray
        }

        $Answer = Read-Host "Choice"
        if ($null -eq $Answer) { $Answer = "" }
        $Answer = $Answer.Trim()

        if (-not $Answer) {
            if ($Current) { return $Current }
            Write-Host "Please make a selection." -ForegroundColor Yellow
            continue
        }

        $Number = 0
        if ([int]::TryParse($Answer, [ref]$Number)) {
            if ($Number -ge 1 -and $Number -le $Options.Count) { return $Options[$Number - 1] }
            if ($AllowOther -and $Number -eq $OtherNumber) { return Read-Text -Prompt "Enter a name" -Required }
        }
        else {
            foreach ($Option in $Options) {
                if ($Option -eq $Answer) { return $Option }
            }
            if ($AllowOther -and $Answer -eq "Other") { return Read-Text -Prompt "Enter a name" -Required }
        }

        Write-Host "Invalid selection." -ForegroundColor Yellow
    }
}

function Read-Time {
    <# Accepts HH:mm, H:mm or HHmm. Enter keeps the current value. #>
    param(
        [string]$Prompt = "Time",
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Current
    )

    while ($true) {
        $Answer = Read-Host "$Prompt [$Current]"
        if ($null -eq $Answer) { $Answer = "" }
        $Answer = $Answer.Trim()

        if (-not $Answer) { return $Current }

        if ($Answer -match '^(\d{1,2}):?(\d{2})$') {
            $Hours = [int]$Matches[1]
            $Minutes = [int]$Matches[2]
            if ($Hours -le 23 -and $Minutes -le 59) {
                return "{0:D2}:{1:D2}" -f $Hours, $Minutes
            }
        }

        Write-Host "Invalid time. Use HH:mm, for example 14:05." -ForegroundColor Yellow
    }
}

function Read-ReportDate {
    $DefaultDate = Get-Date -Format "yyyy-MM-dd"

    while ($true) {
        $Answer = Read-Host "Report date [$DefaultDate]"
        if (-not $Answer) { return $DefaultDate }

        $ParsedDate = [DateTime]::MinValue
        $Valid = [DateTime]::TryParseExact(
            $Answer.Trim(),
            "yyyy-MM-dd",
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::None,
            [ref]$ParsedDate
        )

        if ($Valid) { return $ParsedDate.ToString("yyyy-MM-dd") }

        Write-Host "Invalid date. Use YYYY-MM-DD." -ForegroundColor Yellow
    }
}

function Read-YesNo {
    param([Parameter(Mandatory = $true)][string]$Prompt)

    $Answer = Read-Host "$Prompt (Y/N)"
    return [bool]($Answer -and $Answer.Trim().ToUpperInvariant() -in @("Y", "YES"))
}

# ---------------------------------------------------------------------------
# Items
# ---------------------------------------------------------------------------

function New-PlannedItem {
    param(
        [string]$Reference = "",
        [string]$Description = "",
        [string]$Status = ""
    )

    return [PSCustomObject]@{
        Reference   = $Reference
        Description = $Description
        Status      = $Status
    }
}

function New-Entry {
    param(
        [string]$Time = "",
        [string]$Category = "",
        [string]$Reference = "",
        [string]$Description = "",
        [string]$Status = ""
    )

    return [PSCustomObject]@{
        Time        = $Time
        Category    = $Category
        Reference   = $Reference
        Description = $Description
        Status      = $Status
    }
}

function Read-NewPlannedItem {
    Write-Title "Add Planned Work"
    Write-Host "Leave the description empty to cancel." -ForegroundColor DarkGray
    Write-Host ""

    $Description = Read-Text -Prompt "Description"
    if (-not $Description) { return $null }

    $Reference = Read-Text -Prompt "Ticket, change, or reference number (optional)"
    $Status = Read-Choice -Title "Status" -Options $PlannedStatuses

    return New-PlannedItem -Reference $Reference -Description $Description -Status $Status
}

function Edit-PlannedItem {
    param([Parameter(Mandatory = $true)]$Item)

    Write-Title "Edit Planned Work"
    Write-Host "Press Enter to keep a value. Type - to clear the reference." -ForegroundColor DarkGray
    Write-Host ""

    $Item.Description = Read-Text -Prompt "Description" -Current $Item.Description -Required
    $Item.Reference = Read-Text -Prompt "Reference" -Current $Item.Reference -AllowClear
    $Item.Status = Read-Choice -Title "Status" -Options $PlannedStatuses -Current $Item.Status
}

function Read-NewEntry {
    Write-Title "Add Shift Entry"
    Write-Host "Leave the description empty to cancel." -ForegroundColor DarkGray
    Write-Host ""

    $Description = Read-Text -Prompt "Description"
    if (-not $Description) { return $null }

    $Category = Read-Choice -Title "Category" -Options $EntryCategories -AllowOther
    $Reference = Read-Text -Prompt "Ticket or reference number (optional)"
    $Status = Read-Choice -Title "Status" -Options $EntryStatuses
    Write-Host ""
    $Time = Read-Time -Current (Get-Date -Format "HH:mm")

    return New-Entry -Time $Time -Category $Category -Reference $Reference `
        -Description $Description -Status $Status
}

function Edit-Entry {
    param([Parameter(Mandatory = $true)]$Entry)

    Write-Title "Edit Shift Entry"
    Write-Host "Press Enter to keep a value. Type - to clear the reference." -ForegroundColor DarkGray
    Write-Host ""

    $Entry.Description = Read-Text -Prompt "Description" -Current $Entry.Description -Required
    $Entry.Category = Read-Choice -Title "Category" -Options $EntryCategories -Current $Entry.Category -AllowOther
    $Entry.Reference = Read-Text -Prompt "Reference" -Current $Entry.Reference -AllowClear
    $Entry.Status = Read-Choice -Title "Status" -Options $EntryStatuses -Current $Entry.Status
    Write-Host ""
    $Entry.Time = Read-Time -Current $Entry.Time
}

function Format-PlannedLine {
    param([Parameter(Mandatory = $true)]$Item)

    $ReferenceText = ""
    if ($Item.Reference) { $ReferenceText = "[$($Item.Reference)] " }

    return "{0}{1} - {2}" -f $ReferenceText, $Item.Description, $Item.Status
}

function Format-EntryLine {
    param([Parameter(Mandatory = $true)]$Entry)

    $ReferenceText = ""
    if ($Entry.Reference) { $ReferenceText = " [$($Entry.Reference)]" }

    return "[{0}] [{1}] {2}{3} - {4}" -f `
        $Entry.Time, $Entry.Category, $Entry.Description, $ReferenceText, $Entry.Status
}

# ---------------------------------------------------------------------------
# Time ordering
# ---------------------------------------------------------------------------

function ConvertTo-Minutes {
    param([string]$Time)

    if ($Time -match '^(\d{2}):(\d{2})$') {
        return ([int]$Matches[1] * 60) + [int]$Matches[2]
    }
    return 0
}

function Get-ShiftMinute {
    <#
        Minutes since the report was started, wrapping past midnight, so a T3 entry
        at 00:30 sorts after one at 23:50. Times up to 12 hours before the report was
        started count as earlier, so entries logged late in the shift still sort first.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Time,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$StartTime
    )

    $Offset = ((ConvertTo-Minutes $Time) - (ConvertTo-Minutes $StartTime) + 1440) % 1440
    if ($Offset -gt 720) { $Offset -= 1440 }
    return $Offset
}

function Add-EntryInOrder {
    <# Inserts the entry after any entries with the same or an earlier time. Returns its index. #>
    param(
        [Parameter(Mandatory = $true)]$Report,
        [Parameter(Mandatory = $true)]$Entry
    )

    $Key = Get-ShiftMinute -Time $Entry.Time -StartTime $Report.StartTime

    for ($Index = 0; $Index -lt $Report.Entries.Count; $Index++) {
        $OtherKey = Get-ShiftMinute -Time $Report.Entries[$Index].Time -StartTime $Report.StartTime
        if ($OtherKey -gt $Key) {
            $Report.Entries.Insert($Index, $Entry)
            return $Index
        }
    }

    $null = $Report.Entries.Add($Entry)
    return $Report.Entries.Count - 1
}

# ---------------------------------------------------------------------------
# Reports
# ---------------------------------------------------------------------------

function Get-ReportText {
    param([Parameter(Mandatory = $true)]$Report)

    $Lines = New-Object System.Collections.Generic.List[string]

    $Lines.AddRange([string[]]@(
        "SHIFT REPORT",
        "============",
        "",
        "Date       : $($Report.ReportDate)",
        "Technician : $($Report.Technician)",
        "Shift      : $($Report.Shift)",
        "Updated    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "",
        "PLANNED WORK",
        "------------",
        ""
    ))

    if ($Report.PlannedWork.Count -eq 0) {
        $Lines.Add("No planned work recorded.")
    }
    for ($Index = 0; $Index -lt $Report.PlannedWork.Count; $Index++) {
        $Lines.Add("$($Index + 1). $(Format-PlannedLine -Item $Report.PlannedWork[$Index])")
    }

    $Lines.AddRange([string[]]@("", "SHIFT ENTRIES", "-------------", ""))

    if ($Report.Entries.Count -eq 0) {
        $Lines.Add("No shift entries recorded.")
    }
    for ($Index = 0; $Index -lt $Report.Entries.Count; $Index++) {
        $Lines.Add("$($Index + 1). $(Format-EntryLine -Entry $Report.Entries[$Index])")
    }

    $Lines.AddRange([string[]]@(
        "",
        "SUMMARY",
        "-------",
        "",
        ("{0,-16} : {1}" -f "Planned work", $Report.PlannedWork.Count),
        ("{0,-16} : {1}" -f "Shift entries", $Report.Entries.Count)
    ))

    foreach ($Status in $EntryStatuses) {
        $Count = @($Report.Entries | Where-Object { $_.Status -eq $Status }).Count
        $Lines.Add(("{0,-16} : {1}" -f $Status, $Count))
    }

    return $Lines.ToArray()
}

function Test-Report {
    param([Parameter(Mandatory = $true)]$Report)

    $Problems = New-Object System.Collections.Generic.List[string]

    if (-not $Report.Technician) { $Problems.Add("Technician is missing.") }
    if ($Report.ReportDate -notmatch '^\d{4}-\d{2}-\d{2}$') { $Problems.Add("Report date is invalid.") }
    if (-not $Report.Shift) { $Problems.Add("Shift is missing.") }

    for ($Index = 0; $Index -lt $Report.PlannedWork.Count; $Index++) {
        $Number = $Index + 1
        $Item = $Report.PlannedWork[$Index]
        if (-not $Item.Description) { $Problems.Add("Planned item $Number has no description.") }
        if (-not $Item.Status) { $Problems.Add("Planned item $Number has no status.") }
    }

    for ($Index = 0; $Index -lt $Report.Entries.Count; $Index++) {
        $Number = $Index + 1
        $Entry = $Report.Entries[$Index]
        if (-not $Entry.Description) { $Problems.Add("Shift entry $Number has no description.") }
        if (-not $Entry.Category) { $Problems.Add("Shift entry $Number has no category.") }
        if (-not $Entry.Status) { $Problems.Add("Shift entry $Number has no status.") }
        if ($Entry.Time -notmatch '^(?:[01]\d|2[0-3]):[0-5]\d$') {
            $Problems.Add("Shift entry $Number has an invalid time.")
        }
    }

    return ,$Problems.ToArray()
}

function Write-TextFile {
    <#
        Writes to a temporary file first and then swaps it in, so an interrupted
        save leaves the previous version intact instead of a half-written file.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text
    )

    $TempPath = "$Path.tmp"
    [System.IO.File]::WriteAllText($TempPath, $Text, (New-Object System.Text.UTF8Encoding $true))

    if (-not (Test-Path -LiteralPath $Path)) {
        [System.IO.File]::Move($TempPath, $Path)
        return
    }

    try {
        [System.IO.File]::Replace($TempPath, $Path, [NullString]::Value)
    }
    catch {
        # Some network shares do not support Replace
        Copy-Item -LiteralPath $TempPath -Destination $Path -Force
        Remove-Item -LiteralPath $TempPath -Force
    }
}

function Save-Report {
    param([Parameter(Mandatory = $true)]$Report)

    $Text = (Get-ReportText -Report $Report) -join "`r`n"
    Write-TextFile -Path $Report.ReportPath -Text "$Text`r`n"

    $State = [PSCustomObject]@{
        Version      = 3
        Technician   = $Report.Technician
        ReportDate   = $Report.ReportDate
        Shift        = $Report.Shift
        StartTime    = $Report.StartTime
        LastModified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        PlannedWork  = @($Report.PlannedWork)
        Entries      = @($Report.Entries)
    }

    Write-TextFile -Path $Report.StatePath -Text ($State | ConvertTo-Json -Depth 6)
}

function New-Report {
    param(
        [Parameter(Mandatory = $true)][string]$Directory,
        [Parameter(Mandatory = $true)][string]$Technician,
        [Parameter(Mandatory = $true)][string]$ReportDate,
        [Parameter(Mandatory = $true)][string]$Shift
    )

    $Now = Get-Date
    $SafeTechnician = $Technician -replace '[\\/:*?"<>| ]', '-'
    $SafeShift = $Shift -replace '[\\/:*?"<>| ]', '-'
    $BaseName = "{0}-{1}-{2}-{3}-shift-report" -f `
        $ReportDate, $SafeTechnician, $SafeShift, $Now.ToString("HHmmss")

    return [PSCustomObject]@{
        Technician  = $Technician
        ReportDate  = $ReportDate
        Shift       = $Shift
        StartTime   = $Now.ToString("HH:mm")
        PlannedWork = New-Object System.Collections.ArrayList
        Entries     = New-Object System.Collections.ArrayList
        ReportPath  = Join-Path $Directory "$BaseName.txt"
        StatePath   = Join-Path $Directory "$BaseName.json"
    }
}

function Import-Report {
    <# Loads a report state file. Reads version 2 files written by the original script too. #>
    param([Parameter(Mandatory = $true)][string]$StatePath)

    $State = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json

    $PlannedWork = New-Object System.Collections.ArrayList
    foreach ($Saved in @($State.PlannedWork)) {
        if ($null -eq $Saved) { continue }
        $null = $PlannedWork.Add((New-PlannedItem `
            -Reference ([string]$Saved.Reference) `
            -Description ([string]$Saved.Description) `
            -Status ([string]$Saved.Status)))
    }

    $Entries = New-Object System.Collections.ArrayList
    foreach ($Saved in @($State.Entries)) {
        if ($null -eq $Saved) { continue }
        $null = $Entries.Add((New-Entry `
            -Time ([string]$Saved.Time) `
            -Category ([string]$Saved.Category) `
            -Reference ([string]$Saved.Reference) `
            -Description ([string]$Saved.Description) `
            -Status ([string]$Saved.Status)))
    }

    # Older files have no StartTime: use the creation time in the file name, then the first entry
    $StartTime = [string]$State.StartTime
    if (-not $StartTime) {
        if ($StatePath -match '-(\d{2})(\d{2})\d{2}-shift-report\.json$') {
            $StartTime = "{0}:{1}" -f $Matches[1], $Matches[2]
        }
        elseif ($Entries.Count -gt 0) {
            $StartTime = $Entries[0].Time
        }
        else {
            $StartTime = "00:00"
        }
    }

    return [PSCustomObject]@{
        Technician  = [string]$State.Technician
        ReportDate  = [string]$State.ReportDate
        Shift       = [string]$State.Shift
        StartTime   = $StartTime
        PlannedWork = $PlannedWork
        Entries     = $Entries
        ReportPath  = [System.IO.Path]::ChangeExtension($StatePath, ".txt")
        StatePath   = $StatePath
    }
}

function Get-ReportFiles {
    param([Parameter(Mandatory = $true)][string]$Directory)

    return @(
        Get-ChildItem -LiteralPath $Directory -Filter "*-shift-report.json" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending
    )
}

function Get-OpenItems {
    <# Planned work that was not cancelled and entries still pending, escalated, or monitoring. #>
    param([Parameter(Mandatory = $true)]$Report)

    $Items = New-Object System.Collections.ArrayList

    foreach ($Item in $Report.PlannedWork) {
        if ($Item.Status -ne "Cancelled") {
            $null = $Items.Add((New-PlannedItem -Reference $Item.Reference `
                -Description $Item.Description -Status $Item.Status))
        }
    }

    foreach ($Entry in $Report.Entries) {
        if ($CarryOverStatuses.ContainsKey($Entry.Status)) {
            $null = $Items.Add((New-PlannedItem -Reference $Entry.Reference `
                -Description $Entry.Description -Status $CarryOverStatuses[$Entry.Status]))
        }
    }

    return ,$Items
}

# ---------------------------------------------------------------------------
# Screens
# ---------------------------------------------------------------------------

function Show-ReportPreview {
    param([Parameter(Mandatory = $true)]$Report)

    Write-Title "Report Preview"
    Get-ReportText -Report $Report | ForEach-Object { Write-Host $_ }
    Wait-ForKey -Message "Press any key to return..."
}

function Show-ValidationProblems {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Problems)

    Write-Title "Report Validation"

    if ($Problems.Count -eq 0) {
        Write-Host "The report data is valid." -ForegroundColor Green
    }
    else {
        Write-Host "The following problems were found:" -ForegroundColor Yellow
        Write-Host ""
        foreach ($Problem in $Problems) {
            Write-Host "- $Problem" -ForegroundColor Yellow
        }
    }
}

function Select-ExistingReport {
    param([Parameter(Mandatory = $true)][string]$Directory)

    $PageSize = 10
    $ShowAll = $false

    while ($true) {
        $Files = @(Get-ReportFiles -Directory $Directory)

        Write-Title "Resume Shift Report"

        if ($Files.Count -eq 0) {
            Write-Host "No resumable reports were found." -ForegroundColor Yellow
            Wait-ForKey
            return $null
        }

        $Shown = $Files.Count
        if (-not $ShowAll -and $Shown -gt $PageSize) { $Shown = $PageSize }

        for ($Index = 0; $Index -lt $Shown; $Index++) {
            $File = $Files[$Index]
            try {
                $State = Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                Write-Host ("{0,2}. {1} | {2} | {3}" -f ($Index + 1), $State.ReportDate, $State.Shift, $State.Technician)
                Write-Host ("    Planned: {0} | Entries: {1} | Modified: {2}" -f `
                    @($State.PlannedWork).Count, @($State.Entries).Count,
                    $File.LastWriteTime.ToString("yyyy-MM-dd HH:mm")) -ForegroundColor DarkGray
            }
            catch {
                Write-Host ("{0,2}. Unreadable report: {1}" -f ($Index + 1), $File.Name) -ForegroundColor Red
            }
        }

        Write-Host ""
        if ($Shown -lt $Files.Count) {
            Write-Host " A. Show all $($Files.Count) reports"
        }
        Write-Host " Q. Return to the main menu"
        Write-Host ""

        $Answer = Read-Host "Select a report"
        if ($null -eq $Answer) { $Answer = "" }
        $Answer = $Answer.Trim().ToUpperInvariant()

        if ($Answer -eq "Q") { return $null }
        if ($Answer -eq "A") { $ShowAll = $true; continue }

        $Number = 0
        if ([int]::TryParse($Answer, [ref]$Number) -and $Number -ge 1 -and $Number -le $Shown) {
            return $Files[$Number - 1]
        }

        Write-Host "Invalid selection." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
}

function Write-KeyHelp {
    param([Parameter(Mandatory = $true)][string[]]$Keys)

    # Keys alternate: key, label, key, label...
    for ($Index = 0; $Index -lt $Keys.Count; $Index += 2) {
        Write-Host "[$($Keys[$Index])] " -ForegroundColor Yellow -NoNewline
        Write-Host "$($Keys[$Index + 1])  " -ForegroundColor Gray -NoNewline
    }
    Write-Host ""
}

function Write-Section {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Items,
        [Parameter(Mandatory = $true)][scriptblock]$Format,
        [Parameter(Mandatory = $true)][string]$EmptyText,
        [bool]$Active,
        [int]$Selected
    )

    if ($Active) { Write-Host "$Title [ACTIVE]" -ForegroundColor Cyan }
    else { Write-Host $Title -ForegroundColor DarkCyan }
    Write-Host ("-" * $Title.Length)

    if ($Items.Count -eq 0) {
        Write-Host "  $EmptyText" -ForegroundColor DarkGray
    }

    for ($Index = 0; $Index -lt $Items.Count; $Index++) {
        $Text = "{0}. {1}" -f ($Index + 1), (& $Format $Items[$Index])
        if ($Active -and $Index -eq $Selected) { Write-Host "> $Text" -ForegroundColor Yellow }
        else { Write-Host "  $Text" }
    }
}

function Show-Editor {
    param([Parameter(Mandatory = $true)]$Report)

    $Active = "Planned"
    $Selected = @{ Planned = 0; Entries = 0 }
    $Message = ""
    $MessageColor = "Green"

    while ($true) {
        foreach ($Name in @("Planned", "Entries")) {
            if ($Name -eq "Planned") { $Count = $Report.PlannedWork.Count } else { $Count = $Report.Entries.Count }
            if ($Selected[$Name] -ge $Count) { $Selected[$Name] = [Math]::Max(0, $Count - 1) }
        }

        if ($Active -eq "Planned") { $List = $Report.PlannedWork } else { $List = $Report.Entries }
        $Index = $Selected[$Active]

        Write-Title "Shift Report Editor"
        Write-Host "Date       : $($Report.ReportDate)"
        Write-Host "Technician : $($Report.Technician)"
        Write-Host "Shift      : $($Report.Shift)"
        Write-Host "File       : $($Report.ReportPath)"
        Write-Host ""

        Write-Section -Title "PLANNED WORK" -Items $Report.PlannedWork `
            -Format { param($Item) Format-PlannedLine -Item $Item } `
            -EmptyText "No planned work recorded." `
            -Active ($Active -eq "Planned") -Selected $Selected["Planned"]
        Write-Host ""
        Write-Section -Title "SHIFT ENTRIES" -Items $Report.Entries `
            -Format { param($Entry) Format-EntryLine -Entry $Entry } `
            -EmptyText "No shift entries recorded." `
            -Active ($Active -eq "Entries") -Selected $Selected["Entries"]

        Write-Host ""
        Write-KeyHelp @("Tab", "Section", "Up/Down", "Select", "W", "Add plan", "A", "Add entry",
            "E", "Edit", "D", "Delete", "U/N", "Move")
        Write-KeyHelp @("X", "Plan to entry", "V", "Validate", "P", "Preview", "C", "Copy",
            "S", "Save", "Q", "Save and exit")

        if ($Message) {
            Write-Host ""
            Write-Host $Message -ForegroundColor $MessageColor
        }
        $Message = ""
        $MessageColor = "Green"

        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $Changed = $false

        switch ($Key.VirtualKeyCode) {
            9 {
                # Tab
                if ($Active -eq "Planned") { $Active = "Entries" } else { $Active = "Planned" }
            }
            38 {
                # Up
                if ($Index -gt 0) { $Selected[$Active] = $Index - 1 }
            }
            40 {
                # Down
                if ($Index -lt $List.Count - 1) { $Selected[$Active] = $Index + 1 }
            }
            87 {
                # W - add planned work
                $Item = Read-NewPlannedItem
                if ($Item) {
                    $null = $Report.PlannedWork.Add($Item)
                    $Selected["Planned"] = $Report.PlannedWork.Count - 1
                    $Active = "Planned"
                    $Changed = $true
                }
            }
            65 {
                # A - add shift entry
                $Entry = Read-NewEntry
                if ($Entry) {
                    $Selected["Entries"] = Add-EntryInOrder -Report $Report -Entry $Entry
                    $Active = "Entries"
                    $Changed = $true
                }
            }
            69 {
                # E - edit
                if ($List.Count -gt 0) {
                    if ($Active -eq "Planned") {
                        Edit-PlannedItem -Item $List[$Index]
                    }
                    else {
                        $Entry = $List[$Index]
                        $OldTime = $Entry.Time
                        Edit-Entry -Entry $Entry
                        if ($Entry.Time -ne $OldTime) {
                            $Report.Entries.RemoveAt($Index)
                            $Selected["Entries"] = Add-EntryInOrder -Report $Report -Entry $Entry
                        }
                    }
                    $Changed = $true
                }
            }
            68 {
                # D - delete
                if ($List.Count -gt 0) {
                    if ($Active -eq "Planned") { $Text = Format-PlannedLine -Item $List[$Index] }
                    else { $Text = Format-EntryLine -Entry $List[$Index] }

                    Write-Title "Delete Item"
                    Write-Host $Text
                    Write-Host ""
                    if (Read-YesNo -Prompt "Delete this item?") {
                        $List.RemoveAt($Index)
                        $Changed = $true
                    }
                }
            }
            85 {
                # U - move up
                if ($Index -gt 0) {
                    $Item = $List[$Index]
                    $List.RemoveAt($Index)
                    $List.Insert($Index - 1, $Item)
                    $Selected[$Active] = $Index - 1
                    $Changed = $true
                }
            }
            78 {
                # N - move down
                if ($Index -lt $List.Count - 1) {
                    $Item = $List[$Index]
                    $List.RemoveAt($Index)
                    $List.Insert($Index + 1, $Item)
                    $Selected[$Active] = $Index + 1
                    $Changed = $true
                }
            }
            88 {
                # X - convert planned work to a shift entry
                if ($Active -eq "Planned" -and $List.Count -gt 0) {
                    $Item = $List[$Index]

                    Write-Title "Convert Planned Work"
                    Write-Host (Format-PlannedLine -Item $Item)
                    Write-Host ""
                    Write-Host "This moves the item to the shift entries." -ForegroundColor DarkGray

                    $Status = Read-Choice -Title "Status" -Options $EntryStatuses
                    Write-Host ""
                    $Time = Read-Time -Current (Get-Date -Format "HH:mm")

                    $Entry = New-Entry -Time $Time -Category "Planned work" -Reference $Item.Reference `
                        -Description $Item.Description -Status $Status

                    $Selected["Entries"] = Add-EntryInOrder -Report $Report -Entry $Entry
                    $Report.PlannedWork.RemoveAt($Index)
                    $Active = "Entries"
                    $Changed = $true
                }
                elseif ($Active -eq "Entries") {
                    $Message = "Select a planned work item first (press Tab)."
                    $MessageColor = "Yellow"
                }
            }
            86 {
                # V - validate
                Show-ValidationProblems -Problems (Test-Report -Report $Report)
                Wait-ForKey -Message "Press any key to return..."
            }
            80 {
                # P - preview
                Save-Report -Report $Report
                Show-ReportPreview -Report $Report
            }
            67 {
                # C - copy
                Save-Report -Report $Report
                Set-Clipboard -Value ((Get-ReportText -Report $Report) -join "`r`n")
                $Message = "Report copied to the clipboard."
            }
            83 {
                # S - save
                Save-Report -Report $Report
                $Message = "Report saved at $(Get-Date -Format 'HH:mm:ss')."
            }
            81 {
                # Q - save and exit
                $Problems = Test-Report -Report $Report
                $MayExit = $true

                if ($Problems.Count -gt 0) {
                    Show-ValidationProblems -Problems $Problems
                    Write-Host ""
                    $MayExit = Read-YesNo -Prompt "Save and exit anyway?"
                }

                if ($MayExit) {
                    Save-Report -Report $Report
                    return
                }
            }
        }

        if ($Changed) { Save-Report -Report $Report }
    }
}

function Start-NewReport {
    param([Parameter(Mandatory = $true)][string]$Directory)

    # The most recent report supplies defaults and any open items to hand over
    $Previous = $null
    $Files = @(Get-ReportFiles -Directory $Directory)
    if ($Files.Count -gt 0) {
        try { $Previous = Import-Report -StatePath $Files[0].FullName } catch { $Previous = $null }
    }

    $DefaultTechnician = $env:USERNAME
    $DefaultShift = ""
    if ($Previous) {
        if ($Previous.Technician) { $DefaultTechnician = $Previous.Technician }
        $DefaultShift = $Previous.Shift
    }

    Write-Title "New Shift Report"

    $Technician = Read-Text -Prompt "Technician" -Current $DefaultTechnician -Required
    $ReportDate = Read-ReportDate
    $Shift = Read-Choice -Title "Shift" -Options $ShiftNames -Current $DefaultShift -AllowOther

    $Report = New-Report -Directory $Directory -Technician $Technician -ReportDate $ReportDate -Shift $Shift

    if ($Previous) {
        $OpenItems = Get-OpenItems -Report $Previous

        if ($OpenItems.Count -gt 0) {
            Write-Title "Open Items From The Previous Report"
            Write-Host "$($Previous.ReportDate) | $($Previous.Shift) | $($Previous.Technician)" -ForegroundColor DarkGray
            Write-Host ""
            for ($Index = 0; $Index -lt $OpenItems.Count; $Index++) {
                Write-Host ("{0}. {1}" -f ($Index + 1), (Format-PlannedLine -Item $OpenItems[$Index]))
            }
            Write-Host ""

            if (Read-YesNo -Prompt "Add these to planned work?") {
                $Report.PlannedWork.AddRange($OpenItems)
            }
        }
    }

    Save-Report -Report $Report
    Show-Editor -Report $Report
    return $Report
}

function Show-Saved {
    param([Parameter(Mandatory = $true)]$Report)

    Write-Title "Shift Report Saved"
    Write-Host "File: $($Report.ReportPath)" -ForegroundColor Cyan
    Wait-ForKey
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if (-not $ReportDirectory) { $ReportDirectory = Join-Path $PSScriptRoot "reports" }
$ReportDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ReportDirectory)

if (-not (Test-Path -LiteralPath $ReportDirectory)) {
    New-Item -Path $ReportDirectory -ItemType Directory -Force | Out-Null
}

while ($true) {
    Write-Title "Shift Report"
    Write-Host "1. Start a new report"
    Write-Host "2. Resume an existing report"
    Write-Host "3. Exit"
    Write-Host ""

    $Choice = Read-Host "Select an option"

    switch ($Choice) {
        "1" {
            $Report = Start-NewReport -Directory $ReportDirectory
            Show-Saved -Report $Report
        }
        "2" {
            $File = Select-ExistingReport -Directory $ReportDirectory
            if ($File) {
                try {
                    $Report = Import-Report -StatePath $File.FullName
                }
                catch {
                    Write-Title "Unable To Open Report"
                    Write-Host $File.Name
                    Write-Host ""
                    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
                    Wait-ForKey
                    $Report = $null
                }

                if ($Report) {
                    Show-Editor -Report $Report
                    Show-Saved -Report $Report
                }
            }
        }
        "3" { exit 0 }
        default {
            Write-Host "Invalid option." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}
