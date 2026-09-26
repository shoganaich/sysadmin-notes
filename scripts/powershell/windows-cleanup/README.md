# Windows Cleanup

PowerShell script for cleaning and maintaining a Windows workstation. It removes common temporary files and caches, runs basic storage optimization, and creates a report when finished.

## Script

```text
windows-cleanup.ps1
```

## Features

The script can perform the following tasks:

- Stop Microsoft Teams before clearing its cache
- Remove user temporary files
- Remove Windows temporary files
- Empty the Recycle Bin
- Clear the Windows Update download cache
- Clear the Delivery Optimization cache
- Clear Classic Teams and New Teams caches
- Analyze and clean the Windows Component Store
- Optimize the system drive
- Enable Storage Sense
- Find the 20 largest files on the system drive
- Generate cleanup and transcript logs
- Run optional Windows health checks
- Restart the computer when the cleanup is complete

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or later
- Administrator permissions

Run the script from the Windows session of the affected user. This is important because temporary files, Teams caches, the Recycle Bin, and Storage Sense settings are specific to the signed-in user.

## Running the Script

Open PowerShell as Administrator, go to the folder containing the script, and run:

```powershell
.\windows-cleanup.ps1
```

If script execution is blocked, allow scripts for the current PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then run the script again:

```powershell
.\windows-cleanup.ps1
```

## Interactive Mode

When the script is started without parameters, it runs in interactive mode.

You will be asked whether you want to:

- Run DISM, SFC, and CHKDSK health checks
- Run the advanced ResetBase cleanup
- Skip the largest-files scan
- Restart the computer when finished
- Continue with the cleanup

Answer each question with `Y` or `N`.

## Command-Line Options

### Run Windows health checks

Runs DISM RestoreHealth, System File Checker, and an online CHKDSK scan.

```powershell
.\windows-cleanup.ps1 -IncludeHealthChecks
```

These checks can take some time to complete.

### Run ResetBase cleanup

```powershell
.\windows-cleanup.ps1 -ResetBase
```

> **Warning:** ResetBase is irreversible. After it runs, currently installed Windows updates can no longer be uninstalled or reversed.

### Skip the largest-files scan

```powershell
.\windows-cleanup.ps1 -SkipLargestFilesScan
```

This can reduce the total runtime, especially on computers with large or slow drives.

### Restart after cleanup

```powershell
.\windows-cleanup.ps1 -RestartWhenDone
```

The computer will restart automatically after the script completes.

## Combining Options

Options can be used together.

For example, to run the health checks and restart afterward:

```powershell
.\windows-cleanup.ps1 -IncludeHealthChecks -RestartWhenDone
```

To run the cleanup without scanning the entire system drive for large files:

```powershell
.\windows-cleanup.ps1 -SkipLargestFilesScan
```

To run health checks without the largest-files scan:

```powershell
.\windows-cleanup.ps1 -IncludeHealthChecks -SkipLargestFilesScan
```

## Reports

The script saves its reports in:

```text
C:\Users\Public\WindowsCleanupReports
```

The folder can contain:

- A transcript log with the full script output
- A cleanup report with task results and recovered disk space
- A CSV file containing the 20 largest files found on the system drive

Report filenames include the date and time so that previous reports are not overwritten.

Example:

```text
CleanupLog_20260926_120000.txt
CleanupReport_20260926_120000.txt
LargestFiles_20260926_120000.csv
```

## Important Notes

- Always run the script as Administrator.
- Save your work before starting the cleanup.
- Close Microsoft Teams before running the script. The script will also try to stop it automatically.
- Files that are currently in use may be skipped.
- The largest-files scan may take several minutes.
- DISM, SFC, and CHKDSK are health checks, not cleanup tasks.
- A restart is recommended after running health checks or Windows component cleanup.
- Review the generated report for warnings or failed tasks.
- Use `-ResetBase` only when you understand the impact.

## Examples

Run the standard interactive cleanup:

```powershell
.\windows-cleanup.ps1
```

Run additional Windows health checks:

```powershell
.\windows-cleanup.ps1 -IncludeHealthChecks
```

Run health checks, skip the large-file scan, and restart when finished:

```powershell
.\windows-cleanup.ps1 `
    -IncludeHealthChecks `
    -SkipLargestFilesScan `
    -RestartWhenDone
```

Run the irreversible ResetBase cleanup:

```powershell
.\windows-cleanup.ps1 -