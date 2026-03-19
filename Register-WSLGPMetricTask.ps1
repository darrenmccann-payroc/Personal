#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Registers a Scheduled Task to run Set-WSL_GP_Metric.ps1 when a network connects.

.DESCRIPTION
    Creates a Task Scheduler entry that triggers on Windows network connection events
    (Microsoft-Windows-NetworkProfile/Operational, Event ID 10000).

    The event is generic and fires for any network connection (Wi-Fi, Ethernet, VPN, etc.),
    so a 10-second delay is added to allow the GlobalProtect IP interface time to initialize.
    Set-WSL_GP_Metric.ps1 contains its own guards and exits cleanly if GP is not connected.

.NOTES
    Run this script once to register the task. After that, the task runs automatically.
    To remove the task: Unregister-ScheduledTask -TaskName "Set-WSL_GP_Metric" -Confirm:$false
#>

$taskName   = "Set-WSL_GP_Metric"
$scriptPath = "C:\scripts\Github\Personal\Set-WSL_GP_Metric.ps1"

# --- Trigger ---
# Fires on Event ID 10000 (network connected) in the NetworkProfile operational log.
# The event does not identify the adapter by name, so we rely on the script's own
# adapter/IP-interface checks rather than filtering here.
$CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler
$trigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
$trigger.Subscription = @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational">
    <Select Path="Microsoft-Windows-NetworkProfile/Operational">
      *[System[EventID=10000]]
    </Select>
  </Query>
</QueryList>
"@
$trigger.Enabled = $true
$trigger.Delay   = "PT10S"  # Wait 10s after the event — gives GP time to assign an IP interface

# --- Action ---
# Run PowerShell hidden so there's no console window flash on every network connect.
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

# --- Settings ---
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

# --- Principal ---
# Run as the current user with highest privileges (elevated).
# LogonType Interactive means no stored password is required,
# but the task only runs when the user is logged on.
$principal = New-ScheduledTaskPrincipal `
    -UserId    (whoami) `
    -RunLevel  Highest `
    -LogonType Interactive

# --- Register ---
Register-ScheduledTask `
    -TaskName    $taskName `
    -Trigger     $trigger `
    -Action      $action `
    -Settings    $settings `
    -Principal   $principal `
    -Description "Sets WSL/Hyper-V route metrics when GlobalProtect VPN connects. Triggered by network connection events." `
    -Force

Write-Host "Task '$taskName' registered successfully." -ForegroundColor Green
Write-Host "To remove: Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false"
