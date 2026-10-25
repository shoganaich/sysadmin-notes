# Service Desk Toolkit

A simple toolkit I built to speed up common Service Desk tasks: Active Directory lookups, account unlocks and password resets, and quick checks and actions on user computers.

The toolkit is started from a batch file, which opens a single PowerShell menu. Each function is its own PowerShell script, run inside that same session. Keeping the tools separate makes them easier to maintain, troubleshoot, and expand over time.

## Why I Built This

I found myself constantly jumping between Active Directory Users and Computers, PowerShell, Command Prompt, and various tools just to perform routine checks.

This project brings the most common AD tasks into a single menu-driven interface so day-to-day Service Desk work can be completed faster and more consistently.

## Features

### User Tools

#### Search User

Search for a user by username or display name and quickly view:

- Account status
- Job title
- Password expiry
- Custom attributes

#### Check Account Status

View detailed information about a user account, including:

- Enabled or disabled status
- Lockout status
- Password settings
- Account expiry
- Last logon information

#### Find Lockout Source

Finds which device keeps locking out an account, by reading lockout events (Event ID 4740) from the PDC emulator:

- Current lockout state, read from the PDC emulator
- Each lockout source device, with a count and the most recent time
- Option to search every domain controller if the PDC emulator has no events
- Next steps for the most common causes (saved credentials, phones, mapped drives)

#### View Group Memberships

Display the groups assigned to a user, including:

- Group name
- Group category
- Group scope

#### Find Group Approver

Shows who owns a group, so access requests go to the right approver:

- Searches by full or partial group name, with a pick list for multiple matches
- Group description and notes, which often name the approver
- Owner contact details, with a warning when the owner's account is disabled
- When the owner is a group, lists its members as possible approvers

### Computer Tools

#### Search Computer

Search for computers by name and view information such as:

- Operating system
- Enabled status
- Last logon date
- IP address
- Description

An optional ping test can also be performed.

#### Test Computer Connectivity

Checks that a computer exists in Active Directory, resolves its IP address, and performs basic connectivity tests.

This includes:

- DNS lookup
- Ping test
- Common remote management ports

#### View Computer Details

Displays useful computer information from Active Directory, including:

- Operating system
- Organizational Unit (OU)
- Location
- Last logon information
- Direct group memberships
- IP address

#### PC Health Check

One-screen health check of a remote computer:

- Signed-in user, model, serial number, OS and build
- Last boot and uptime
- Pending restart (Windows Update / servicing)
- CPU load and memory use
- Free space on every local disk
- Summary of warnings

Connects over WinRM, and falls back to DCOM (RPC) when WinRM is not available.

#### Check LAPS Information

Review Local Administrator Password Solution (LAPS) details for a computer, including:

- Computer account lookup
- LAPS password expiry information
- Local administrator account details

### Remote Actions

#### Send Message to User

Sends a pop-up message to everyone signed in to a computer:

- Shows the signed-in sessions first
- Ready-made Service Desk messages, or a custom message
- Confirmation before sending

The target must allow remote messages (`AllowRemoteRPC = 1` under `HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server`).

#### Remote Group Policy Update

Runs a Group Policy update on a remote computer:

- Uses `Invoke-GPUpdate` to refresh computer policy, signed-in user policy, or both
- Falls back to PowerShell remoting (computer policy only) when the Group Policy module isn't installed

### Network / DNS-DHCP Tools

#### Check DNS and DHCP Records

Review relevant DNS and DHCP details for a target device or record, including:

- DNS record resolution
- DHCP lease information
- Basic environment validation

### Administrative Actions

#### Unlock Account

- Displays the account before making changes
- Shows important status information
- Unlocks the account after confirmation
- Verifies the result

#### Reset Password

- Displays account details before resetting
- Supports hidden password entry
- Confirms the password before applying it
- Optionally requires a password change at next sign-in

## Repository Structure

```text
servicedesk-toolkit/
|-- README.md
|-- servicedesk-toolkit.bat        # Double-click launcher
|-- servicedesk-toolkit.ps1        # Menu (runs the tools in one session)
`-- scripts/
    |-- search-user.ps1
    |-- check-account-status.ps1
    |-- find-lockout-source.ps1
    |-- view-user-groups.ps1
    |-- find-group-approver.ps1
    |-- search-computer.ps1
    |-- test-computer-connectivity.ps1
    |-- view-computer-details.ps1
    |-- pc-health-check.ps1
    |-- check-laps-information.ps1
    |-- send-user-message.ps1
    |-- remote-gpupdate.ps1
    |-- check-dns-dhcp.ps1
    |-- unlock-account.ps1
    `-- reset-password.ps1
```

## Requirements

The toolkit was built and tested with:

- Windows PowerShell 5.1
- Active Directory PowerShell module
- RSAT Active Directory tools
- Access to an Active Directory domain

Some tools need additional modules:

| Tool | Additional requirement |
|---|---|
| Check LAPS information | Windows LAPS PowerShell module (`LAPS`) and permission to read LAPS passwords |
| Check DNS and DHCP records | DHCP Server RSAT tools (`DhcpServer` module) and permission to query the DHCP servers |
| Find lockout source | Permission to read the Security log on the domain controllers (for example **Event Log Readers**) |
| PC health check, Send message, Remote Group Policy update | Administrator rights on the target computer |
| Remote Group Policy update (user policy) | Group Policy Management RSAT tools (`GroupPolicy` module) |

The account running the toolkit will need appropriate permissions for the actions being performed.

Check whether the Active Directory module is installed:

```powershell
Get-Module ActiveDirectory -ListAvailable
```

## Usage

Double-click `servicedesk-toolkit.bat`, or run it from a command prompt:

```bat
servicedesk-toolkit.bat
```

The batch file starts PowerShell once with `-ExecutionPolicy Bypass` and opens the menu. This works on machines where running `.ps1` files directly is blocked by the default execution policy. It does not get around AppLocker or WDAC rules.

From an existing PowerShell window you can also run the menu directly:

```powershell
.\servicedesk-toolkit.ps1
```

Menu:

```text
Service Desk Toolkit
====================

User tools
----------
  1. Search user
  2. Check account status
  3. Find lockout source
  4. View group memberships
  5. Find group approver

Computer tools
--------------
  6. Search computer
  7. Test computer connectivity
  8. View computer details
  9. PC health check
 10. Check LAPS information

Remote actions
--------------
 11. Send message to user
 12. Remote Group Policy update

Network / DNS-DHCP
------------------
 13. Check DNS and DHCP records

Administrative actions
----------------------
 14. Unlock account
 15. Reset password

  Q. Exit
```

Select an option and follow the prompts. After the script finishes, press any key to return to the menu.


## Permissions

Most lookup and reporting functions only require standard domain access.

Administrative actions require delegated permissions:

- `Unlock-ADAccount`
- `Set-ADAccountPassword`
- `Set-ADUser` (for "change password at next sign-in")

The toolkit uses your existing Active Directory permissions. If you can't perform an action manually, the toolkit won't be able to perform it either.

## Security Notes

- Use the toolkit only in environments where you are authorized to perform these actions.
- Avoid storing passwords in scripts, tickets, screenshots, or logs.
- Use hidden password entry whenever possible.
- Always verify the selected account before making changes.
- Password resets remain subject to your organization's password policy.
- Accounts set to "Password never expires" can't also be set to "Change password at next sign-in". The reset tool warns about this before making any change.
- The `Attribute 5` / `Phone Number` columns read `extensionAttribute5`, which is specific to the environment the toolkit was built for. Change it to the attribute your organization uses.
- Test changes in a non-production environment before deployment.

## Notes

- The batch file only starts the menu. All menu logic is in `servicedesk-toolkit.ps1`.
- The Active Directory module is loaded once when the menu starts, so tools open quickly.
- Each tool is kept in its own PowerShell script and can still be run on its own.
- If a tool fails or exits with an error, you return to the menu instead of the toolkit closing.
- To add a tool, put the script in `scripts/` and add one line to the `$MenuItems` list in `servicedesk-toolkit.ps1`.
- A failed ping doesn't always mean a machine is offline. ICMP may be blocked in your environment.
- Some fields such as location, description, or ownership information will only appear if they are populated in Active Directory.

## Scope

This is an IT Operations / Service Desk toolkit: tools for answering and resolving tickets quickly with front-line permissions.

It covers on-premises Active Directory lookups, account unlocks and password resets, and quick remote checks and actions on user computers.

AD administration (creating users, changing group memberships, editing accounts), reporting and clean-up, Microsoft 365 administration, and infrastructure management are intentionally outside its scope.

## To Do

Ideas for future versions:

- [ ] Audit log: ask for a ticket number and log every unlock and password reset to a CSV
- [ ] Copy the ticket summary to the clipboard
- [ ] Search users by email address and UPN, not only username and display name
- [ ] Show the real last sign-in time (`lastLogon` from every DC, not `LastLogonDate`)
- [ ] Show nested group memberships
- [ ] BitLocker recovery key lookup
- [ ] Check sign-in restrictions (logon hours, "Log on to" computers)
- [ ] Shared module for the code repeated across the tool scripts

## Disclaimer

Always test changes using designated test accounts and devices before using the toolkit in production.

You are responsible for verifying the selected user or computer and following your organization's security, access, and change management procedures.