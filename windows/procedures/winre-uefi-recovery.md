# Windows UEFI Boot Recovery

## Purpose

Use this procedure to repair a Windows installation that no longer starts on a UEFI computer using a GPT disk.

The main goal is to identify the correct Windows and EFI partitions, rebuild the Windows boot files, and test the result. File-system and Windows image repairs should only be performed if rebuilding the boot files does not resolve the issue.

## Recovery Order

1. Identify the Windows disk.
2. Locate the Windows volume and EFI System Partition.
3. Rebuild the UEFI boot files using BCDBoot.
4. Restart the computer and test Windows.
5. Check the Windows file system if the issue remains.
6. Repair the offline Windows image and system files if required.
7. Record the results and escalate based on the remaining startup error.

> [!IMPORTANT]
> This procedure applies to UEFI systems using GPT disks. Do not use it as a BIOS or MBR recovery procedure.

---

## Temporary Drive Letters

The following drive letters are used throughout this procedure:

- `W:` for the Windows volume
- `S:` for the EFI System Partition

The letters are assigned temporarily in the Windows Recovery Environment.

Drive letters in WinRE often differ from the letters used when Windows starts normally. Never assume that Windows is installed on `C:`.

Before running any repair command, verify that:

- `W:` contains the intended Windows installation.
- `S:` is the correct FAT32 EFI System Partition.

If either letter is already in use, choose another unused letter and replace it consistently in every related command.

---

## Before You Start

- Confirm that the computer normally starts in UEFI mode.
- Disconnect unnecessary USB drives and external disks.
- Keep the Windows installation media connected if WinRE was started from it.
- Obtain the BitLocker recovery key if the Windows volume is encrypted.
- Record the exact startup error.
- Record any recent Windows updates, firmware changes, disk replacements, cloning operations, or partition changes.
- Verify the selected disk and volumes before making changes.
- Restart and test Windows after each repair stage.
- Stop the procedure once Windows starts normally.

> [!WARNING]
> Do not use `clean`, `format`, `delete partition`, or `convert` in DiskPart. These commands can destroy data or make the installation unbootable.

---

## 1. Open Command Prompt in WinRE

From the Windows Recovery Environment, select:

```text
Troubleshoot > Advanced options > Command Prompt
```

If the computer was started from Windows installation media, select:

```text
Repair your computer > Troubleshoot > Advanced options > Command Prompt
```

### BitLocker-protected computers

If the Windows volume is protected by BitLocker, unlock it using the approved recovery-key process.

After unlocking the volume, verify that the Windows directory is accessible.

Do not:

- Disable BitLocker without authorization.
- Decrypt the Windows volume as part of routine boot recovery.
- Clear the TPM.
- Change TPM or Secure Boot settings unless an approved procedure requires it.

A boot-file or firmware change may cause another BitLocker recovery prompt during the next startup.

---

## 2. Identify the Windows Disk

Start DiskPart:

```cmd
diskpart
```

List the available physical disks:

```cmd
list disk
```

Identify the internal Windows disk using:

- Disk size
- GPT status
- Number and size of partitions
- Connected installation media
- Connected external disks
- Number of internal disks

An asterisk in the `GPT` column means that the disk uses GPT. GPT is normally used with UEFI, but it does not confirm that the firmware is currently configured for UEFI boot.

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

Confirm that the selected disk is the intended internal Windows disk.

> [!WARNING]
> Do not identify the disk by number alone. USB installers, external disks, recovery media, and old Windows disks may also appear in DiskPart.

---

## 3. Locate the Windows and EFI Partitions

With the correct disk selected, list its partitions:

```cmd
list partition
```

List the detected volumes:

```cmd
list volume
```

### Windows volume

The Windows volume is normally:

- Formatted as NTFS
- One of the largest volumes
- Large enough to contain Windows, applications, and user profiles

### EFI System Partition

The EFI System Partition is normally:

- Formatted as FAT32
- Approximately 100 MB to 500 MB
- Located on a GPT disk
- Configured as a system partition
- Not assigned a permanent drive letter

Do not identify a partition by size alone. Verify its file system, type, disk number, and relationship to the intended Windows installation.

If the computer contains several physical disks, there may be more than one EFI System Partition. Use the EFI partition associated with the Windows installation being repaired.

---

## 4. Assign `W:` to the Windows Volume

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
- Is not installation media or a recovery partition

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

Choose another unused letter and replace `W:` with that letter in every subsequent Windows-volume command.

---

## 5. Verify the Windows Installation

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
- Recovery files
- An empty file system
- A different Windows installation

If the expected directories are missing, return to DiskPart and locate the correct Windows volume.

---

## 6. Assign `S:` to the EFI System Partition

Start DiskPart again:

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

Select the suspected EFI System Partition volume:

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
- Is the small EFI System Partition
- Is on the intended Windows disk
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
> Do not format the EFI System Partition. Formatting it removes existing boot files and may affect Windows or other installed operating systems.

---

## 7. Validate the Selected Volumes

Before running BCDBoot, confirm that:

- `W:` contains the intended Windows installation.
- `W:\Windows` exists.
- `W:\Users` exists.
- `W:\Program Files` exists.
- `S:` is the correct FAT32 EFI System Partition.
- The Windows and EFI volumes belong to the intended Windows installation.
- The physical disk uses GPT.
- The computer is configured for UEFI boot.
- The Windows volume is unlocked if BitLocker is enabled.

Inspect the EFI System Partition:

```cmd
dir S:\
dir S:\EFI
```

The partition may already contain boot files from Windows, the computer manufacturer, or another operating system.

Do not delete existing EFI files during this procedure.

---

## 8. Rebuild the UEFI Boot Files

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

The presence of this directory confirms that the Windows boot files exist on the selected EFI partition. It does not confirm that the firmware is configured to start from that partition.

### If BCDBoot fails

Check that:

- `W:\Windows` is the correct Windows directory.
- `S:` is the correct EFI System Partition.
- Both volumes belong to the intended Windows installation.
- BitLocker is unlocked.
- The EFI partition is writable.
- The EFI partition has available space.
- The command was entered correctly.

### If Windows Boot Manager is missing

When `/s S:` is specified, BCDBoot writes the files to the selected EFI partition. On some systems, a new firmware entry may not be created automatically.

If BCDBoot succeeds but Windows Boot Manager is missing:

1. Restart the computer.
2. Open the one-time boot menu or UEFI settings.
3. Check for **Windows Boot Manager**.
4. Confirm that UEFI mode is enabled.
5. Review the boot order.

Do not manually create firmware boot entries unless an approved advanced recovery procedure requires it.

---

## 9. Restart and Test Windows

Close Command Prompt:

```cmd
exit
```

Restart the computer. Remove installation media when appropriate so the computer starts from the repaired internal disk.

Review the result:

- If Windows starts normally, stop here.
- If Windows still fails, record the exact error and continue.
- If no boot device is found, check UEFI mode, the boot order, Windows Boot Manager, the selected EFI partition, and physical disk detection.
- If BitLocker prompts for recovery, follow the approved recovery process.

---

## 10. Check the Windows File System

Return to WinRE Command Prompt.

Drive letters may change after a restart, so verify the Windows volume again:

```cmd
dir W:\Windows
```

If `W:` is no longer correct, repeat the identification and drive-letter assignment steps.

Run:

```cmd
chkdsk W: /f
```

This checks the volume and repairs logical file-system errors.

Do not interrupt CHKDSK unnecessarily.

### Deeper storage scan

Use the following command only when disk damage, unreadable sectors, I/O errors, or recurring corruption is suspected:

```cmd
chkdsk W: /r
```

The `/r` option includes `/f` and also checks for unreadable sectors. It may take a long time, especially on large mechanical disks.

Escalate for storage diagnostics if CHKDSK reports:

- Bad sectors
- Unreadable data
- I/O errors
- Recurring file-system corruption
- A volume that cannot be accessed
- A volume that repeatedly becomes unavailable
- Repairs that return after another restart

Restart and test Windows after CHKDSK completes.

---

## 11. Repair the Offline Windows Image

If Windows still does not start, return to WinRE and verify the Windows volume:

```cmd
dir W:\Windows
```

Repair the offline component store:

```cmd
dism /image:W:\ /cleanup-image /restorehealth
```

If DISM succeeds, run offline System File Checker:

```cmd
sfc /scannow /offbootdir=W:\ /offwindir=W:\Windows
```

DISM is run first because SFC may need the repaired component store when replacing damaged system files.

### If DISM cannot find the source files

Use matching Windows installation media or another approved repair source.

The source should match the installed system as closely as possible:

- Architecture
- Language
- Edition
- Windows release
- Servicing level

Do not guess the image index when using `install.wim` or `install.esd`. Identify the correct image before using it as a repair source.

Restart and test Windows after DISM and SFC complete.

---

## 12. BOOTREC on UEFI Systems

BOOTREC is not part of the normal repair sequence for this procedure.

Do not automatically run:

```cmd
bootrec /fixmbr
bootrec /fixboot
bootrec /scanos
bootrec /rebuildbcd
```

On a UEFI/GPT installation:

- `/fixmbr` repairs MBR boot code, which is not normally used for native UEFI startup.
- `/fixboot` often returns `Access is denied` on current UEFI installations.
- `/rebuildbcd` is normally unnecessary after BCDBoot succeeds.
- BOOTREC cannot correct an incorrectly selected EFI partition.
- BOOTREC does not resolve every missing firmware boot entry.

BCDBoot is the preferred tool for rebuilding Windows UEFI boot files and the BCD store.

Use BOOTREC only as part of an approved advanced troubleshooting procedure.

> [!IMPORTANT]
> If `bootrec /fixboot` returns `Access is denied`, do not repeat it indefinitely.

---

## 13. Check the UEFI Firmware Configuration

Use this section if:

- BCDBoot succeeds but Windows still does not start.
- Windows Boot Manager does not appear.
- The computer reports that no bootable device exists.
- The computer starts from the wrong physical disk.
- The computer contains multiple internal disks.

Restart the computer and open its UEFI settings or one-time boot menu.

Check that:

- UEFI boot mode is enabled.
- Legacy BIOS or Compatibility Support Module mode is not being used unexpectedly.
- The internal Windows disk is detected.
- Windows Boot Manager appears as a boot option.
- Windows Boot Manager is positioned appropriately in the boot order.
- The computer is not attempting to start from a disconnected or old disk.
- The storage-controller configuration has not changed unexpectedly.

> [!WARNING]
> Do not change RAID, AHCI, Intel VMD, TPM, or Secure Boot settings without understanding the existing configuration and the effect of the change.

An incorrect storage-controller change may prevent Windows from starting and may trigger BitLocker recovery.

---

## 14. Remove the Temporary EFI Drive Letter

Drive letters assigned in WinRE are normally temporary. The temporary `S:` assignment can still be removed before leaving the recovery session.

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

> [!WARNING]
> Do not remove a drive letter unless you have positively identified the selected volume.

Removing `W:` is normally unnecessary because drive letters assigned in WinRE do not generally become the installed operating system's normal drive letters.

---

## 15. Record the Recovery Results

Record the recovery work and all relevant command results.

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

Record exact errors rather than only stating that a command failed.

Save relevant photographs, screenshots, command output, diagnostic reports, and recovery details in the support ticket or approved support record.

---

## 16. If Windows Still Does Not Start

If BCDBoot, CHKDSK, DISM, and SFC complete but Windows still does not start, record:

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
- Memory, motherboard, or another hardware failure

Use symptom-specific troubleshooting or escalate according to the organization's recovery process.

Do not proceed directly to reinstalling Windows until user data, BitLocker status, available recovery options, and organizational requirements have been reviewed.

---

## Keyboard Symbol Reference

The following mappings may help when a Portuguese ISO keyboard is interpreted using the English (US) layout in WinRE.

Keyboard models and layouts may differ. Test uncertain symbols on an empty command line before entering the full command.

Common mappings:

- `:`: Hold **Shift** and press the key immediately to the right of `L`, commonly labelled `Ç`.
- `\`: Press the ISO key immediately to the left of `Z`, commonly labelled `<` and `>`.
- `/`: Press the key immediately to the left of the right **Shift** key.
- `-`: Press the first key immediately to the right of `0`.
- `_`: Hold **Shift** and press the first key immediately to the right of `0`.
- `=`: Press the second key immediately to the right of `0`.

Treat these mappings as guidance rather than guarantees.

---

## Recovery Order at a Glance

### 1. Identify and validate the disk and volumes

Confirm that:

- The correct physical disk is selected.
- `W:` is assigned to the intended Windows volume.
- `S:` is assigned to the correct FAT32 EFI System Partition.
- Both volumes belong to the intended Windows installation.
- The physical disk uses GPT.
- The computer is configured for UEFI boot.

### 2. Rebuild the UEFI boot files

```cmd
bcdboot W:\Windows /s S: /f UEFI
```

Restart and test Windows.

### 3. Repair file-system errors

```cmd
chkdsk W: /f
```

Restart and test Windows.

Use the following only when storage damage is suspected:

```cmd
chkdsk W: /r
```

### 4. Repair the Windows image and system files

```cmd
dism /image:W:\ /cleanup-image /restorehealth
sfc /scannow /offbootdir=W:\ /offwindir=W:\Windows
```

Restart and test Windows.

### 5. Escalate based on the exact symptoms

Do not automatically run the generic BOOTREC sequence on a UEFI/GPT computer.

---

## UEFI Boot Recovery Checklist

### Initial assessment

- [ ] Exact startup error recorded
- [ ] Recent changes recorded
- [ ] Unnecessary external storage disconnected
- [ ] BitLocker status checked
- [ ] Approved BitLocker recovery key available, if required
- [ ] UEFI boot mode confirmed
- [ ] Internal disk detected by the firmware

### Disk and volume identification

- [ ] Correct physical disk identified
- [ ] Physical disk number recorded
- [ ] GPT status confirmed
- [ ] Windows volume identified
- [ ] `W:` assigned to the Windows volume
- [ ] `W:\Windows` confirmed
- [ ] `W:\Users` confirmed
- [ ] `W:\Program Files` confirmed
- [ ] EFI System Partition identified
- [ ] FAT32 file system confirmed
- [ ] EFI System Partition confirmed on the intended disk
- [ ] `S:` assigned to the EFI System Partition

### UEFI boot repair

- [ ] Pre-repair validation completed
- [ ] BCDBoot command completed
- [ ] BCDBoot result recorded
- [ ] `S:\EFI\Microsoft\Boot` checked
- [ ] Computer restarted
- [ ] Windows startup tested
- [ ] Windows Boot Manager checked in the firmware, if required

### Additional repairs

- [ ] Drive-letter assignments rechecked after restart
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
- [ ] All command results documented
- [ ] Firmware changes documented
- [ ] Recovery record completed
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

If Windows still does not start after the documented repairs, use the exact error messages and recorded command results to continue with symptom-specific troubleshooting.
