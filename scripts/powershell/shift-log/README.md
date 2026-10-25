# Shift Log

A terminal-based shift report editor for Windows PowerShell.

During a shift you log what you worked on, and at the end you have a clean, consistent report ready to paste into an email or a handover ticket. Open items carry over to the next shift's report, so nothing gets lost at handover.

## What it does

- Starts a new report or resumes an existing one
- Supports T1, T2, T3, or a custom shift name
- Keeps two sections:
  - **Planned Work**: things you need to do this shift
  - **Shift Entries**: what actually happened, with a time, category, and status
- Offers to carry open items from the previous report into the new one
- Keeps entries in time order, including shifts that pass midnight
- Converts a planned item into a shift entry once it is done
- Saves after every change
- Validates, previews, and copies the report to the clipboard
- Suggests your most-used entries so regular tasks take one keypress
- Searches every report, archived ones included
- Builds weekly, monthly, or custom-range summaries
- Archives old reports into monthly folders

## Files

```text
shift-log.ps1
shift-log.bat
shift-log-config.json
reports/
├── archive/
│   └── 2026-09/
└── summaries/
```

- `shift-log.ps1` contains the main script.
- `shift-log.bat` starts the script with a double-click.
- `shift-log-config.json` holds your name, shifts, categories, and other defaults. It is created on first run and ignored by Git.
- `reports/` is created on first run and holds your reports. It is ignored by Git.
- `reports/archive/` holds archived reports, one folder per month.
- `reports/summaries/` holds summaries you save to a file.

## Usage

Double-click `shift-log.bat`, or run the script from PowerShell:

```powershell
.\shift-log.ps1
```

To keep reports somewhere else for one run, such as a OneDrive or network folder:

```powershell
.\shift-log.ps1 -ReportDirectory "$env:OneDrive\Shift Reports"
```

To use a different config file, for example one per job:

```powershell
.\shift-log.ps1 -ConfigPath "D:\Configs\shift-log-config.json"
```

## Configuration

The first time the script runs, it creates `shift-log-config.json` next to itself with these defaults:

```json
{
  "technician": "",
  "defaultShift": "",
  "shifts": ["T1", "T2", "T3"],
  "entryCategories": ["Incident", "Request", "Planned work", "Escalation", "Information"],
  "reportDirectory": "",
  "resumeListSize": 10,
  "suggestionCount": 9,
  "archiveAfterDays": 60,
  "ticketPrefixes": ["INC", "REQ", "RITM", "CHG", "TASK", "PRB", "SR"]
}
```

Edit it in any text editor. The changes apply the next time you start the script. The main menu shows which config file and report folder are in use.

| Setting | What it does |
|---|---|
| `technician` | Your name, offered as the default on every new report. Empty uses the name from your last report, then your Windows user name. |
| `defaultShift` | Shift offered by default. Empty uses the shift from your last report. |
| `shifts` | The shift names in the menu. **Other** is always added for anything else. |
| `entryCategories` | The categories offered for entries. **Other** is always added. |
| `reportDirectory` | Where reports are stored. Empty uses `reports` next to the script. A relative path is relative to the script folder, and variables like `%OneDrive%` are expanded. The `-ReportDirectory` parameter overrides it. |
| `resumeListSize` | How many reports the resume list shows before you press `A`. |
| `suggestionCount` | How many recent entries are suggested when adding an entry. `0` turns suggestions off. |
| `archiveAfterDays` | Default age, in days, offered when archiving. |
| `ticketPrefixes` | Ticket number prefixes that the summary leaves out of the host list. |

Any setting you leave out uses its default, so the file can be as short as:

```json
{
  "technician": "Jane Doe",
  "shifts": ["Morning", "Afternoon", "Night"],
  "entryCategories": ["Incident", "Request", "RDT Replacement", "GPS Report"]
}
```

If the file has a mistake, the script lists each problem and stops instead of guessing. Fix it, or delete the file to have it recreated with the defaults.

The entry and planned work statuses are not configurable. The carry-over to the next shift, the summary's resolved-on-shift figure, and validation all depend on them.

Changing `shifts` or `entryCategories` does not change existing reports. Old reports keep the names they were saved with, and Search and Summary still include them.

### Main menu

| Option | What it does |
|---|---|
| 1. Start a new report | Creates today's report and opens the editor |
| 2. Resume an existing report | Lists your latest reports (10 by default), or all of them with `A` |
| 3. Search reports | Finds entries and planned work across every report |
| 4. Summary | Totals for a week, a month, or any date range |
| 5. Archive old reports | Moves old reports out of the resume list |
| 6. Exit | |

### Starting a report

The script asks for:

1. Technician name. It defaults to `technician` in the config file, or the name on your last report.
2. Report date. It defaults to today.
3. Shift. It defaults to `defaultShift` in the config file, or the shift on your last report.

If the previous report still has open items, they are listed and you can add them to planned work. Open items are:

| In the previous report | Carried over as planned work with status |
|---|---|
| Planned work not marked Cancelled | Its existing status |
| Shift entry marked Pending | Pending |
| Shift entry marked Escalated | Pending |
| Shift entry marked Monitoring | In progress |

### Editor keys

| Key | Action |
|---|---|
| `Tab` | Switch between Planned Work and Shift Entries |
| `Up` / `Down` | Select an item |
| `W` | Add planned work |
| `A` | Add a shift entry |
| `E` | Edit the selected item |
| `D` | Delete the selected item |
| `U` / `N` | Move the selected item up or down |
| `X` | Turn the selected planned item into a shift entry |
| `V` | Check the report for missing information |
| `P` | Preview the report |
| `C` | Copy the report to the clipboard |
| `S` | Save |
| `Q` | Save and exit |

When adding an item, leave the description empty to cancel.

### Reusing recent entries

When you press `A`, the descriptions you use most (9 by default, set by `suggestionCount`) are listed above the prompt, most frequent first, then most recent. They come from the current report and your last 30 reports. Type a number to reuse one:

```text
Recent entries - type a number to reuse one:
  1. [Incident] TV REEFERS screen adjusted
  2. [Request] Badge reader reset at gate 3
  3. [Incident] PC012 offline, damaged network cable replaced

Description: 1
Press Enter to keep it, or type a new description.
Description [TV REEFERS screen adjusted]:
```

The category defaults to the one you used last time, so Enter keeps that too. The reference, status, and time are asked as usual.

When editing, press Enter to keep a value, or type `-` to clear the reference.

### Entry times

New entries default to the current time, and you can type a different one if you are logging something after the fact. `14:05`, `9:30`, and `1405` are all accepted.

Entries are placed in time order counted from when the report was started, so on a shift that runs past midnight `00:30` comes after `23:50`. Times up to 12 hours before the report was started count as earlier, so you can open the report late and still log what happened at the start of the shift. `U` and `N` still let you reorder entries by hand.

## Search

Option 3 searches the description, reference, category, and status of every entry and planned item, in all reports including archived ones. Results are listed newest first with their date and shift:

```text
Search for: pc012

2 match(es) for 'pc012', newest first:

2026-10-13 T3  [16:35] [Incident] PC012 offline, damaged network cable replaced [INC0045678] - Completed
2026-09-28 T2  [09:10] [Incident] PC012 no network after move - Escalated
```

Case and accents are ignored, so `conexao` finds `conexão`.

## Summary

Option 4 asks for a period (this week, last week, this month, last month, or a custom range) and shows:

- How many reports and shifts were worked, and by whom
- Entries by status, and the share resolved on shift (completed out of everything except Information only)
- Entries by category
- The hosts mentioned in two or more entries
- What was still open at the end of the period, taken from the last report in it

Hosts are picked up from descriptions as upper-case names that contain a number, such as `QC09`, `ENG018`, or `PC012`. Ticket numbers starting with one of the `ticketPrefixes` in the config file are left out.

Press `C` to copy the summary or `S` to save it to `reports/summaries/`.

## Archiving

Option 5 moves reports older than a number of days you choose (60 by default, set by `archiveAfterDays`) into `reports/archive/YYYY-MM/`. It shows how many reports will move and asks before moving anything.

Archived reports leave the resume list but are still used by Search and Summary. Nothing is deleted. To resume an archived report, move its two files back into `reports/`.

## Example report

```text
SHIFT REPORT
============

Date       : 2026-10-13
Technician : Jane Doe
Shift      : T3
Updated    : 2026-10-13 23:58:12

PLANNED WORK
------------

1. [CHG0012345] Replace switch in the warehouse office - Scheduled

SHIFT ENTRIES
-------------

1. [16:13] [Incident] Meeting room display not detecting laptop - Completed
2. [16:35] [Incident] PC012 offline, damaged network cable replaced [INC0045678] - Completed
3. [21:10] [Escalation] Printer queue stuck on PRT004 [INC0045690] - Escalated

SUMMARY
-------

Planned work     : 1
Shift entries    : 3
Completed        : 2
Pending          : 0
Escalated        : 1
Monitoring       : 0
Information only : 0
```

## How reports are stored

Each report is two files with the same name:

```text
2026-10-13-Jane-Doe-T3-154432-shift-report.txt
2026-10-13-Jane-Doe-T3-154432-shift-report.json
```

- The `.txt` file is the readable report.
- The `.json` file is what the editor loads when you resume.

Saves are written to a temporary file first and then swapped in, so closing the window or losing power in the middle of a save cannot leave a half-written report.

Reports from the earlier version of this script can still be resumed.

## Requirements

- Windows
- Windows PowerShell 5.1 or later
- A real console window. The editor reads single key presses, so it does not work in the PowerShell ISE.

It also runs on PowerShell 7 on Linux. Copying needs `xclip` or `wl-clipboard` installed there; without one the script says it could not reach the clipboard instead of copying.

## Notes

Shift reports usually contain internal hostnames, ticket numbers, and names. Keep the `reports` folder and your `shift-log-config.json` out of version control and anywhere public.
