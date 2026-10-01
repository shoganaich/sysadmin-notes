#requires -Version 5.1

<#
.SYNOPSIS
    Remote Computer Service Manager

.DESCRIPTION
    Terminal-based tool for managing remote Windows services on computers.
    1. Asks for one or more computer identifiers.
    2. Accepts individual numbers, comma-separated numbers, ranges, or mixed input.
    3. Lets you choose a service and action.
    4. Starts, stops, restarts, or checks a Windows service.
    5. Shows the result for every computer.

.EXAMPLES
    020
    020, 030, 040, 112, 150
    070-140
    020, 030, 070-085, 112, 150
#>

Add-Type -AssemblyName System.ServiceProcess

# ============================================================
# CONFIGURATION
# ============================================================

function Get-DefaultConfiguration {
    return [ordered]@{
        computerPrefix = ""
        hostnameAliases = @()
        maximumComputers = 500 # This is a fallback if not defined in the configuration file.
        services = [ordered]@{}
    }
}

function Get-ScriptConfiguration {
    $defaultConfig = Get-DefaultConfiguration
    $configPath = Join-Path -Path $PSScriptRoot -ChildPath "service-manager-config.json"

    if (-not (Test-Path -Path $configPath)) {
        throw "Missing configuration file '$configPath'. Create it with the computer prefix, hostname aliases, and service mappings."
    }

    try {
        $rawConfig = Get-Content -Path $configPath -Raw -ErrorAction Stop
        $loadedConfig = $rawConfig | ConvertFrom-Json -ErrorAction Stop

        $resolvedConfig = [ordered]@{
            computerPrefix = if ([string]::IsNullOrWhiteSpace([string]$loadedConfig.computerPrefix)) { $defaultConfig.computerPrefix } else { [string]$loadedConfig.computerPrefix }
            hostnameAliases = @(
                if ($null -ne $loadedConfig.hostnameAliases) {
                    @($loadedConfig.hostnameAliases)
                }
                else {
                    @($defaultConfig.hostnameAliases)
                }
            )
            maximumComputers = if ($null -ne $loadedConfig.maximumComputers) { [int]$loadedConfig.maximumComputers } else { [int]$defaultConfig.maximumComputers }
            services = [ordered]@{}
        }

        if ($null -ne $loadedConfig.services) {
            foreach ($property in $loadedConfig.services.PSObject.Properties) {
                $resolvedConfig.services[$property.Name] = [string]$property.Value
            }
        }

        if ([string]::IsNullOrWhiteSpace([string]$resolvedConfig.computerPrefix)) {
            throw "Configuration is missing 'computerPrefix'."
        }

        if ($resolvedConfig.services.Count -eq 0) {
            throw "Configuration is missing any services in 'services'."
        }

        return $resolvedConfig
    }
    catch {
        throw "Unable to load configuration from '$configPath': $($_.Exception.Message)"
    }
}

# Apply the configuration values loaded from the JSON file to the script variables.
$ScriptConfig = Get-ScriptConfiguration
$ComputerPrefix = $ScriptConfig.computerPrefix
$HostnameAliases = @($ScriptConfig.hostnameAliases)
$HostnameAliasPattern = (($HostnameAliases | Where-Object { $_ -and $_.Trim() } | ForEach-Object { [regex]::Escape($_.Trim()) }) -join "|")
$MaximumComputers = [int]$ScriptConfig.maximumComputers
$Services = $ScriptConfig.services

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Write-SectionHeader {
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Show-Message {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Title = "Service Manager"
    )

    Write-Host "`n[$Title]" -ForegroundColor Yellow
    Write-Host $Message -ForegroundColor White
}

function ConvertTo-ComputerList {
    param(
        [Parameter(Mandatory)]
        [string]$InputText
    )

    # Accept user input like 020, 030, 070-085, or mixed values and convert them to full hostnames.
    $numbers = New-Object System.Collections.Generic.List[int]

    if ([string]::IsNullOrWhiteSpace($InputText)) {
        throw "Enter at least one computer identifier."
    }

    $cleanInput = $InputText.Trim()
    $items = $cleanInput -split "[,;`r`n ]+" |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($item in $items) {
        $value = $item.Trim()
        $aliasPattern = if ($HostnameAliasPattern) { $HostnameAliasPattern } else { "" }

        if (-not [string]::IsNullOrWhiteSpace($aliasPattern)) {
            $value = $value -replace "(?i)^(?:$aliasPattern)", ""
        }

        if ($value -match "^(\d{1,4})-(?:$aliasPattern)?(\d{1,4})$") {
            $start = [int]$Matches[1]
            $end = [int]$Matches[2]

            if ($start -gt $end) {
                throw "Invalid range '$item'. The first number must be lower than the second number."
            }

            $rangeSize = ($end - $start) + 1

            if ($rangeSize -gt $MaximumComputers) {
                throw "Range '$item' contains $rangeSize computers. The maximum allowed is $MaximumComputers."
            }

            for ($number = $start; $number -le $end; $number++) {
                if (-not $numbers.Contains($number)) {
                    $numbers.Add($number)
                }
            }
        }
        elseif ($value -match "^\d{1,4}$") {
            $number = [int]$value

            if (-not $numbers.Contains($number)) {
                $numbers.Add($number)
            }
        }
        else {
            throw "Invalid computer entry: '$item'. Use examples such as 020, 030, or 070-140."
        }
    }

    if ($numbers.Count -eq 0) {
        throw "No valid computer identifiers were found."
    }

    if ($numbers.Count -gt $MaximumComputers) {
        throw "You selected $($numbers.Count) computers. The maximum allowed is $MaximumComputers."
    }

    $computers = @(
        $numbers |
            Sort-Object |
            ForEach-Object {
                "{0}{1:D3}" -f $ComputerPrefix, $_
            }
    )

    return $computers
}

function Test-ComputerConnection {
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName
    )

    try {
        return Test-Connection `
            -ComputerName $ComputerName `
            -Count 1 `
            -Quiet `
            -ErrorAction Stop
    }
    catch {
        return $false
    }
}

function Get-RemoteServiceController {
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [string]$ServiceName
    )

    # Connect to the Windows Service Control Manager on the remote host and select the service.
    $controller = New-Object System.ServiceProcess.ServiceController(
        $ServiceName,
        $ComputerName
    )

    $controller.Refresh()

    return $controller
}

function Invoke-ComputerServiceAction {
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [string]$ServiceName,

        [Parameter(Mandatory)]
        [ValidateSet("Check Status", "Start", "Stop", "Restart")]
        [string]$Action
    )

    # Perform one service action on a single remote computer and return a result object.
    $result = [ordered]@{
        Computer = $ComputerName
        Action   = $Action
        Service  = $ServiceName
        Status   = "Failed"
        Details  = ""
    }

    $serviceController = $null

    try {
        if (-not (Test-ComputerConnection -ComputerName $ComputerName)) {
            throw "Computer is offline, unreachable, or blocking ping."
        }

        $serviceController = Get-RemoteServiceController `
            -ComputerName $ComputerName `
            -ServiceName $ServiceName

        $serviceController.Refresh()
        $initialStatus = $serviceController.Status.ToString()

        switch ($Action) {
            "Check Status" {
                $result.Status = "Success"
                $result.Details = "Current service status: $initialStatus"
            }

            "Start" {
                if ($serviceController.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                    $result.Status = "Success"
                    $result.Details = "Service is already running."
                }
                else {
                    $serviceController.Start()
                    $serviceController.WaitForStatus(
                        [System.ServiceProcess.ServiceControllerStatus]::Running,
                        [TimeSpan]::FromSeconds(30)
                    )

                    $serviceController.Refresh()
                    $result.Status = "Success"
                    $result.Details = "Service started successfully. Status: $($serviceController.Status)"
                }
            }

            "Stop" {
                if ($serviceController.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Stopped) {
                    $result.Status = "Success"
                    $result.Details = "Service is already stopped."
                }
                elseif (-not $serviceController.CanStop) {
                    throw "The service does not accept stop commands."
                }
                else {
                    $serviceController.Stop()
                    $serviceController.WaitForStatus(
                        [System.ServiceProcess.ServiceControllerStatus]::Stopped,
                        [TimeSpan]::FromSeconds(30)
                    )

                    $serviceController.Refresh()
                    $result.Status = "Success"
                    $result.Details = "Service stopped successfully. Status: $($serviceController.Status)"
                }
            }

            "Restart" {
                # Restart the remote service by stopping it, waiting for the stopped state,
                # then starting it again and waiting for a healthy running state.
                if ($serviceController.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Stopped) {
                    if (-not $serviceController.CanStop) {
                        throw "The service does not accept stop commands and cannot be restarted."
                    }

                    $serviceController.Stop()
                    $serviceController.WaitForStatus(
                        [System.ServiceProcess.ServiceControllerStatus]::Stopped,
                        [TimeSpan]::FromSeconds(30)
                    )
                }

                Start-Sleep -Seconds 2

                $serviceController.Refresh()
                $serviceController.Start()
                $serviceController.WaitForStatus(
                    [System.ServiceProcess.ServiceControllerStatus]::Running,
                    [TimeSpan]::FromSeconds(30)
                )

                $serviceController.Refresh()
                $result.Status = "Success"
                $result.Details = "Service restarted successfully. Status: $($serviceController.Status)"
            }
        }
    }
    catch {
        $result.Status = "Failed"
        $result.Details = $_.Exception.Message
    }
    finally {
        if ($null -ne $serviceController) {
            $serviceController.Dispose()
        }
    }

    return [PSCustomObject]$result
}

function Select-Service {
    Write-Host "`nAvailable services:" -ForegroundColor Cyan

    $index = 1
    foreach ($displayName in $Services.Keys) {
        Write-Host ("{0,2}. {1}" -f $index, $displayName) -ForegroundColor White
        $index++
    }

    while ($true) {
        $selection = Read-Host "Select a service by number or name"

        if ([string]::IsNullOrWhiteSpace($selection)) {
            Write-Host "Please choose a service." -ForegroundColor Red
            continue
        }

        $trimmed = $selection.Trim()

        if ($trimmed -match "^\d+$") {
            $choice = [int]$trimmed
            if ($choice -ge 1 -and $choice -le $Services.Count) {
                $displayName = @($Services.Keys)[$choice - 1]
                return [PSCustomObject]@{
                    DisplayName = $displayName
                    ServiceName = $Services[$displayName]
                }
            }
        }

        foreach ($displayName in $Services.Keys) {
            if ($displayName -ieq $trimmed) {
                return [PSCustomObject]@{
                    DisplayName = $displayName
                    ServiceName = $Services[$displayName]
                }
            }
        }

        Write-Host "Invalid choice. Try a number or a service name from the list." -ForegroundColor Red
    }
}

function Select-Action {
    $options = @("Check Status", "Start", "Stop", "Restart")

    Write-Host "`nAvailable actions:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $options.Count; $i++) {
        Write-Host ("{0,2}. {1}" -f ($i + 1), $options[$i]) -ForegroundColor White
    }

    while ($true) {
        $selection = Read-Host "Choose an action by number or name"

        if ([string]::IsNullOrWhiteSpace($selection)) {
            Write-Host "Please choose an action." -ForegroundColor Red
            continue
        }

        $trimmed = $selection.Trim()

        if ($trimmed -match "^\d+$") {
            $choice = [int]$trimmed
            if ($choice -ge 1 -and $choice -le $options.Count) {
                return $options[$choice - 1]
            }
        }

        foreach ($option in $options) {
            if ($option -ieq $trimmed) {
                return $option
            }
        }

        Write-Host "Invalid action. Choose one of the listed actions." -ForegroundColor Red
    }
}

# ============================================================
# MAIN WORKFLOW
# ============================================================

Write-SectionHeader "Service Manager"
Write-Host "Examples: 020, 030, 070-140, 020, 030, 070-085, 112" -ForegroundColor DarkGray
Write-Host "Type 'q' or 'quit' at any prompt to exit." -ForegroundColor DarkGray

$applicationRunning = $true

while ($applicationRunning) {
    # Main loop: collect the target computers, choose the service and action, and apply it.
    Write-SectionHeader "Computer Selection"
    $input = Read-Host "Enter computers to manage"

    if ($input -match "^(q|quit|exit)$") {
        break
    }

    try {
        $computers = ConvertTo-ComputerList -InputText $input
    }
    catch {
        Show-Message -Message $_.Exception.Message -Title "Invalid computer input"
        continue
    }

    Write-Host "Selected computers: $($computers -join ', ')" -ForegroundColor Green

    $selectedService = Select-Service
    $selectedAction = Select-Action

    Write-SectionHeader "Confirmation"
    Write-Host "Number of computers: $($computers.Count)" -ForegroundColor White
    Write-Host "Service: $($selectedService.DisplayName)" -ForegroundColor White
    Write-Host "Windows service name: $($selectedService.ServiceName)" -ForegroundColor White
    Write-Host "Action: $selectedAction" -ForegroundColor White
    Write-Host "Computers: $($computers -join ', ')" -ForegroundColor White

    $proceed = Read-Host "Proceed with this operation? [Y/N]"
    if ($proceed -notmatch "^(y|yes)$") {
        Write-Host "Operation canceled." -ForegroundColor Yellow
        continue
    }

    Write-SectionHeader "Processing"
    $results = @()

    foreach ($computer in $computers) {
        $statusText = "Processing $computer..."
        Write-Host $statusText -ForegroundColor Cyan

        $result = Invoke-ComputerServiceAction `
            -ComputerName $computer `
            -ServiceName $selectedService.ServiceName `
            -Action $selectedAction

        $results += $result
    }

    Write-SectionHeader "Results"
    $results |
        Select-Object Computer, Service, Action, Status, Details |
        Format-Table -AutoSize

    $another = Read-Host "Run another operation? [Y/N]"
    if ($another -notmatch "^(y|yes)$") {
        $applicationRunning = $false
    }
}

Write-SectionHeader "Exit"
Write-Host "Service Manager closed." -ForegroundColor Green
