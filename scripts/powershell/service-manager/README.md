# Service Manager

A small PowerShell tool for managing Windows services on multiple computers from the terminal.

It can check, start, stop, or restart a configured service across a list of machines without having to connect to each one individually.

## What it does

- Accepts computer numbers, hostnames, and ranges
- Converts numbers into hostnames using a configured prefix
- Supports alternate hostname prefixes
- Checks whether each computer is reachable
- Lets you select a service from a configured list
- Supports:
  - Status
  - Start
  - Stop
  - Restart
- Shows the result for each computer when finished

## Files

```text
service-manager.ps1
service-manager-config.json
```

- `service-manager.ps1` contains the main script.
- `service-manager-config.json` contains the hostname settings and available services.

## Configuration

Settings are stored in `service-manager-config.json`.

Example:

```json
{
  "computerPrefix": "PC",
  "hostnameAliases": [
    "HOST",
    "PC"
  ],
  "maximumComputers": 500,
  "services": {
    "Application Service": "AppService",
    "Background Sync": "BackgroundSync",
    "File Watcher": "FileWatcher",
    "Monitoring Agent": "MonitoringAgent",
    "Web Server": "WebServer"
  }
}
```

### Options

**`computerPrefix`**

Default prefix used when only a computer number is entered.

For example, with:

```json
"computerPrefix": "PC"
```

Entering:

```text
020
```

becomes:

```text
PC020
```

**`hostnameAliases`**

Other hostname prefixes that are accepted as input.

For example:

```json
"hostnameAliases": [
  "HOST",
  "PC"
]
```

**`maximumComputers`**

Maximum number of computers that can be processed in one run. This mainly prevents accidentally entering a very large range.

**`services`**

Maps the name shown in the menu to the actual Windows service name.

For example:

```json
"Monitoring Agent": "MonitoringAgent"
```

`Monitoring Agent` is shown in the menu, while `MonitoringAgent` is the service name passed to Windows.

## Usage

Run the script from PowerShell:

```powershell
.\service-manager.ps1
```

The script will ask you to:

1. Enter the computers you want to target.
2. Select a service.
3. Select an action.
4. Confirm the operation.
5. Review the results.

## Computer input

You can enter a single computer:

```text
020
```

Multiple computers:

```text
020,030,112
```

A range:

```text
070-085
```

Or mix them together:

```text
020,030,070-085,112
```

Configured hostname aliases can also be entered directly:

```text
HOST020,PC030
```

Assuming the prefix is `PC`, this:

```text
020,030,070-072
```

would be expanded to:

```text
PC020
PC030
PC070
PC071
PC072
```

## Service actions

### Status

Checks the current state of the selected service.

### Start

Starts the service if it is not already running.

### Stop

Stops the service if it is not already stopped.

### Restart

Stops the service, waits for it to reach the `Stopped` state, and then starts it again.

The script waits for the service to reach the expected state before moving on.

## How remote service control works

The script does not open a PowerShell session on the remote computer.

It uses the .NET `ServiceController` class to communicate with the Windows Service Control Manager on the target machine.

For each computer, the basic process is:

```text
Check connectivity
        |
        v
Connect to service
        |
        v
Check current status
        |
        v
Perform requested action
        |
        v
Wait for service state
        |
        v
Record result
```

Each computer is handled separately, so if an operation fails on one machine, the script can continue with the others.

## Example

```text
Enter computers:
020,021,025-028

Resolved computers:
PC020
PC021
PC025
PC026
PC027
PC028

Select service:
> Monitoring Agent

Select action:
> Restart

Computers: 6
Service: Monitoring Agent
Action: Restart

Continue? Y

PC020    Success
PC021    Success
PC025    Success
PC026    Failed
PC027    Success
PC028    Success
```

## Requirements

- Windows
- PowerShell
- Network access to the target computers
- Permission to manage services on the target computers
- The configured services must exist on the target computers
- Remote Service Control Manager access must be allowed by the environment

A computer responding to ping does not necessarily mean the service operation will work. Firewall rules, RPC connectivity, permissions, or other security policies can still block remote service management.

## Troubleshooting

### Computer shows as unreachable

Check that:

- the hostname is correct
- the computer is online
- DNS is resolving the hostname
- the computer is reachable from your network
- ping is not being blocked

### Service not found

Make sure the value in the config is the actual Windows **service name**, not just its display name.

You can check service names in PowerShell with:

```powershell
Get-Service
```

### Access denied

Make sure the account running the script has permission to manage services on the remote computer.

### Service fails to start or stop

Check the service directly on the affected computer.

Possible causes include:

- service dependencies
- the service being disabled
- insufficient permissions
- the service taking too long to stop or start
- an application-specific error

The Windows Event Viewer may have more information about the failure.

## Notes

Be careful when running Stop or Restart against a large number of computers.

Before confirming an operation, check:

- the computer list
- the selected service
- the selected action

When testing a new configuration or service, it is a good idea to try it against one or two computers first.