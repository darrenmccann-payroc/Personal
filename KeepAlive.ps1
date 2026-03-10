Clear-Host
Write-Host "Keep Alive Script Running"

$WShell = New-Object -ComObject "WScript.Shell"
while($true) {
    if ($currentTime.Hour -ge 17) {
        Write-Host "It's 5:00 PM — script exiting."
        Stop-Computer -ComputerName $ENV:COMPUTERNAME
        break
        }
    Get-Date -Format HH:mm:ss
    $WShell.sendkeys("{SCROLLLOCK}")
    Start-Sleep -Milliseconds 100
    $WShell.sendkeys("{SCROLLLOCK}")
    Start-Sleep -Seconds 240
}