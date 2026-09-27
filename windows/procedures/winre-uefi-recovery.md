# Windows UEFI Boot Recovery

Use this procedure to repair a Windows installation that no longer starts on a computer configured for **UEFI boot with a GPT disk**.

The primary goal is to identify the correct Windows and EFI partitions, rebuild the UEFI boot files, and test Windows. File-system and Windows image repairs should only be performed if rebuilding the boot files does not resolve the issue.

> [!IMPORTANT]
> This procedure applies only to **UEFI systems using GPT disks**.  
> Do not use it as a BIOS or MBR recovery procedure.

> [!WARNING]
> Selecting the wrong disk or partition can make another Windows installation or operating system unbootable.
>
> Do not use the following DiskPart commands:
>
> - `clean`
> - `format`
> - `delete partition`
> - `convert`

---

## Recovery Order

1. Open Command Prompt in the Windows Recovery Environment.
2. Identify the correct physical disk.
3. Assign `W:` to the Windows volume.
4. Assign `S:` to the EFI System Partition.
5. Validate both volumes.
6. Rebuild the UEFI boot files with BCDBoot.
7. Restart and test Windows.
8. Run CHKDSK, DISM, and SFC only if required.
9. Record the results and escalate using the exact remaining error.

Stop the procedure once Windows starts normally.

---

## Temporary Drive Letters

This procedure uses the following temporary drive letters:

- `W:` for the Windows volume
- `S:` for the EFI System Partition

Drive letters in the Windows Recovery Environment may differ from the letters used when Windows starts normally.

Never assume that Windows is installed on `C:`.

If either letter is already in use, choose another unused letter and replace it consistently in all related commands.

---

## Before You Start

- Record the exact startup error.
- Record any recent updates, firmware changes, disk replacements, cloning operations, or partition changes.
- Disconnect unnecessary USB drives and external disks.
- Keep the Windows installation media connected if the recovery environment was started from it.
- Obtain the BitLocker recovery key if the Windows volume is encrypted.
- Confirm that the computer normally starts in UEFI mode.
- Confirm that the internal disk is detected by the firmware.
- Verify every disk and volume before making changes.
- Restart and test Windows after each repair stage.

### BitLocker

If the Windows volume is protected by BitLocker, unlock it using the approved recovery-key process.

Do not:

- Disable BitLocker without authorization.
- Decrypt the Windows volume as part of routine boot recovery.
- Clear the TPM.
- Change TPM or Secure Boot settings unless an approved procedure requires it.

A boot-file or firmware change may cause another BitLocker recovery prompt during the next startup.

---

## 1. Open Command Prompt

From the Windows Recovery Environment, select:

```text
Troubleshoot > Advanced options > Command Prompt
```

If the computer was started from Windows installation media, select:

```text
Repair your computer > Troubleshoot > Advanced options > Command Prompt
```

---

## 2. Identify the Windows Disk

Start DiskPart:

```cmd
diskpart
```

List the physical disks:

```cmd
list disk
```

Identify the internal Windows disk using:

- Disk size
- GPT status
- Number and size of partitions
- Number of internal disks
- Connected installation media
- Connected USB or external disks

An asterisk in the `GPT` column indicates that the disk uses GPT.

> [!NOTE]
> GPT status does not prove that the firmware is currently configured for UEFI boot.

Select the suspected Windows disk:

```cmd
select disk <DiskNumber>
```

Example:

```cmd
select disk 0
```

Display the disk details:

```cmd
detail disk
```

List its partitions and detected volumes:

```cmd
list partition
list volume
```

Confirm that the selected disk is the intended internal Windows disk.

> [!WARNING]
> Do not identify the disk by number alone.  
> USB installers, external disks, recovery media, and old Windows disks may also appear in DiskPart.

---

## 3. Identify the Windows Volume

The Windows volume is normally:

- Formatted as NTFS
- One of the largest volumes
- Large enough to contain Windows, applications, and user profiles

Select the suspected Windows volume:

```cmd
select volume <WindowsVolumeNumber>
```

Example:

```cmd
select volume 3
```

Display its details:

```cmd
detail volume
```

Verify that the volume:

- Uses NTFS
- Is located on the intended physical disk
- Is large enough to contain Windows
- Is not installation media
- Is not a recovery partition

Assign the temporary drive letter:

```cmd
assign letter=W
```

Exit DiskPart:

```cmd
exit
```

### If `W:` is already assigned

Do not remove the existing drive letter until you know which volume is using it.

Choose another unused letter and replace `W:` with that letter in all subsequent Windows-volume commands.

---

## 4. Verify the Windows Installation

Run:

```cmd
dir W:\Windows
dir W:\Users
dir "W:\Program Files"
dir W:\Windows\System32\Config
```

Continue only if these directories confirm that `W:` contains the intended Windows installation.

Do not continue if the volume contains:

- Windows installation media
- Recovery files only
- An empty file system
- A different Windows installation

If the expected directories are missing, return to DiskPart and locate the correct Windows volume.

---

## 5. Identify the EFI System Partition

The EFI System Partition is normally:

- Formatted as FAT32
- Approximately 100 MB to 500 MB
- Located on a GPT disk
- Configured as a system partition
- Not assigned a permanent drive letter

Do not identify the EFI partition by size alone.

If the computer contains multiple physical disks, it may also contain multiple EFI System Partitions. Select the EFI partition associated with the Windows installation being repaired.

Start DiskPart:

```cmd
diskpart
```

List the physical disks:

```cmd
list disk
```

Select the verified Windows disk:

```cmd
select disk <DiskNumber>
```

List its partitions and volumes:

```cmd
list partition
list volume
```

Select the suspected EFI volume:

```cmd
select volume <EFIVolumeNumber>
```

Example:

```cmd
select volume 1
```

Display its details:

```cmd
detail volume
```

Verify that the volume:

- Uses FAT32
- Is located on the intended Windows disk
- Is the small EFI System Partition
- Is not installation media
- Is not an OEM recovery partition
- Does not belong to another operating-system disk

Assign the temporary drive letter:

```cmd
assign letter=S
```

Exit DiskPart:

```cmd
exit
```

> [!WARNING]
> Do not format the EFI System Partition.  
> Formatting it removes existing boot files and may affect Windows or other installed operating systems.

---

## 6. Validate the Selected Volumes

Before running BCDBoot, confirm that:

- `W:` contains the intended Windows installation.
- `W:\Windows` exists.
- `W:\Users` exists.
- `W:\Program Files` exists.
- `S:` is the correct FAT32 EFI System Partition.
- Both volumes are associated with the intended Windows installation.
- The physical disk uses GPT.
- The computer is configured for UEFI boot.
- The Windows volume is unlocked if BitLocker is enabled.

Inspect the EFI System Partition:

```cmd
dir S:\
dir S:\EFI
```

The partition may already contain boot files from Windows, the computer manufacturer, or another operating system.

Do not delete existing EFI files.

If either volume is uncertain, stop and verify it again before continuing.

---

## 7. Rebuild the UEFI Boot Files

Run:

```cmd
bcdboot W:\Windows /s S: /f UEFI
```

In this command:

- `W:\Windows` is the source Windows installation.
- `S:` is the destination EFI System Partition.
- `/f UEFI` creates boot files for UEFI firmware.

A successful command should return:

```text
Boot files successfully created.
```

Verify that the Windows boot directory exists:

```cmd
dir S:\EFI\Microsoft\Boot
```

The presence of this directory confirms that Windows boot files exist on the selected EFI partition.

It does not confirm that the firmware is configured to start from that partition.

### If BCDBoot fails

Verify that:

- `W:\Windows` is the correct Windows directory.
- `S:` is the correct EFI System Partition.
- Both volumes are associated with the intended Windows installation.
- BitLocker is unlocked.
- The EFI partition is writable.
- The EFI partition has available space.
- The command was entered correctly.

Do not format the EFI partition as a routine response to a BCDBoot failure.

---

## 8. Restart and Test Windows

Close Command Prompt:

```cmd
exit
```

Restart the computer.

Remove the Windows installation media when appropriate so the computer starts from the repaired internal disk.

Review the result:

- If Windows starts normally, stop the procedure.
- If Windows still fails, record the exact error.
- If no boot device is found, check UEFI mode, disk detection, Windows Boot Manager, and the boot order.
- If BitLocker requests recovery, follow the approved recovery process.

### If Windows Boot Manager Is Missing

If BCDBoot succeeds but Windows Boot Manager does not appear:

1. Restart the computer.
2. Open the one-time boot menu or UEFI settings.
3. Confirm that the internal disk is detected.
4. Confirm that UEFI boot mode is enabled.
5. Check for **Windows Boot Manager**.
6. Review the boot order.

Do not manually create firmware boot entries unless an approved advanced recovery procedure requires it.

---

## 9. Check the Windows File System

Only continue if rebuilding the boot files did not resolve the issue.

Return to the Windows Recovery Environment and open Command Prompt.

Drive letters may change after a restart. Verify the Windows volume again:

```cmd
dir W:\Windows
```

If `W:` is no longer correct, repeat the disk and volume identification steps.

Run:

```cmd
chkdsk W: /f
```

This checks the volume and repairs logical file-system errors.

Do not interrupt CHKDSK unnecessarily.

Restart and test Windows after CHKDSK completes.

### Deeper Storage Scan

Use `/r` only when disk damage, unreadable sectors, I/O errors, or recurring corruption is suspected:

```cmd
chkdsk W: /r
```

The `/r` option includes `/f` and also checks for unreadable sectors. It may take a long time, particularly on large mechanical disks.

Escalate for storage diagnostics if CHKDSK reports:

- Bad sectors
- Unreadable data
- I/O errors
- Recurring file-system corruption
- A volume that cannot be accessed
- A volume that repeatedly becomes unavailable
- Repairs that return after another restart

---

## 10. Repair the Offline Windows Image

If Windows still does not start, return to Command Prompt and verify the Windows volume:

```cmd
dir W:\Windows
```

Repair the offline Windows component store:

```cmd
dism /image:W:\ /cleanup-image /restorehealth
```

If DISM succeeds, run offline System File Checker:

```cmd
sfc /scannow /offbootdir=W:\ /offwindir=W:\Windows
```

DISM is run first because SFC may require the repaired component store when replacing damaged system files.

Restart and test Windows after DISM and SFC complete.

### If DISM Cannot Find the Source Files

Use matching Windows installation media or another approved repair source.

The repair source should match the installed system as closely as possible:

- Architecture
- Language
- Edition
- Windows release
- Servicing level

Do not guess the image index when using `install.wim` or `install.esd`. Identify the correct image before using it as a repair source.

---

## 11. BOOTREC on UEFI Systems

BOOTREC is not part of the normal repair sequence in this procedure.

Do not automatically run:

```cmd
bootrec /fixmbr
bootrec /fixboot
bootrec /scanos
bootrec /rebuildbcd
```

On a UEFI and GPT installation:

- `/fixmbr` repairs MBR boot code, which is not normally used for native UEFI startup.
- `/fixboot` may return `Access is denied` on current UEFI installations.
- `/rebuildbcd` is normally unnecessary after BCDBoot succeeds.
- BOOTREC cannot correct an incorrectly selected EFI partition.
- BOOTREC does not resolve every missing firmware boot entry.

BCDBoot is the preferred tool for rebuilding Windows UEFI boot files and the BCD store.

Use BOOTREC only as part of an approved advanced troubleshooting procedure.

> [!IMPORTANT]
> If `bootrec /fixboot` returns `Access is denied`, do not repeat it indefinitely.

---

## 12. Check the UEFI Firmware Configuration

Check the firmware configuration if:

- BCDBoot succeeds but Windows still does not start.
- Windows Boot Manager does not appear.
- The computer reports that no bootable device exists.
- The computer starts from the wrong physical disk.
- The computer contains multiple internal disks.

Restart the computer and open its UEFI settings or one-time boot menu.

Confirm that:

- UEFI boot mode is enabled.
- Legacy BIOS or Compatibility Support Module mode is not being used unexpectedly.
- The internal Windows disk is detected.
- Windows Boot Manager appears as a boot option.
- Windows Boot Manager is positioned appropriately in the boot order.
- The system is not attempting to start from a disconnected or old disk.
- The storage-controller configuration has not changed unexpectedly.

> [!WARNING]
> Do not change RAID, AHCI, Intel VMD, TPM, or Secure Boot settings without understanding the existing configuration and the effect of the change.
>
> An incorrect storage-controller change may prevent Windows from starting and may trigger BitLocker recovery.

---

## 13. Remove the Temporary EFI Drive Letter

Drive letters assigned in the Windows Recovery Environment are normally temporary.

The temporary `S:` assignment can also be removed before leaving the recovery session.

Start DiskPart:

```cmd
diskpart
```

List the volumes:

```cmd
list volume
```

Select the verified EFI System Partition:

```cmd
select volume <EFIVolumeNumber>
```

Display its details one final time:

```cmd
detail volume
```

Remove the temporary drive letter:

```cmd
remove letter=S
```

Exit DiskPart:

```cmd
exit
```

Removing `W:` is normally unnecessary because drive letters assigned in the recovery environment do not generally become the installed operating system's normal drive letters.

> [!WARNING]
> Do not remove a drive letter unless you have positively identified the selected volume.

---

## If Windows Still Does Not Start

> [!IMPORTANT]
> Do not consider the recovery complete just because the boot files were rebuilt or the Windows volume was checked.
> If the computer still does not start normally after this procedure, stop treating this as a simple boot fix.
>
> Continue with the advanced UEFI diagnosis and firmware investigation in [winre-uefi-advanced-troubleshooting.md](winre-uefi-advanced-troubleshooting.md) before returning the device to service.
>
> This is the point where missing firmware settings, wrong boot order, storage-controller issues, and other deeper Windows startup problems are usually found.

---

## 14. Record the Recovery Results

Record the recovery work and all relevant command results in the support ticket or approved support record.

```text
Computer name:
Computer model:
Serial number:
Current user:
Technician:
Date:

Original startup error:
Recent changes:

BitLocker enabled:
BitLocker recovery required:
UEFI mode confirmed:
Internal disk detected in firmware:
Windows Boot Manager present:

Physical disk number:
Windows volume number:
Windows temporary drive letter:
EFI volume number:
EFI temporary drive letter:

BCDBoot result:
CHKDSK result:
DISM result:
SFC result:

Storage warnings:
Firmware changes:
Windows started successfully:
Follow-up required:
Escalation reference:
```

Record exact messages and error codes rather than stating only that a command failed.

Save relevant photographs, screenshots, command output, diagnostic reports, and recovery details in the approved support record.

---

## 15. If Windows Still Does Not Start

If the documented repairs complete but Windows still does not start, record:

- The exact startup error
- The BCDBoot result
- The CHKDSK summary
- The DISM result
- The SFC result
- Whether Windows Boot Manager appears in the UEFI boot menu
- Whether the internal disk appears in the firmware
- Whether BitLocker requests a recovery key
- Whether the issue began after an update, firmware change, disk replacement, cloning operation, or partition change

The remaining issue may involve:

- An incorrect UEFI boot order
- A missing or invalid firmware boot entry
- An incorrect EFI System Partition
- Multiple physical disks with competing EFI System Partitions
- Storage-device failure
- Pending or failed Windows updates
- Registry corruption
- Damaged boot-critical drivers
- An incorrect storage-controller mode
- RAID, Intel VMD, or storage-driver issues
- An unserviceable Windows installation
- Memory, motherboard, or other hardware failure

Use symptom-specific troubleshooting or escalate according to the organization's recovery process.

Do not proceed directly to reinstalling Windows until the following have been reviewed:

- User data
- BitLocker status
- Available recovery options
- Backup status
- Organizational requirements

---

## Keyboard Symbol Reference

The following mappings may help when a Portuguese ISO keyboard is interpreted using the English US layout in the Windows Recovery Environment.

Keyboard models and layouts may differ. Test uncertain symbols on an empty command line before entering the complete command.

Common mappings:

- `:`: Hold **Shift** and press the key immediately to the right of `L`, commonly labelled `Ç`.
- `\`: Press the ISO key immediately to the left of `Z`, commonly labelled `<` and `>`.
- `/`: Press the key immediately to the left of the right **Shift** key.
- `-`: Press the first key immediately to the right of `0`.
- `_`: Hold **Shift** and press the first key immediately to the right of `0`.
- `=`: Press the second key immediately to the right of `0`.

Treat these mappings as guidance rather than guarantees.

---

## Quick Command Reference

### Identify the disk and volumes

```cmd
diskpart
list disk
select disk <DiskNumber>
detail disk
list partition
list volume
```

### Assign `W:` to Windows

```cmd
select volume <WindowsVolumeNumber>
detail volume
assign letter=W
exit
```

### Verify Windows

```cmd
dir W:\Windows
dir W:\Users
dir "W:\Program Files"
```

### Assign `S:` to the EFI partition

```cmd
diskpart
select disk <DiskNumber>
list volume
select volume <EFIVolumeNumber>
detail volume
assign letter=S
exit
```

### Rebuild the UEFI boot files

```cmd
bcdboot W:\Windows /s S: /f UEFI
```

### Check the file system

```cmd
chkdsk W: /f
```

Use the following only when storage damage is suspected:

```cmd
chkdsk W: /r
```

### Repair the offline Windows installation

```cmd
dism /image:W:\ /cleanup-image /restorehealth
sfc /scannow /offbootdir=W:\ /offwindir=W:\Windows
```

---

## Recovery Checklist

### Initial Assessment

- [ ] Exact startup error recorded
- [ ] Recent changes recorded
- [ ] Unnecessary external storage disconnected
- [ ] BitLocker status checked
- [ ] Recovery key available, if required
- [ ] UEFI boot mode confirmed
- [ ] Internal disk detected by the firmware

### Disk and Volume Identification

- [ ] Correct physical disk identified
- [ ] GPT status confirmed
- [ ] Windows volume identified
- [ ] `W:` assigned to the Windows volume
- [ ] `W:\Windows` confirmed
- [ ] `W:\Users` confirmed
- [ ] `W:\Program Files` confirmed
- [ ] EFI System Partition identified
- [ ] FAT32 file system confirmed
- [ ] EFI partition confirmed on the intended disk
- [ ] `S:` assigned to the EFI partition

### UEFI Boot Repair

- [ ] Final volume validation completed
- [ ] BCDBoot command completed
- [ ] BCDBoot result recorded
- [ ] `S:\EFI\Microsoft\Boot` checked
- [ ] Computer restarted
- [ ] Windows startup tested
- [ ] Windows Boot Manager checked, if required

### Additional Repair

- [ ] Drive letters rechecked after restart
- [ ] CHKDSK `/f` completed, if required
- [ ] CHKDSK `/r` used only when storage damage was suspected
- [ ] Storage warnings documented
- [ ] Offline DISM completed, if required
- [ ] Offline SFC completed, if required
- [ ] Computer restarted after each repair stage
- [ ] Windows startup tested after each repair stage

### Completion

- [ ] Windows starts successfully
- [ ] Required applications and services tested
- [ ] BitLocker status checked after recovery
- [ ] Temporary EFI drive letter removed
- [ ] Command results documented
- [ ] Firmware changes documented
- [ ] Follow-up actions recorded
- [ ] Issue escalated if Windows still does not start

---

## Expected Results

Depending on the cause of the startup failure, this procedure may provide:

- Recreated Windows UEFI boot files
- A repaired BCD store
- Restored access to Windows Boot Manager
- Repaired logical file-system errors
- Repaired Windows component-store corruption
- Repaired protected Windows system files
- Identification of storage-device problems
- Identification of incorrect firmware settings
- Better diagnostic information for escalation

A successful BCDBoot result does not guarantee that the firmware is configured to start from the correct EFI System Partition.

If Windows still does not start, use the exact errors and recorded command results for symptom-specific troubleshooting or escalation.