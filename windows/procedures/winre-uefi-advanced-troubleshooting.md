# Windows UEFI Boot Recovery: Advanced Troubleshooting

Use this guide when the main UEFI boot recovery procedure does not fix the problem.

Before using this guide, complete the standard recovery steps:

1. Identify the correct Windows disk.
2. Find the Windows volume.
3. Find the EFI System Partition.
4. Assign temporary drive letters.
5. Run BCDBoot.
6. Restart and test Windows.

> [!IMPORTANT]
> This guide is only for Windows computers that use:
>
> - UEFI firmware
> - A GPT disk
>
> Do not use this guide for a BIOS or MBR installation.

> [!WARNING]
> Selecting the wrong disk or partition could stop another Windows installation or operating system from starting.
>
> Do not use these DiskPart commands:
>
> - `clean`
> - `format`
> - `delete partition`
> - `convert`

Do not change RAID, AHCI, Intel VMD, TPM, or Secure Boot settings unless you understand the current configuration and have approval to make the change.

---

## How to Use This Guide

Start with the problem you can see.

### BCDBoot displays an error

Go to:

- #3-bcdboot-failed

### BCDBoot succeeds, but Windows does not start

Go to:

- #4-bcdboot-succeeds-but-windows-does-not-start

### Windows Boot Manager is missing

Go to:

- #5-windows-boot-manager-is-missing

### The computer shows "No bootable device"

Go to:

- #6-no-bootable-device

### The computer starts from the wrong disk

Go to:

- #7-the-computer-starts-from-the-wrong-disk

### Windows starts loading but fails before sign-in

Go to:

- #20-windows-starts-loading-but-fails-before-sign-in

### Automatic Repair repeats continuously

Go to:

- #12-automatic-repair-loop

### The problem started after an update

Go to:

- #13-startup-failure-after-a-windows-update

### The problem started after cloning or replacing a disk

Go to:

- #14-startup-failure-after-disk-cloning-or-replacement

---

## Temporary Drive Letters

The examples in this guide use:

- `W:` for the Windows volume
- `S:` for the EFI System Partition
- `X:` for Windows installation media

These letters are temporary.

Drive letters in the Windows Recovery Environment, also called WinRE, may change after a restart.

Before running a repair command, check the letters again:

```cmd
dir W:\Windows
dir S:\EFI
```

The first command should show the Windows installation.

The second command should show the contents of the EFI System Partition.

If either command shows the wrong files or returns an unexpected error, stop and identify the volumes again.

Never assume that Windows is on `C:` while working in WinRE.

---

## Recommended Troubleshooting Order

Follow this order unless the startup error clearly points to another problem:

1. Record the exact error.
2. Confirm the correct disk and volumes.
3. Review the BCDBoot result.
4. Check Windows Boot Manager.
5. Check the UEFI boot order.
6. Check whether the firmware detects the internal disk.
7. Run CHKDSK if file-system damage is possible.
8. Run DISM and SFC if Windows files may be damaged.
9. Investigate updates, drivers, or hardware.
10. Record the results and escalate if needed.

Restart and test Windows after each repair stage.

Stop when Windows starts normally.

---

## 1. Record the Exact Problem

Before making more changes, record what happens when the computer starts.

Useful details include:

- The complete error message
- Any error or stop code
- Whether the error appears before or after the Windows logo
- Whether Windows Boot Manager appears
- Whether the internal disk appears in the firmware
- Whether BitLocker asks for a recovery key
- Whether WinRE or Automatic Repair starts
- Whether the computer starts from the wrong disk
- Any recent updates or firmware changes
- Any recent disk replacement, cloning, or partition change

Do not record only:

```text
Windows does not start.
```

Record the exact message instead. For example:

```text
No bootable device found.
```

or:

```text
Recovery error: 0xc000000e
```

The exact error helps determine the next step.

---

## 2. Confirm the Disk and Volumes Again

Confirm the disk and volumes before repeating a repair.

This is especially important when the computer has:

- More than one internal disk
- An old Windows disk
- A cloned disk
- Windows installation media
- External storage
- More than one EFI partition

Start DiskPart:

```cmd
diskpart
```

List the physical disks:

```cmd
list disk
```

Select the suspected Windows disk:

```cmd
select disk <DiskNumber>
```

Example:

```cmd
select disk 0
```

Show information about the disk:

```cmd
detail disk
```

List its partitions and volumes:

```cmd
list partition
list volume
```

Confirm that:

- The disk is the intended internal disk.
- The disk size is correct.
- The disk uses GPT.
- The Windows volume is on this disk.
- The EFI partition is on the correct disk.
- You have not selected installation media or an external disk.
- You have not selected an old Windows disk.

Exit DiskPart:

```cmd
exit
```

Check the Windows volume:

```cmd
dir W:\Windows
dir W:\Users
dir "W:\Program Files"
dir W:\Windows\System32\Config
```

Check the EFI partition:

```cmd
dir S:\
dir S:\EFI
```

Do not continue if you are unsure about either volume.

---

## 3. BCDBoot Failed

The normal UEFI boot repair command is:

```cmd
bcdboot W:\Windows /s S: /f UEFI
```

A successful command normally displays:

```text
Boot files successfully created.
```

If BCDBoot displays an error, complete the following checks.

### 3.1 Check the Windows Volume

Run:

```cmd
dir W:\Windows
dir W:\Windows\System32
dir W:\Windows\Boot
```

These folders should exist.

If they do not exist, `W:` may be assigned to the wrong volume.

Return to DiskPart and identify the correct Windows volume.

### 3.2 Check the EFI Partition

Run:

```cmd
dir S:\
dir S:\EFI
```

The EFI System Partition should normally be:

- FAT32
- On a GPT disk
- On the intended Windows disk
- Approximately 100 MB to 500 MB
- Different from the recovery partition
- Different from Windows installation media

Do not use size as the only way to identify the EFI partition.

### 3.3 Check BitLocker

Check whether the Windows volume is locked:

```cmd
manage-bde -status W:
```

If the volume is locked, use the approved process to unlock it with the BitLocker recovery key.

After unlocking it, check the Windows folder again:

```cmd
dir W:\Windows
```

Do not:

- Disable BitLocker without approval.
- Decrypt the drive as part of normal boot recovery.
- Clear the TPM.
- Change Secure Boot settings without approval.

### 3.4 Check the EFI Partition for Free Space

Review the EFI volume:

```cmd
diskpart
list volume
select volume <EFIVolumeNumber>
detail volume
exit
```

Then inspect its files:

```cmd
dir S:\
dir S:\EFI
```

Do not delete files simply to create more space.

The EFI partition may contain files for:

- Windows
- The computer manufacturer
- Hardware diagnostics
- Recovery tools
- Another operating system

If the EFI partition is full, stop and escalate unless an approved procedure identifies files that can be removed safely.

### 3.5 Run BCDBoot Again

Run BCDBoot again only after confirming both volumes:

```cmd
bcdboot W:\Windows /s S: /f UEFI
```

Do not format the EFI partition because BCDBoot failed.

Formatting the partition may remove important boot, recovery, diagnostic, or manufacturer files.

### 3.6 Get More Detailed BCDBoot Output

Use verbose output if you need more information:

```cmd
bcdboot W:\Windows /s S: /f UEFI /v
```

Record the complete result in the support ticket.

---

## 4. BCDBoot Succeeds but Windows Does Not Start

A successful BCDBoot result means that Windows copied boot files to the selected EFI partition.

It does not prove that:

- The correct EFI partition was selected.
- The firmware uses that EFI partition.
- Windows Boot Manager exists in the firmware.
- Windows Boot Manager is first in the boot order.
- The firmware uses UEFI mode.
- The Windows installation is healthy.

Check that the Windows boot folder exists:

```cmd
dir S:\EFI\Microsoft\Boot
```

Restart the computer and open the UEFI boot menu or firmware settings.

Check that:

- The internal disk appears.
- UEFI mode is enabled.
- Windows Boot Manager appears.
- Windows Boot Manager is in the correct boot order.
- The computer is not trying to start from an old disk.
- Legacy BIOS or Compatibility Support Module mode is not enabled unexpectedly.

Do not manually create firmware boot entries unless an approved procedure requires it.

---

## 5. Windows Boot Manager Is Missing

Use this section if BCDBoot succeeds but Windows Boot Manager does not appear in the UEFI boot menu.

Confirm that:

- The firmware detects the internal disk.
- UEFI mode is enabled.
- The disk uses GPT.
- `S:` is the correct EFI partition.
- `S:\EFI\Microsoft\Boot` exists.
- BCDBoot wrote the files to the intended disk.
- The computer is not trying to start from another internal disk.

After checking these items, you may run BCDBoot again:

```cmd
bcdboot W:\Windows /s S: /f UEFI
```

Restart the computer and check the UEFI boot menu again.

### Computers with Multiple Internal Disks

If the computer has more than one internal disk:

1. Record every disk shown by DiskPart.
2. Record the size of each disk.
3. Record the partition layout of each disk.
4. Identify the disk containing the intended Windows installation.
5. Identify every FAT32 EFI partition.
6. Check which EFI partition contains Windows boot files.
7. Check which disk the firmware is trying to start.

Do not delete EFI partitions from other disks.

An old disk may contain the EFI partition that previously started Windows. If that disk was removed or failed, the remaining Windows disk may need boot files on its own EFI partition.

Escalate if the firmware entry cannot be restored using an approved procedure.

---

## 6. No Bootable Device

If the firmware reports that no bootable device exists, first check whether it can detect the internal disk.

### The Disk Is Missing from the Firmware

Check:

- Whether the drive appears in the firmware storage information
- Whether the drive is installed correctly
- Physical connections, if the device is serviceable
- Whether the storage controller is enabled
- Whether hardware diagnostics detect the drive
- Whether the drive appears only sometimes
- Whether the issue started after physical service or disk replacement

If the firmware cannot detect the disk, Windows repair commands are unlikely to help.

Escalate for hardware or storage diagnostics.

### The Disk Appears but Windows Boot Manager Is Missing

Check:

- UEFI boot mode
- GPT status
- The selected EFI partition
- The BCDBoot result
- `S:\EFI\Microsoft\Boot`
- The firmware boot order
- EFI partitions on other disks

### The Disk Appears in the Firmware but Not in WinRE

Possible causes include:

- Missing storage-controller drivers
- Intel VMD configuration
- RAID configuration
- A storage-mode change
- A damaged partition table
- A failing storage device
- Recovery media that does not include the required driver

Do not change RAID, AHCI, or Intel VMD settings as a test.

Changing the storage mode may stop Windows from accessing the disk and may trigger BitLocker recovery.

---

## 7. The Computer Starts from the Wrong Disk

This can happen when:

- The computer has multiple internal disks.
- A disk was cloned.
- An old Windows disk is still connected.
- A replacement disk was installed.
- The firmware boot order changed.
- Windows and the EFI partition are on different disks.

Check all disks:

```cmd
diskpart
list disk
list volume
```

For each suspected disk, run:

```cmd
select disk <DiskNumber>
detail disk
list partition
```

Record:

- Disk number
- Disk size
- GPT status
- Windows partition
- EFI partition
- Other operating-system partitions

Make sure `W:` is the intended Windows volume and `S:` is the intended EFI partition.

Then run:

```cmd
bcdboot W:\Windows /s S: /f UEFI
```

Do not delete or change files on another disk unless an approved migration or decommission process requires it.

---

## 8. Check the Windows File System

Use CHKDSK if file-system damage may be preventing Windows from starting.

First, confirm the Windows volume:

```cmd
dir W:\Windows
```

Run:

```cmd
chkdsk W: /f
```

The `/f` option repairs logical file-system errors.

Record the final CHKDSK summary.

Restart and test Windows after CHKDSK finishes.

### Check for Unreadable Sectors

Use `/r` only if there are signs of disk damage, such as:

- I/O errors
- Unreadable files
- Bad-sector warnings
- Repeated file-system corruption
- A volume that sometimes disappears
- Unusual noises from a mechanical disk

Run:

```cmd
chkdsk W: /r
```

The `/r` option includes `/f` and checks for unreadable sectors.

This scan can take a long time.

Do not interrupt it unless there is a clear reason to do so.

### When to Escalate

Escalate for storage diagnostics if CHKDSK reports:

- Bad sectors
- Unreadable data
- I/O errors
- A volume that cannot be accessed
- Corruption that returns after a restart
- A drive that repeatedly disappears
- A large number of repaired errors

CHKDSK can repair file-system problems. It cannot repair failing hardware.

---

## 9. Repair Windows System Files

Use DISM and SFC when Windows files may be damaged.

First, confirm the Windows volume:

```cmd
dir W:\Windows
```

Repair the Windows component store:

```cmd
dism /image:W:\ /cleanup-image /restorehealth
```

If DISM succeeds, run System File Checker:

```cmd
sfc /scannow /offbootdir=W:\ /offwindir=W:\Windows
```

Run DISM first because SFC may need the repaired component store to replace damaged files.

Record the result of both commands.

Restart and test Windows.

---

## 10. DISM Cannot Find the Source Files

DISM may need files from matching Windows installation media.

The repair source should match the installed Windows system as closely as possible:

- Architecture
- Language
- Edition
- Windows release
- Update level

Do not guess the image index.

### Find the Installation Image

Installation media normally contains one of these files:

```text
X:\sources\install.wim
```

or:

```text
X:\sources\install.esd
```

Replace `X:` with the letter assigned to the installation media.

Check which file exists:

```cmd
dir X:\sources\install.wim
dir X:\sources\install.esd
```

### Find the Correct Image Index

For a WIM file:

```cmd
dism /get-wiminfo /wimfile:X:\sources\install.wim
```

For an ESD file:

```cmd
dism /get-wiminfo /wimfile:X:\sources\install.esd
```

Find the index that matches the installed Windows edition.

### Use a WIM Source

```cmd
dism /image:W:\ /cleanup-image /restorehealth /source:wim:X:\sources\install.wim:<Index> /limitaccess
```

Example:

```cmd
dism /image:W:\ /cleanup-image /restorehealth /source:wim:X:\sources\install.wim:6 /limitaccess
```

The index in this example is only an example. Use the index shown by the `/get-wiminfo` command.

### Use an ESD Source

```cmd
dism /image:W:\ /cleanup-image /restorehealth /source:esd:X:\sources\install.esd:<Index> /limitaccess
```

After DISM succeeds, run:

```cmd
sfc /scannow /offbootdir=W:\ /offwindir=W:\Windows
```

Restart and test Windows.

---

## 11. SFC Cannot Repair Some Files

Run SFC with the correct offline Windows paths:

```cmd
sfc /scannow /offbootdir=W:\ /offwindir=W:\Windows
```

If SFC cannot repair some files:

1. Confirm that `W:` is the correct Windows volume.
2. Confirm that DISM completed successfully.
3. Run SFC again after DISM.
4. Record the final result.
5. Save the relevant logs for escalation.

Useful logs include:

```text
W:\Windows\Logs\CBS\CBS.log
W:\Windows\Logs\DISM\dism.log
```

Do not run SFC repeatedly if DISM failed or if the disk may be damaged.

---

## 12. Automatic Repair Loop

Use this section if Windows repeatedly displays:

```text
Preparing Automatic Repair
```

or:

```text
Diagnosing your PC
```

Possible causes include:

- Damaged boot files
- A failed Windows update
- File-system corruption
- Damaged Windows system files
- A failed boot driver
- Registry corruption
- Storage failure

Complete these repairs in order:

1. BCDBoot
2. CHKDSK
3. Offline DISM
4. Offline SFC

Restart and test Windows after each stage.

If the loop continues, record:

- Whether Safe Mode is available
- Whether System Restore is available
- Whether WinRE offers update removal
- When the problem began
- Which update or driver was installed recently
- Any stop or recovery code

Use the approved procedure for System Restore, update removal, or driver recovery.

Do not manually remove update files or edit the registry unless an approved procedure requires it.

---

## 13. Startup Failure After a Windows Update

If Windows stopped starting immediately after an update, open:

```text
Troubleshoot > Advanced options
```

Available recovery options may include:

- Uninstall latest quality update
- Uninstall latest feature update
- System Restore
- Startup Settings
- Command Prompt

Record:

- The update type
- When the update was installed
- Whether the update completed
- Whether the update was interrupted
- Whether WinRE offers rollback
- Whether a restore point is available
- Any displayed error code

Use the least disruptive approved option first.

Do not manually remove Windows servicing packages unless an approved procedure requires it.

---

## 14. Startup Failure After Disk Cloning or Replacement

Check:

- Whether the new disk uses GPT
- Whether the new disk has an EFI partition
- Whether the Windows and EFI partitions were both copied
- Whether BCDBoot targeted the new disk
- Whether the firmware still points to the old disk
- Whether both the old and new disks are connected
- Whether BitLocker recovery is expected

If the new disk has a valid Windows volume and EFI partition, confirm both and run:

```cmd
bcdboot W:\Windows /s S: /f UEFI
```

Restart the computer and select Windows Boot Manager for the new disk.

Do not erase or remove the old installation until:

- The new disk starts without the old disk.
- User data has been checked.
- Required applications and services work.
- BitLocker status has been reviewed.
- Organizational requirements have been met.

---

## 15. BitLocker Recovery After Boot Repair

Changes to boot files or firmware may cause BitLocker to ask for its recovery key.

If this happens:

1. Record the recovery prompt.
2. Verify the device using the approved asset process.
3. Get the approved recovery key.
4. Enter the key only on the verified device.
5. Continue startup.
6. Check BitLocker status after Windows starts.

Do not:

- Clear the TPM.
- Disable Secure Boot.
- Disable BitLocker without approval.
- Decrypt the drive as routine troubleshooting.
- Enter a recovery key on an unverified device.
- Save the recovery key in an unapproved location.

---

## 16. BOOTREC on UEFI Systems

BOOTREC is not part of the normal UEFI recovery process.

Do not automatically run:

```cmd
bootrec /fixmbr
bootrec /fixboot
bootrec /scanos
bootrec /rebuildbcd
```

On a UEFI and GPT system:

- `/fixmbr` repairs MBR boot code, which native UEFI startup does not normally use.
- `/fixboot` may display `Access is denied`.
- `/scanos` may fail to detect Windows even when the files are present.
- `/rebuildbcd` is usually not required after BCDBoot succeeds.
- BOOTREC cannot fix a wrongly selected EFI partition.
- BOOTREC cannot fix every firmware-entry problem.

Use BCDBoot for the normal UEFI boot repair:

```cmd
bcdboot W:\Windows /s S: /f UEFI
```

Use BOOTREC only when an approved procedure specifically requires it.

> [!IMPORTANT]
> If `bootrec /fixboot` displays `Access is denied`, do not keep repeating it.

---

## 17. Check Firmware and Storage Settings

Review the firmware settings if:

- The internal disk is missing.
- Windows Boot Manager is missing.
- The computer starts from the wrong disk.
- The problem began after a firmware update.
- The firmware settings were reset.
- WinRE cannot access the storage device.
- The computer was recently serviced.

Check:

- UEFI boot mode
- Windows Boot Manager
- Boot order
- Internal disk detection
- Secure Boot status
- RAID configuration
- AHCI configuration
- Intel VMD configuration
- Storage-controller detection
- Firmware version
- Whether firmware defaults were loaded recently

> [!WARNING]
> Do not change RAID, AHCI, Intel VMD, TPM, or Secure Boot settings as a test.
>
> Changing a storage setting may stop Windows from accessing the disk. Security changes may also trigger BitLocker recovery.

Record the original settings before making any approved change.

---

## 18. Multiple EFI Partitions

A computer may have more than one EFI partition when:

- It has multiple operating systems.
- It has multiple internal disks.
- A disk was cloned.
- An old Windows disk is still installed.
- A previous repair created another EFI partition.
- The manufacturer included its own boot tools.

For each EFI partition, record:

- Physical disk number
- Volume number
- Partition number
- File system
- Size
- Contents of the `EFI` folder
- Whether `EFI\Microsoft\Boot` exists
- Whether manufacturer files exist
- Whether another operating system uses it

Do not delete, combine, or format EFI partitions during normal troubleshooting.

Confirm which EFI partition the firmware uses before changing boot files.

If you cannot identify the correct EFI partition safely, stop and escalate.

---

## 19. View the BCD Store

The Boot Configuration Data store, also called the BCD store, contains Windows boot settings.

The UEFI BCD store is normally located at:

```text
S:\EFI\Microsoft\Boot\BCD
```

To view its contents, run:

```cmd
bcdedit /store S:\EFI\Microsoft\Boot\BCD /enum all
```

Record the output before making any advanced change.

Do not manually delete or recreate individual BCD entries unless an approved procedure requires it.

For normal UEFI recovery, use BCDBoot:

```cmd
bcdboot W:\Windows /s S: /f UEFI
```

---

## 20. Windows Starts Loading but Fails Before Sign-In

If the Windows logo appears, the EFI boot files may already be working.

The problem may instead involve:

- A failed update
- A damaged driver
- Registry corruption
- File-system corruption
- Damaged Windows system files
- Storage failure
- Security software
- A recently installed device
- A failed service

Complete these checks:

```cmd
chkdsk W: /f
```

```cmd
dism /image:W:\ /cleanup-image /restorehealth
```

```cmd
sfc /scannow /offbootdir=W:\ /offwindir=W:\Windows
```

You may also need an approved procedure for:

- Safe Mode
- System Restore
- Removing the latest update
- Driver rollback
- Hardware diagnostics

Do not keep rebuilding the EFI boot files if Windows Boot Manager already starts loading Windows.

---

## 21. Signs of Hardware Failure

Stop software repairs and escalate for hardware diagnostics if:

- The disk is missing from the firmware.
- The disk appears only sometimes.
- The volume repeatedly disappears.
- CHKDSK reports bad sectors.
- WinRE reports I/O errors.
- The system freezes while reading the disk.
- File-system corruption returns.
- Hardware diagnostics report storage errors.
- A mechanical disk makes unusual noises.
- The computer restarts or powers off unexpectedly.
- Memory diagnostics report an error.
- Multiple unrelated files become corrupted.

Do not repeatedly run repair commands against a disk that may be failing.

Prioritize:

1. Protecting user data
2. Following the approved backup process
3. Running approved hardware diagnostics
4. Replacing failed hardware
5. Escalating with the diagnostic results

---

## 22. Keyboard Symbol Reference

These mappings may help when WinRE treats a Portuguese ISO keyboard as an English US keyboard.

Keyboard models may differ. Test uncertain symbols on an empty command line first.

Common mappings:

- `:`: Hold **Shift** and press the key immediately to the right of `L`, commonly labelled `Ç`.
- `\`: Press the key immediately to the left of `Z`, commonly labelled `<` and `>`.
- `/`: Press the key immediately to the left of the right **Shift** key.
- `-`: Press the first key immediately to the right of `0`.
- `_`: Hold **Shift** and press the first key immediately to the right of `0`.
- `=`: Press the second key immediately to the right of `0`.

These mappings are guidance only.

---

## 23. Stop and Escalate

Stop and escalate if:

- You cannot confidently identify the correct Windows disk.
- You cannot confidently identify the correct EFI partition.
- The computer has multiple EFI partitions and their purpose is unclear.
- The Windows volume remains locked.
- The BitLocker recovery key is unavailable.
- The disk is missing from the firmware.
- The disk appears only sometimes.
- BCDBoot continues to fail after checking both volumes.
- Windows Boot Manager remains missing.
- CHKDSK reports bad sectors or I/O errors.
- DISM cannot repair Windows using an approved matching source.
- SFC repeatedly reports files it cannot repair.
- A firmware or storage-controller change may be required.
- A manual firmware entry may be required.
- User data may be at risk.
- Hardware failure is suspected.
- Reinstalling Windows is being considered.

Before reinstalling Windows, review:

- User data
- Backup status
- BitLocker status
- Recovery-key availability
- Available recovery options
- Application requirements
- Licensing requirements
- Device-management requirements
- Organizational approval

---

## 24. Information to Include When Escalating

Record the following information:

```text
Computer name:
Computer model:
Serial number:
Current user:
Technician:
Date:

Original startup error:
Current startup error:
Recent changes:
Recent Windows updates:
Firmware changes:
Disk replacement or cloning:

BitLocker enabled:
BitLocker recovery required:
Recovery key available:

UEFI mode confirmed:
Secure Boot status:
Internal disk detected:
Windows Boot Manager present:
Firmware boot order:

Physical disk number:
Physical disk size:
GPT confirmed:
Number of internal disks:

Windows volume number:
Windows temporary drive letter:
Windows directory verified:
Windows volume unlocked:

EFI volume number:
EFI partition number:
EFI temporary drive letter:
EFI file system:
EFI partition size:
Multiple EFI partitions present:

BCDBoot command:
BCDBoot result:
BCDBoot verbose result:

CHKDSK command:
CHKDSK summary:
Bad sectors reported:
I/O errors reported:

DISM command:
DISM source:
DISM image index:
DISM result:

SFC command:
SFC result:

Storage-controller mode:
RAID, AHCI, or VMD observations:
Hardware diagnostic result:

Windows started successfully:
User data verified:
Follow-up required:
Escalation reference:
```

Attach relevant:

- Photographs
- Screenshots
- Command output
- BCDBoot verbose output
- CHKDSK summary
- DISM logs
- CBS logs
- Firmware photographs
- Hardware diagnostic reports

Do not add passwords, BitLocker recovery keys, or other secrets to an unapproved ticket field.

---

## Advanced Troubleshooting Checklist

### Initial Checks

- [ ] Exact startup error recorded
- [ ] Error code recorded
- [ ] Recent changes recorded
- [ ] BitLocker status checked
- [ ] Windows volume unlocked
- [ ] Correct physical disk confirmed
- [ ] GPT status confirmed
- [ ] Correct Windows volume confirmed
- [ ] Correct EFI partition confirmed
- [ ] Drive letters rechecked after restart

### BCDBoot

- [ ] `W:\Windows` verified
- [ ] `S:` confirmed as FAT32
- [ ] EFI partition confirmed on the intended disk
- [ ] Available EFI space checked
- [ ] Existing EFI files preserved
- [ ] BCDBoot command recorded
- [ ] BCDBoot result recorded
- [ ] Verbose output recorded, if required
- [ ] `S:\EFI\Microsoft\Boot` verified

### Firmware

- [ ] Internal disk detected
- [ ] UEFI mode enabled
- [ ] Windows Boot Manager checked
- [ ] Boot order checked
- [ ] Multiple internal disks checked
- [ ] Multiple EFI partitions documented
- [ ] Storage-controller configuration reviewed
- [ ] No unauthorized firmware changes made

### Windows Repair

- [ ] CHKDSK `/f` completed, if required
- [ ] CHKDSK `/r` used only when disk damage was suspected
- [ ] CHKDSK result recorded
- [ ] Offline DISM completed, if required
- [ ] Matching repair source used, if required
- [ ] Correct WIM or ESD index confirmed
- [ ] Offline SFC completed
- [ ] Required logs saved

### Completion or Escalation

- [ ] Windows startup tested after each repair
- [ ] Hardware warning signs checked
- [ ] User-data risk assessed
- [ ] Backup status checked
- [ ] Reinstallation not started without review
- [ ] Escalation information completed
- [ ] Relevant logs and photographs attached