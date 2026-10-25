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

## Files

```text
shift-log.ps1
shift-log.bat
reports/
```

- `shift-log.ps1` contains the main script.
- `shift-log.bat` starts the script with a double-click.
- `reports/` is created on first run and holds your reports. It is ignored by Git.

## Usage

Double-click `shift-log.bat`, or run the script from PowerShell:

```powershell
.\shift-log.ps1
```

To keep reports somewhere else, such as a OneDrive or network folder:

```powershell
.\shift-log.ps1 -ReportDirectory "$env:OneDrive\Shift Reports"
```

### Starting a report

The script asks for:

1. Technician name. It defaults to the name on your last report.
2. Report date. It defaults to today.
3. Shift. It defaults to the shift on your last report.

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

When editing, press Enter to keep a value, or type `-` to clear the reference.

### Entry times

New entries default to the current time, and you can type a different one if you are logging something after the fact. `14:05`, `9:30`, and `1405` are all accepted.

Entries are placed in time order counted from when the report was started, so on a shift that runs past midnight `00:30` comes after `23:50`. Times up to 12 hours before the report was started count as earlier, so you can open the report late and still log what happened at the start of the shift. `U` and `N` still let you reorder entries by hand.

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

## Notes

Shift reports usually contain internal hostnames, ticket numbers, and names. Keep the `reports` folder out of version control and anywhere public.
