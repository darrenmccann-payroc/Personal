#Define log Source
If (!(Get-EventLog -LogName Application -source Certificatecheck -erroraction SilentlyContinue)){
    New-EventLog -LogName Application -Source "CertificateCheck"
}


# Define the certificate expiration threshold (in days)
$thresholdDays = 30

# Get certificates that are expiring within the threshold
$certificates = Get-ChildItem -Recurse -Path Cert: | 
    Where-Object { ($_.NotAfter -lt (Get-Date).AddDays($thresholdDays))`
         -and ($_.NotAfter -gt (Get-Date)) }
# Check if there are any expiring certificates
if ($certificates.Count -gt 0) {
    # Create an event log entry with Event ID 64
    $eventLogMessage = "Found expiring certificates:`n"
    $eventLogMessage += $certificates | ForEach-Object { "Subject: $($_.Subject)`nExpiration Date: $($_.NotAfter)`n`n" }
    
    # Write the event log entry
    Write-EventLog -LogName Application -Source "CertificateCheck" -EntryType Information -EventID 64 -Message $eventLogMessage
} else {
    # No expiring certificates found
    Write-EventLog -LogName Application -Source "CertificateCheck" -EntryType Information -EventID 65 -Message "No expiring certificates found."
}