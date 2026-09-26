# Windows PC Cleanup and Optimization Procedure

## Purpose

Use this procedure to remove temporary files and cached data, recover disk space, and carry out basic Windows maintenance.

Some sections are optional and should only be used when needed.

> **Automated option:** The PowerShell version of this procedure is available in [windows-cleanup](/scripts/powershell/windows-cleanup/). The folder contains `windows-cleanup.ps1` and its README.

## Before You Start

- Sign in with the affected user's account.
- Save any open work.
- Close running applications.
- Open PowerShell or Command Prompt as Administrator.
- Record the available disk space before starting.
- Do not delete files or profiles unless you know they are no longer needed.

To check the current free space in PowerShell:

```powershell
Get-PSDrive C |
    Select-Object Name,
    @{Name = "FreeSpaceGB"; Expression = {
        [math\]::Round($_.Free / 1GB, 2)
    }}
```

---

## 1. Run Disk Cleanup

Press `Win + R`, enter the following command, and select **OK**:

```cmd
cleanmgr.exe
```

Select the items that are safe to remove. These may include:

- Temporary files
- Windows Error Reporting files
- Thumbnails
- Temporary Internet Files
- Delivery Optimization Files
- Recycle Bin
- Temporary Windows installation files

Select **Clean up system files** to check for additional items.

> **Important:** Removing **Previous Windows Installation(s)** deletes the files used to return to an earlier Windows version. Only select this item if a rollback is no longer required.

---

## 2. Remove Temporary Files

### User temporary files

Press `Win + R` and enter:

```text
%temp%
```

Delete the contents of the folder.

Files that are currently in use may not be deleted. Select **Skip** if Windows reports that a file is open or locked.

### Windows temporary files

Open the following folder:

```text
C:\Windows\Temp
```

Delete the files and folders that Windows allows you to remove.

Administrator permission may be required. Skip any files that are currently in use.

---

## 3. Clean the Windows Component Store

Do not delete files directly from the `WinSxS` folder. Use DISM to analyze and clean it safely.

### Analyze the Component Store

Run:

```cmd
DISM /Online /Cleanup-Image /AnalyzeComponentStore
```

Review the result to check whether cleanup is recommended.

### Remove superseded components

Run:

```cmd
DISM /Online /Cleanup-Image /StartComponentCleanup
```

This removes older component versions that Windows no longer needs.

### Optional ResetBase cleanup

Use the following command only when advanced cleanup is required:

```cmd
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
```

> **Warning:** `/ResetBase` is irreversible. After it runs, currently installed Windows updates can no longer be uninstalled.

For normal maintenance, use `/StartComponentCleanup` without `/ResetBase`.

---

## 4. Clear the Windows Update Cache

Use this step if the Windows Update download cache is taking up too much space or if downloaded update files may be corrupted.

### Stop the update services

Open PowerShell as Administrator and run:

```powershell
Stop-Service -Name wuauserv -Force
Stop-Service -Name bits -Force
```

### Clear the download cache

Remove the contents of:

```text
C:\Windows\SoftwareDistribution\Download
```

Do not delete the `Download` folder itself.

You can also clear it with PowerShell:

```powershell
Remove-Item `
    -Path "$env:WINDIR\SoftwareDistribution\Download\*" `
    -Recurse `
    -Force `
    -ErrorAction SilentlyContinue
```

### Start the update services

Always start the services again when finished:

```powershell
Start-Service -Name bits
Start-Service -Name wuauserv
```

Confirm their status:

```powershell
Get-Service -Name bits, wuauserv |
    Select-Object Name, Status
```

---

## 5. Clear the Delivery Optimization Cache

Open PowerShell as Administrator and run:

```powershell
Delete-DeliveryOptimizationCache -Force
```

If the command is not available, use Disk Cleanup or remove Delivery Optimization files from:

```text
Settings → System → Storage → Temporary files
```

---

## 6. Clear the Microsoft Teams Cache

Clearing the Teams cache can help with sign-in, loading, notification, and general performance issues.

Teams may take slightly longer to open after its cache is cleared.

### PowerShell method

Run the following commands in the affected user's Windows session:

```powershell
# Stop Classic Teams and New Teams
Get-Process -Name Teams, ms-teams -ErrorAction SilentlyContinue |
    Stop-Process -Force

# Clear Classic Teams cache
Remove-Item `
    -Path "$env:APPDATA\Microsoft\Teams\*" `
    -Recurse `
    -Force `
    -ErrorAction SilentlyContinue

# Clear New Teams cache
Remove-Item `
    -Path "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\*" `
    -Recurse `
    -Force `
    -ErrorAction SilentlyContinue
```

### Cache locations

Classic Teams:

```text
%APPDATA%\Microsoft\Teams
```

New Teams:

```text
%LOCALAPPDATA%\Packages\MSTeams_8wekyb3d8bbwe\LocalCache
```

If a folder does not exist, that version of Teams may not be installed for the current user.

---

## 7. Repair Windows System Files

This is a repair step, not a routine cleanup step. Use it when Windows is unstable, system files may be damaged, or updates are failing.

These checks can take some time to complete.

### Repair the Windows image

Run DISM first:

```cmd
DISM /Online /Cleanup-Image /RestoreHealth
```

### Check Windows system files

After DISM finishes, run:

```cmd
sfc /scannow
```

Restart the computer if either command reports that repairs were completed.

---

## 8. Uninstall Unused Applications

Open:

```text
Settings → Apps → Installed apps
```

Review applications that are:

- No longer used
- No longer supported
- Old versions of installed software
- Trial applications
- Large and no longer required

> **Important:** Do not remove security software, device drivers, management tools, VPN clients, or company applications unless their removal has been approved.

---

## 9. Review Startup Applications

> **Note:** This is a startup optimization step. It does not remove files or free up a significant amount of disk space.

Press `Win + R` and run:

```cmd
taskmgr
```

Open **Startup apps** and disable applications that do not need to start automatically.

This may help with:

- Slow sign-in
- High CPU or memory use after sign-in
- Too many applications opening at startup

> **Important:** Do not disable antivirus, security tools, device management software, or required work applications.

---

## 10. Empty the Recycle Bin

Right-click the **Recycle Bin** and select:

```text
Empty Recycle Bin
```

Check the contents before emptying it if the user may still need any deleted files.

You can also use PowerShell:

```powershell
Clear-RecycleBin -Force
```

---

## 11. Remove Old User Profiles

Old profiles can take up a large amount of disk space.

Press `Win + R` and run:

```cmd
sysdm.cpl
```

Go to:

```text
Advanced → User Profiles → Settings
```

Only remove profiles that:

- Are no longer used
- Belong to former employees
- Have been confirmed as safe to delete

> **Important:** Confirm the profile owner and check for locally stored files before deleting a profile. Removing a profile deletes the user's local data from that computer.

Do not remove:

- The current user's profile
- Default or system profiles
- Profiles that have not been verified

---

## 12. Optimize the System Drive

Press `Win + R` and run:

```cmd
dfrgui
```

Select the system drive and choose **Optimize**.

Windows will use the appropriate method for the drive type:

- HDDs are defragmented.
- SSDs are optimized using retrim.

You can also run the following PowerShell command as Administrator:

```powershell
Optimize-Volume -DriveLetter C -Verbose
```

Do not use third-party defragmentation tools on SSDs.

---

## 13. Check the File System

Use an online CHKDSK scan to check the system drive without immediately restarting the computer:

```cmd
chkdsk C: /scan
```

Review the result.

If Windows reports errors that require an offline repair, schedule the repair during an approved maintenance window.

Do not force a restart while the user has unsaved work.

---

## 14. Enable Storage Sense

Open:

```text
Settings → System → Storage
```

Enable **Storage Sense**.

Recommended options include:

- Remove temporary system and application files
- Empty the Recycle Bin after 30 days
- Run Storage Sense automatically

Deleting files from the Downloads folder should normally be left disabled unless the user or company policy allows it.

---

## 15. Check for Large Files

### File Explorer

Open File Explorer and search the required drive for:

```text
size:>1GB
```

Review the results before deleting anything.

### PowerShell

The following command lists the 20 largest files on the `C:` drive:

```powershell
Get-ChildItem `
    -Path C:\ `
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
                [math\]::Round($_.Length / 1GB, 2)
            }
        }
```

The scan may take several minutes.

Pay particular attention to:

- ISO files
- ZIP archives
- Application installers
- Old log files
- Backup files
- Virtual machine files
- Duplicate downloads

> **Important:** Do not delete files based only on their size. Confirm that they are not required by the user, Windows, or an installed application.

---

## 16. Record the Results

Record the work completed and any issues found.

```text
Computer name:
Current user:
Technician:
Date:

Free space before:
Free space after:
Space recovered:

Actions completed:
Issues found:
Follow-up required:
Restart completed:
```

To check the final free space in PowerShell:

```powershell
Get-PSDrive C |
    Select-Object Name,
    @{Name = "FreeSpaceGB"; Expression = {
        [math\]::Round($_.Free / 1GB, 2)
    }}
```

Save any generated logs or reports in the relevant ticket or support record.

---

## 17. Restart the Computer

Save all open work before restarting.

To restart immediately:

```cmd
shutdown /r /t 0
```

A restart is recommended after:

- Windows Update cache cleanup
- DISM component cleanup
- System file repairs
- Disk repairs
- Application removal

After the restart, confirm that Windows starts normally and required applicationsintenance Checklist

### Cleanup

- [ ] Free space recorded before cleanup
- [ ] Disk Cleanup completed
- [ ] User temporary files removed
- [ ] Windows temporary files removed
- [ ] Recycle Bin emptied
- [ ] Windows Update cache cleared
- [ ] Windows Update services started again
- [ ] Delivery Optimization cache cleared
- [ ] Teams cache cleared
- [ ] Component Store analyzed
- [ ] Component Store cleanup completed
- [ ] Unused applications reviewed
- [ ] Old user profiles reviewed
- [ ] Large files reviewed

### Repair and optimization

- [ ] Startup applications reviewed
- [ ] System drive optimized
- [ ] Storage Sense enabled
- [ ] DISM RestoreHealth completed, if required
- [ ] SFC completed, if required
- [ ] CHKDSK scan completed, if required

### Completion

- [ ] Free space recorded after cleanup
- [ ] Cleanup report completed
- [ ] Warnings or errors documented
- [ ] Computer restarted, if required
- [ ] Windows Update checked
- [ ] Teams and other required applications tested

---

## Expected Results

Depending on the condition of the computer, this procedure may provide:

- More available disk space
- Fewer temporary and cached files
- A smaller Windows Update download cache
- Better Windows Update performance
- Improved Teams performance
- Faster startup when unnecessary startup applications are disabled
- Better visibility of large files and disk usage

The amount of recovered space and any performance improvement will vary between computers.