#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Shows who owns (approves access to) an Active Directory group.

.DESCRIPTION
    Searches for a group by name, then shows its "Managed By" owner and the
    group's description and notes, which often name the approver.

    - If the owner is a user, shows their contact details and warns when
      the account is disabled (for example, the owner has left).
    - If the owner is a group, lists its members as possible approvers.
    - If no owner is set, says so, so the request can be escalated.

.NOTES
    This script is read-only.
#>

$ErrorActionPreference = "Stop"

# Import the Active Directory module.
try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "Failed to import the Active Directory module." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    exit 1
}

Write-Host ""
Write-Host "Find Group Approver" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host ""

$SearchInput = Read-Host "Enter the group name (or part of it)"

if ([string]::IsNullOrWhiteSpace($SearchInput)) {
    Write-Host ""
    Write-Host "Please enter a group name." -ForegroundColor Yellow
    exit 1
}

$SearchInput = $SearchInput.Trim()
$SafeSearchInput = $SearchInput.Replace("'", "''")

$GroupProperties = @("Description", "info", "ManagedBy", "mail", "GroupCategory", "GroupScope", "whenChanged")

# Exact name first, then partial match.
try {
    $Groups = @(Get-ADGroup -Filter "Name -eq '$SafeSearchInput'" -Properties $GroupProperties -ErrorAction Stop)

    if ($Groups.Count -eq 0) {
        $Groups = @(
            Get-ADGroup -Filter "Name -like '*$SafeSearchInput*'" -Properties $GroupProperties -ErrorAction Stop |
                Sort-Object Name
        )
    }
}
catch {
    Write-Host ""
    Write-Host "An error occurred while searching for groups." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    exit 1
}

if ($Groups.Count -eq 0) {
    Write-Host ""
    Write-Host "No groups matching '$SearchInput' were found." -ForegroundColor Yellow
    exit 0
}

# Let the technician pick when there is more than one match.
if ($Groups.Count -gt 1) {
    $MaxShown = 30

    Write-Host ""
    Write-Host "Matching groups" -ForegroundColor Cyan
    Write-Host "---------------" -ForegroundColor Cyan

    $Shown = @($Groups | Select-Object -First $MaxShown)

    for ($Index = 0; $Index -lt $Shown.Count; $Index++) {
        $Desc = if ($Shown[$Index].Description) { " - $($Shown[$Index].Description)" } else { "" }

        if ($Desc.Length -gt 60) {
            $Desc = $Desc.Substring(0, 57) + "..."
        }

        Write-Host ("{0,3}. {1}{2}" -f ($Index + 1), $Shown[$Index].Name, $Desc)
    }

    if ($Groups.Count -gt $MaxShown) {
        Write-Host ""
        Write-Host "Showing $MaxShown of $($Groups.Count) matches. Use a more specific name to narrow it down." -ForegroundColor DarkGray
    }

    Write-Host ""
    $Selection = Read-Host "Select a group by number"

    if ($Selection -notmatch '^\d+$' -or [int]$Selection -lt 1 -or [int]$Selection -gt $Shown.Count) {
        Write-Host ""
        Write-Host "Invalid selection." -ForegroundColor Yellow
        exit 1
    }

    $Group = $Shown[[int]$Selection - 1]
}
else {
    $Group = $Groups[0]
}

# Group details.
$Description = if ($Group.Description) { $Group.Description } else { "N/A" }
$Notes = if ($Group.info) { $Group.info } else { "N/A" }

Write-Host ""
Write-Host "Group" -ForegroundColor Cyan
Write-Host "-----" -ForegroundColor Cyan
Write-Host ("{0,-16}: {1}" -f "Name", $Group.Name)
Write-Host ("{0,-16}: {1}" -f "Type", "$($Group.GroupCategory) / $($Group.GroupScope)")
Write-Host ("{0,-16}: {1}" -f "Description", $Description)
Write-Host ("{0,-16}: {1}" -f "Notes", $Notes)

if ($Group.mail) {
    Write-Host ("{0,-16}: {1}" -f "Email", $Group.mail)
}

# Owner.
Write-Host ""
Write-Host "Owner / Approver" -ForegroundColor Cyan
Write-Host "================" -ForegroundColor Cyan
Write-Host ""

if (-not $Group.ManagedBy) {
    Write-Host "No owner is set on this group (Managed By is empty)." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Check the description and notes above for an approver." -ForegroundColor DarkGray
    Write-Host "Otherwise, escalate the request according to your access-request process." -ForegroundColor DarkGray
    exit 0
}

try {
    $Owner = Get-ADObject `
        -Identity $Group.ManagedBy `
        -Properties objectClass, displayName, mail, telephoneNumber, title, department `
        -ErrorAction Stop
}
catch {
    Write-Host "The owner could not be read:" -ForegroundColor Yellow
    Write-Host $Group.ManagedBy -ForegroundColor DarkGray
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    exit 1
}

$OwnerName = if ($Owner.displayName) { $Owner.displayName } else { $Owner.Name }

if ($Owner.objectClass -eq "user") {
    $OwnerUser = $null

    try {
        $OwnerUser = Get-ADUser -Identity $Owner.DistinguishedName -Properties Enabled -ErrorAction Stop
    }
    catch {
        $OwnerUser = $null
    }

    Write-Host ("{0,-16}: {1}" -f "Owner", $OwnerName)

    if ($OwnerUser) {
        Write-Host ("{0,-16}: {1}" -f "Username", $OwnerUser.SamAccountName)
    }

    if ($Owner.title) { Write-Host ("{0,-16}: {1}" -f "Job title", $Owner.title) }
    if ($Owner.department) { Write-Host ("{0,-16}: {1}" -f "Department", $Owner.department) }
    if ($Owner.mail) { Write-Host ("{0,-16}: {1}" -f "Email", $Owner.mail) }
    if ($Owner.telephoneNumber) { Write-Host ("{0,-16}: {1}" -f "Phone", $Owner.telephoneNumber) }

    if ($OwnerUser -and -not $OwnerUser.Enabled) {
        Write-Host ""
        Write-Host "[WARNING] The owner's account is DISABLED. They may have left the organization." -ForegroundColor Yellow
        Write-Host "The group needs a new owner. Escalate according to your access-request process." -ForegroundColor Yellow
    }
}
elseif ($Owner.objectClass -eq "group") {
    Write-Host ("{0,-16}: {1} (group)" -f "Owner", $OwnerName)
    Write-Host ""
    Write-Host "The owner is a group. Its members can approve:" -ForegroundColor DarkGray
    Write-Host ""

    try {
        $Approvers = @(
            Get-ADGroupMember -Identity $Owner.DistinguishedName -ErrorAction Stop |
                Where-Object { $_.objectClass -eq "user" } |
                Sort-Object Name
        )

        if ($Approvers.Count -eq 0) {
            Write-Host "The owner group has no direct user members." -ForegroundColor Yellow
        }

        foreach ($Approver in $Approvers) {
            try {
                $ApproverUser = Get-ADUser -Identity $Approver.DistinguishedName -Properties DisplayName, mail, Enabled -ErrorAction Stop
                $Name = if ($ApproverUser.DisplayName) { $ApproverUser.DisplayName } else { $ApproverUser.Name }
                $Mail = if ($ApproverUser.mail) { $ApproverUser.mail } else { "" }
                $Color = if ($ApproverUser.Enabled) { "White" } else { "DarkGray" }
                $Status = if ($ApproverUser.Enabled) { "" } else { " (disabled)" }

                Write-Host ("  - {0,-30} {1}{2}" -f $Name, $Mail, $Status) -ForegroundColor $Color
            }
            catch {
                Write-Host ("  - {0}" -f $Approver.Name)
            }
        }
    }
    catch {
        Write-Host "Unable to list the owner group's members." -ForegroundColor Yellow
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkRed
    }
}
else {
    Write-Host ("{0,-16}: {1} ({2})" -f "Owner", $OwnerName, $Owner.objectClass)
}

exit 0
