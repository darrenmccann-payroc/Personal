#Requires -RunAsAdministrator
<#This script is to override the default route settings enabled upon connection to
Globalprotect. The interface metreic for the GP Adapter is set to automatic (default:20)
rather than '1' and set the route metric to more than the Hyper-V routes for any specified
route in the routing table#>
#Get GlobalProtect Interface
$GPInterface = Get-NetAdapter -InterfaceDescription "PANGP*"
if (-not $GPInterface) {
    Write-Warning "GlobalProtect adapter not found. Is GP connected?"
    return
}

$GPIPInterface = Get-NetIPInterface -InterfaceIndex $GPInterface.InterfaceIndex -ErrorAction SilentlyContinue
if (-not $GPIPInterface) {
    Write-Warning "GlobalProtect adapter found but has no active IP interface. Is GP connected?"
    return
}

#Get Hyper-V Interfaces
$HVInterfaces = get-netadapter -IncludeHidden |
    Where-Object {($_.InterfaceDescription -like "*Hyper-V*") -and ($_.MacAddress -ne "")}

#Get Routes used by Hyper-V (exclude Broadcast, Multicast & Default destinations)
$Routes = $HVInterfaces | ForEach-Object {
    Get-NetRoute -InterfaceIndex $_.InterfaceIndex |
    Where-Object {
        $_.DestinationPrefix -ne "255.255.255.255/32" -and
        $_.DestinationPrefix -ne "224.0.0.0/4" -and
        $_.DestinationPrefix -ne "0.0.0.0/0"
    }
}
$Routes = $Routes | Sort-Object DestinationPrefix -Unique


#Set the GlobalProtect interface to use Automatic Metric
Set-NetIPInterface -ifindex $GPInterface.InterfaceIndex -AutomaticMetric Enabled

#For Each Hyper-V Route, set the route metric for the GlobalProtect Interface
#to greater the Hyper-V interface metric
ForEach ($Route in $Routes){
    $Metric = $Route.InterfaceMetric + $Route.RouteMetric + 1

    Set-NetRoute -InterfaceIndex $GPInterface.InterfaceIndex `
        -DestinationPrefix $Route.DestinationPrefix `
        -RouteMetric $Metric -ErrorAction SilentlyContinue
}