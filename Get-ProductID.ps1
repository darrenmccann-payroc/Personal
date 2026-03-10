
$Path = Read-Host "Enter filepath of MSI to check (e.g. C:\temp\example.msi)"
$msi = (Resolve-Path $Path).Path
$installer = New-Object -ComObject WindowsInstaller.Installer
$db = $installer.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $installer, @($msi, 0))
$query = $db.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $db, @("SELECT Value FROM Property WHERE Property='ProductCode'"))
$query.GetType().InvokeMember("Execute", "InvokeMethod", $null, $query, $null)
$record = $query.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $query, $null)
$record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, @(1))