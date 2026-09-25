# AD Toolkit

A simple toolkit I built to speed up common Active Directory tasks handled by the Service Desk.

The toolkit uses a batch menu as the main launcher, with each function handled by its own PowerShell script. Keeping everything separate makes it easier to maintain, troubleshoot, and expand over time.

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

#### View Group Memberships

Display the groups assigned to a user, including:

- Group name
- Group category
- Group scope

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

#### Check LAPS Information

Review Local Administrator Password Solution (LAPS) details for a computer, including:

- Computer account lookup
- LAPS password expiry information
- Local administrator account details

### Network / DNS-DHCP Tools

#### Check DNS and DHCP Records

Review relevant DNS and DHCP details for a target device or record, including:

- DNS record resolution
- DHCP lease information
- Basic environment validation

#### Repair DNS Registration

Attempt to fix stale or broken DNS records for a selected computer.

#### Remove Stale DNS Records

Identify and remove outdated DNS entries that may no longer be valid.

#### Renew DHCP Lease Remotely

Trigger a DHCP lease refresh on a remote device when appropriate.

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
ad-toolkit/
|-- README.md
|-- ad-toolkit.bat
`-- scripts/
    |-- search-user.ps1
    |-- check-account-status.ps1
    |-- view-user-groups.ps1
    |-- search-computer.ps1
    |-- test-computer-connectivity.ps1
    |-- view-computer-details.ps1
    |-- unlock-account.ps1
    `-- reset-password.ps1
```

## Requirements

The toolkit was built and tested with:

- Windows PowerShell 5.1
- Active Directory PowerShell module
- RSAT Active Directory tools
- Access to an Active Directory domain

The account running the toolkit will need appropriate permissions for the actions being performed.

Check whether the Active Directory module is installed:

```powershell
Get-Module ActiveDirectory -ListAvailable
```

## Usage

Launch the toolkit from the batch file:

```bat
ad-toolkit.bat
```

Menu:

```text
AD Toolkit
==========

User tools
----------
1. Search user
2. Check account status
3. View group memberships

Computer tools
--------------
4. Search computer
5. Test computer connectivity
6. View computer details
7. Check LAPS information

Network / DNS-DHCP
------------------
8. Check DNS and DHCP records
9. Repair DNS registration
10. Remove stale DNS records
11. Renew DHCP lease remotely

Administrative actions
----------------------
12. Unlock account
13. Reset password

14. Exit
```

Select an option and follow the prompts. After the script finishes, press any key to return to the menu.

## Permissions

Most lookup and reporting functions only require standard domain access.

Administrative actions require delegated permissions:

- `Unlock-ADAccount`
- `Set-ADAccountPassword`
- `Set-ADUser`

The toolkit uses your existing Active Directory permissions. If you can't perform an action manually, the toolkit won't be able to perform it either.

## Security Notes

- Use the toolkit only in environments where you are authorized to perform these actions.
- Avoid storing passwords in scripts, tickets, screenshots, or logs.
- Use hidden password entry whenever possible.
- Always verify the selected account before making changes.
- Password resets remain subject to your organization's password policy.
- Test changes in a non-production environment before deployment.

## Notes

- The batch file only handles menu navigation and script launching.
- Each tool is kept in its own PowerShell script.
- Additional tools can be added without redesigning the entire project.
- A failed ping doesn't always mean a machine is offline. ICMP may be blocked in your environment.
- Some fields such as location, description, or ownership information will only appear if they are populated in Active Directory.

## Scope

This project focuses on on-premises Active Directory administration and common Service Desk tasks.

Workstation troubleshooting, networking diagnostics, Microsoft 365 administration, and infrastructure management are intentionally outside the scope of this toolkit.

## To Do

Missing or planned functions for the toolkit menu:

- [X] Check LAPS information
- [X] Check DNS and DHCP records
- [ ] Repair DNS registration
- [ ] Remove stale DNS records
- [ ] Renew DHCP lease remotely

## Disclaimer

Always test changes using designated test accounts and devices before using the toolkit in production.

You are responsible for verifying the selected user or computer and following your organization's security, access, and change management procedures.