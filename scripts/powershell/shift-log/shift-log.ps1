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
    - Reuse recent entry descriptions when adding an entry
    - Search every report, including archived ones
    - Weekly, monthly, or custom-range summaries
    - Archive old reports into monthly folders

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

function Read-Date {
    <# Accepts YYYY-MM-DD. Enter keeps the default. #>
    param(
        [string]$Prompt = "Report date",
        [string]$Default = (Get-Date -Format "yyyy-MM-dd")
    )

    while ($true) {
        $Answer = Read-Host "$Prompt [$Default]"
        if (-not $Answer) { return $Default }

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
    <# Suggestions are recent entries; typing one's number reuses its description and category. #>
    param([AllowEmptyCollection()][object[]]$Suggestions = @())

    Write-Title "Add Shift Entry"

    if ($Suggestions.Count -gt 0) {
        Write-Host "Recent entries - type a number to reuse one:" -ForegroundColor Cyan
        for ($Index = 0; $Index -lt $Suggestions.Count; $Index++) {
            $Text = $Suggestions[$Index].Description
            if ($Text.Length -gt 70) { $Text = $Text.Substring(0, 67) + "..." }
            Write-Host ("  {0}. [{1}] {2}" -f ($Index + 1), $Suggestions[$Index].Category, $Text)
        }
        Write-Host ""
    }

    Write-Host "Leave the description empty to cancel." -ForegroundColor DarkGray
    Write-Host ""

    $Description = Read-Text -Prompt "Description"
    if (-not $Description) { return $null }

    $DefaultCategory = ""
    $Number = 0
    if ([int]::TryParse($Description, [ref]$Number) -and $Number -ge 1 -and $Number -le $Suggestions.Count) {
        $Picked = $Suggestions[$Number - 1]
        Write-Host "Press Enter to keep it, or type a new description." -ForegroundColor DarkGray
        $Description = Read-Text -Prompt "Description" -Current $Picked.Description -Required
        $DefaultCategory = $Picked.Category
    }

    $Category = Read-Choice -Title "Category" -Options $EntryCategories -Current $DefaultCategory -AllowOther
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
    <# Newest first. Without -Recurse only the main folder is read, so archived reports are left out. #>
    param(
        [Parameter(Mandatory = $true)][string]$Directory,
        [switch]$Recurse
    )

    return @(
        Get-ChildItem -LiteralPath $Directory -Filter "*-shift-report.json" -File -Recurse:$Recurse -ErrorAction SilentlyContinue |
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

function Copy-ToClipboard {
    <# Returns $true when copied. On Linux, Set-Clipboard needs a clipboard tool such as xclip. #>
    param([Parameter(Mandatory = $true)][string]$Text)

    try {
        Set-Clipboard -Value $Text
        return $true
    }
    catch {
        return $false
    }
}

# ---------------------------------------------------------------------------
# History: suggestions, search, summaries, and archiving
# ---------------------------------------------------------------------------

function Import-AllReports {
    <# Loads every report, archived ones included, oldest first. Unreadable files are skipped. #>
    param([Parameter(Mandatory = $true)][string]$Directory)

    $Reports = New-Object System.Collections.ArrayList
    foreach ($File in @(Get-ReportFiles -Directory $Directory -Recurse)) {
        try { $null = $Reports.Add((Import-Report -StatePath $File.FullName)) } catch { }
    }

    $Sorted = @($Reports | Sort-Object ReportDate, StartTime)
    return ,$Sorted
}

function Get-EntryHistory {
    <# Entries from the most recent other reports, newest first. #>
    param(
        [Parameter(Mandatory = $true)][string]$Directory,
        [string]$ExcludePath = "",
        [int]$ReportCount = 30
    )

    $Entries = New-Object System.Collections.ArrayList
    $Files = @(Get-ReportFiles -Directory $Directory -Recurse |
        Where-Object { $_.FullName -ne $ExcludePath } |
        Select-Object -First $ReportCount)

    foreach ($File in $Files) {
        try {
            $Saved = Import-Report -StatePath $File.FullName
            for ($Index = $Saved.Entries.Count - 1; $Index -ge 0; $Index--) {
                $null = $Entries.Add($Saved.Entries[$Index])
            }
        }
        catch { }
    }

    return ,$Entries
}

function Get-EntrySuggestions {
    <# Most often used descriptions first, then the most recent. The current report counts first. #>
    param(
        [Parameter(Mandatory = $true)]$Report,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$History,
        [int]$Limit = 9
    )

    $Candidates = New-Object System.Collections.ArrayList
    for ($Index = $Report.Entries.Count - 1; $Index -ge 0; $Index--) {
        $null = $Candidates.Add($Report.Entries[$Index])
    }
    $Candidates.AddRange($History)

    $Seen = @{}
    $Ranked = New-Object System.Collections.ArrayList
    for ($Index = 0; $Index -lt $Candidates.Count; $Index++) {
        $Entry = $Candidates[$Index]
        if (-not $Entry.Description) { continue }

        $Key = $Entry.Description.Trim().ToLowerInvariant()
        if ($Seen.ContainsKey($Key)) {
            $Seen[$Key].Uses++
        }
        else {
            $Stat = [PSCustomObject]@{ Entry = $Entry; Uses = 1; Order = $Index }
            $Seen[$Key] = $Stat
            $null = $Ranked.Add($Stat)
        }
    }

    $Top = @($Ranked |
        Sort-Object @{ Expression = "Uses"; Descending = $true }, @{ Expression = "Order" } |
        Select-Object -First $Limit)

    return ,@($Top | ForEach-Object { $_.Entry })
}

function ConvertTo-SearchText {
    <# Lower case without accents, so a search typed without accents still finds accented words. #>
    param([string]$Text)

    if (-not $Text) { return "" }

    $Builder = New-Object System.Text.StringBuilder
    foreach ($Char in $Text.Normalize([System.Text.NormalizationForm]::FormD).ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($Char) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            $null = $Builder.Append($Char)
        }
    }
    return $Builder.ToString().ToLowerInvariant()
}

function Find-ReportItems {
    <# Entries and planned work containing the term in any field. Newest first. #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Reports,
        [Parameter(Mandatory = $true)][string]$Term
    )

    $Needle = ConvertTo-SearchText $Term
    $Results = New-Object System.Collections.ArrayList

    foreach ($Report in $Reports) {
        foreach ($Item in $Report.PlannedWork) {
            $Haystack = ConvertTo-SearchText ("{0} {1} {2}" -f $Item.Description, $Item.Reference, $Item.Status)
            if ($Haystack.Contains($Needle)) {
                $null = $Results.Add([PSCustomObject]@{
                    Report = $Report
                    Line   = "[Planned] $(Format-PlannedLine -Item $Item)"
                })
            }
        }

        foreach ($Entry in $Report.Entries) {
            $Haystack = ConvertTo-SearchText ("{0} {1} {2} {3}" -f $Entry.Description, $Entry.Reference, $Entry.Category, $Entry.Status)
            if ($Haystack.Contains($Needle)) {
                $null = $Results.Add([PSCustomObject]@{
                    Report = $Report
                    Line   = Format-EntryLine -Entry $Entry
                })
            }
        }
    }

    # Reports are loaded oldest first
    $Results.Reverse()
    return ,$Results
}

function Get-AssetNames {
    <# Upper-case names that contain a number, such as QC09, ENG018 or PC012. Ticket numbers are left out. #>
    param([string]$Text)

    $Names = New-Object System.Collections.Generic.HashSet[string]
    foreach ($Match in [regex]::Matches([string]$Text, '\b[A-Z][A-Z0-9-]*[0-9][A-Z0-9-]*\b')) {
        $Name = $Match.Value.TrimEnd('-')
        if ($Name.Length -ge 3 -and $Name -notmatch '^(INC|REQ|RITM|CHG|TASK|PRB|SR)\d') {
            $null = $Names.Add($Name)
        }
    }
    return ,@($Names)
}

function Get-PeriodRange {
    $Today = (Get-Date).Date
    $WeekStart = $Today.AddDays(-((([int]$Today.DayOfWeek) + 6) % 7))
    $MonthStart = $Today.AddDays(1 - $Today.Day)

    $Choice = Read-Choice -Title "Period" -Options @("This week", "Last week", "This month", "Last month", "Custom range")

    switch ($Choice) {
        "This week"  { $From = $WeekStart; $To = $Today }
        "Last week"  { $From = $WeekStart.AddDays(-7); $To = $WeekStart.AddDays(-1) }
        "This month" { $From = $MonthStart; $To = $Today }
        "Last month" { $From = $MonthStart.AddMonths(-1); $To = $MonthStart.AddDays(-1) }
        default {
            Write-Host ""
            $Culture = [Globalization.CultureInfo]::InvariantCulture
            $From = [DateTime]::ParseExact((Read-Date -Prompt "From" -Default $MonthStart.ToString("yyyy-MM-dd")), "yyyy-MM-dd", $Culture)
            $To = [DateTime]::ParseExact((Read-Date -Prompt "To" -Default $Today.ToString("yyyy-MM-dd")), "yyyy-MM-dd", $Culture)
            if ($To -lt $From) { $From, $To = $To, $From }
        }
    }

    return [PSCustomObject]@{
        Label = $Choice
        From  = $From.ToString("yyyy-MM-dd")
        To    = $To.ToString("yyyy-MM-dd")
    }
}

function Get-SummaryText {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Reports,
        [Parameter(Mandatory = $true)]$Period
    )

    $InRange = @($Reports | Where-Object { $_.ReportDate -ge $Period.From -and $_.ReportDate -le $Period.To })

    $Entries = New-Object System.Collections.ArrayList
    foreach ($Report in $InRange) { $Entries.AddRange($Report.Entries) }

    $Lines = New-Object System.Collections.Generic.List[string]
    $Lines.AddRange([string[]]@(
        "SHIFT SUMMARY",
        "=============",
        "",
        "Period      : $($Period.Label) ($($Period.From) to $($Period.To))",
        "Reports     : $($InRange.Count)"
    ))

    if ($InRange.Count -eq 0) {
        $Lines.AddRange([string[]]@("", "No reports in this period."))
        return $Lines.ToArray()
    }

    $Shifts = @($InRange | Group-Object Shift | Sort-Object Name | ForEach-Object { "$($_.Name) x$($_.Count)" })
    $Technicians = @($InRange | ForEach-Object { $_.Technician } | Sort-Object -Unique)
    $Lines.Add("Shifts      : $($Shifts -join ', ')")
    $Lines.Add("Technicians : $($Technicians -join ', ')")

    # Entries by status, and how many were resolved without carrying over
    $Lines.AddRange([string[]]@("", "ENTRIES", "-------", ""))
    $Lines.Add(("{0,-17} : {1}" -f "Total", $Entries.Count))
    foreach ($Status in $EntryStatuses) {
        $Count = @($Entries | Where-Object { $_.Status -eq $Status }).Count
        $Lines.Add(("{0,-17} : {1}" -f $Status, $Count))
    }

    $Actionable = @($Entries | Where-Object { $_.Status -ne "Information only" }).Count
    if ($Actionable -gt 0) {
        $Completed = @($Entries | Where-Object { $_.Status -eq "Completed" }).Count
        $Percent = [Math]::Round(100 * $Completed / $Actionable)
        $Lines.Add("")
        $Lines.Add(("{0,-17} : {1} of {2} ({3}%)" -f "Resolved on shift", $Completed, $Actionable, $Percent))
    }

    $Lines.AddRange([string[]]@("", "BY CATEGORY", "-----------", ""))
    if ($Entries.Count -eq 0) {
        $Lines.Add("No entries recorded.")
    }
    $Categories = @($Entries | Group-Object Category |
        Sort-Object @{ Expression = "Count"; Descending = $true }, @{ Expression = "Name" })
    foreach ($Group in $Categories) {
        $Lines.Add(("{0,-17} : {1}" -f $Group.Name, $Group.Count))
    }

    # Hosts and assets named in two or more entries
    $Mentions = @{}
    foreach ($Entry in $Entries) {
        foreach ($Name in (Get-AssetNames -Text $Entry.Description)) {
            $Mentions[$Name] = 1 + [int]$Mentions[$Name]
        }
    }
    $Top = @($Mentions.GetEnumerator() | Where-Object { $_.Value -ge 2 } |
        Sort-Object @{ Expression = "Value"; Descending = $true }, @{ Expression = "Key" } |
        Select-Object -First 10)

    $Lines.AddRange([string[]]@("", "MOST MENTIONED HOSTS", "--------------------", ""))
    if ($Top.Count -eq 0) {
        $Lines.Add("No host came up in more than one entry.")
    }
    foreach ($Mention in $Top) {
        $Lines.Add(("{0,-17} : {1} entries" -f $Mention.Key, $Mention.Value))
    }

    # Whatever the last report of the period would hand over
    $Last = $InRange[$InRange.Count - 1]
    $Open = Get-OpenItems -Report $Last

    $Lines.AddRange([string[]]@("", "STILL OPEN AT END OF PERIOD", "---------------------------", ""))
    $Lines.Add("From the $($Last.ReportDate) $($Last.Shift) report:")
    if ($Open.Count -eq 0) {
        $Lines.Add("Nothing open.")
    }
    for ($Index = 0; $Index -lt $Open.Count; $Index++) {
        $Lines.Add("$($Index + 1). $(Format-PlannedLine -Item $Open[$Index])")
    }

    $Lines.AddRange([string[]]@("", "Generated   : $(Get-Date -Format 'yyyy-MM-dd HH:mm')"))
    return $Lines.ToArray()
}

function Show-Search {
    param([Parameter(Mandatory = $true)][string]$Directory)

    $Reports = Import-AllReports -Directory $Directory

    while ($true) {
        Write-Title "Search Reports"
        Write-Host "Searches every field of $($Reports.Count) reports, archived ones included." -ForegroundColor DarkGray
        Write-Host "Case and accents are ignored. Leave empty to return." -ForegroundColor DarkGray
        Write-Host ""

        $Term = Read-Text -Prompt "Search for"
        if (-not $Term) { return }

        $Results = Find-ReportItems -Reports $Reports -Term $Term

        Write-Host ""
        if ($Results.Count -eq 0) {
            Write-Host "No matches for '$Term'." -ForegroundColor Yellow
        }
        else {
            Write-Host "$($Results.Count) match(es) for '$Term', newest first:" -ForegroundColor Green
            Write-Host ""
            foreach ($Result in $Results) {
                Write-Host ("{0} {1,-3} " -f $Result.Report.ReportDate, $Result.Report.Shift) -ForegroundColor DarkGray -NoNewline
                Write-Host $Result.Line
            }
        }

        Wait-ForKey -Message "Press any key to search again..."
    }
}

function Show-Summary {
    param([Parameter(Mandatory = $true)][string]$Directory)

    Write-Title "Shift Summary"
    $Period = Get-PeriodRange
    $Lines = Get-SummaryText -Reports (Import-AllReports -Directory $Directory) -Period $Period
    $Text = ($Lines -join "`r`n") + "`r`n"
    $Message = ""
    $MessageColor = "Green"

    while ($true) {
        Write-Title "Shift Summary"
        foreach ($Line in $Lines) { Write-Host $Line }
        Write-Host ""
        Write-KeyHelp @("C", "Copy", "S", "Save to file", "Any other key", "Return")

        if ($Message) {
            Write-Host ""
            Write-Host $Message -ForegroundColor $MessageColor
        }
        $Message = ""
        $MessageColor = "Green"

        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        switch ($Key.VirtualKeyCode) {
            67 {
                if (Copy-ToClipboard -Text $Text) {
                    $Message = "Summary copied to the clipboard."
                }
                else {
                    $Message = "Could not reach the clipboard. Save it to a file instead."
                    $MessageColor = "Yellow"
                }
            }
            83 {
                $Folder = Join-Path $Directory "summaries"
                if (-not (Test-Path -LiteralPath $Folder)) {
                    New-Item -Path $Folder -ItemType Directory -Force | Out-Null
                }
                $Path = Join-Path $Folder ("summary-{0}-to-{1}.txt" -f $Period.From, $Period.To)
                Write-TextFile -Path $Path -Text $Text
                $Message = "Saved to $Path"
            }
            default { return }
        }
    }
}

function Invoke-Archive {
    <# Moves reports dated before the cutoff into archive\YYYY-MM folders. #>
    param([Parameter(Mandatory = $true)][string]$Directory)

    Write-Title "Archive Old Reports"
    Write-Host "Archived reports move to monthly folders under 'archive'." -ForegroundColor DarkGray
    Write-Host "They leave the resume list but Search and Summary still use them." -ForegroundColor DarkGray
    Write-Host ""

    $Days = 0
    while ($true) {
        $Answer = Read-Text -Prompt "Archive reports older than how many days" -Current "60"
        if ([int]::TryParse($Answer, [ref]$Days) -and $Days -ge 1) { break }
        Write-Host "Enter a whole number of days, 1 or more." -ForegroundColor Yellow
    }

    $Cutoff = (Get-Date).Date.AddDays(-$Days).ToString("yyyy-MM-dd")
    $Old = @(Get-ReportFiles -Directory $Directory |
        Where-Object { $_.Name -match '^(\d{4}-\d{2}-\d{2})-' -and $Matches[1] -lt $Cutoff } |
        Sort-Object Name)

    Write-Host ""
    if ($Old.Count -eq 0) {
        Write-Host "No reports dated before $Cutoff." -ForegroundColor Yellow
        Wait-ForKey
        return
    }

    Write-Host ("{0} report(s) dated before {1}, from {2} to {3}." -f `
        $Old.Count, $Cutoff, $Old[0].Name.Substring(0, 10), $Old[$Old.Count - 1].Name.Substring(0, 10))
    Write-Host ""
    if (-not (Read-YesNo -Prompt "Move them to the archive?")) { return }

    $ArchiveRoot = Join-Path $Directory "archive"
    $Moved = 0
    $Skipped = 0

    foreach ($File in $Old) {
        $Target = Join-Path $ArchiveRoot $File.Name.Substring(0, 7)
        if (-not (Test-Path -LiteralPath $Target)) {
            New-Item -Path $Target -ItemType Directory -Force | Out-Null
        }

        if (Test-Path -LiteralPath (Join-Path $Target $File.Name)) {
            $Skipped++
            continue
        }

        $TextFile = [System.IO.Path]::ChangeExtension($File.FullName, ".txt")
        Move-Item -LiteralPath $File.FullName -Destination $Target
        if ((Test-Path -LiteralPath $TextFile) -and -not (Test-Path -LiteralPath (Join-Path $Target (Split-Path -Leaf $TextFile)))) {
            Move-Item -LiteralPath $TextFile -Destination $Target
        }
        $Moved++
    }

    Write-Host ""
    Write-Host "Archived $Moved report(s) to $ArchiveRoot." -ForegroundColor Green
    if ($Skipped -gt 0) {
        Write-Host "$Skipped report(s) skipped because the archive already has a file with the same name." -ForegroundColor Yellow
    }
    Wait-ForKey
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
        if (Test-Path -LiteralPath (Join-Path $Directory "archive")) {
            Write-Host "Archived reports are not listed here. Search still finds them." -ForegroundColor DarkGray
            Write-Host ""
        }
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

    # Earlier entries, loaded once, for the suggestions shown when adding an entry
    $History = Get-EntryHistory -Directory (Split-Path -Parent $Report.StatePath) -ExcludePath $Report.StatePath

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
                $Entry = Read-NewEntry -Suggestions (Get-EntrySuggestions -Report $Report -History $History)
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
                if (Copy-ToClipboard -Text ((Get-ReportText -Report $Report) -join "`r`n")) {
                    $Message = "Report copied to the clipboard."
                }
                else {
                    $Message = "Could not reach the clipboard. Use Preview or the saved .txt file instead."
                    $MessageColor = "Yellow"
                }
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
    $ReportDate = Read-Date
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
    Write-Host "3. Search reports"
    Write-Host "4. Summary"
    Write-Host "5. Archive old reports"
    Write-Host "6. Exit"
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
        "3" { Show-Search -Directory $ReportDirectory }
        "4" { Show-Summary -Directory $ReportDirectory }
        "5" { Invoke-Archive -Directory $ReportDirectory }
        "6" { exit 0 }
        default {
            Write-Host "Invalid option." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}
