<#
.SYNOPSIS
Get-DiskInventory retrieves logical disk information from one ormore computers.
.DESCRIPTION
Get-DiskInventory uses CIM to retrieve the Win32_LogicalDiskinstances from one or more computers. 
It displays each disk'sdrive letter, free space, total size, and percentage of freespace.
.PARAMETER 
computernameThe computer name, or names, to query. Default: Localhost.
.PARAMETER 
drivetypeThe drive type to query. See Win32_LogicalDisk documentationfor values. 3 is a fixed disk, and is the default.
.EXAMPLEGet-DiskInventory -computername SRV02 -drivetype 3
#>
param (  $computername = 'localhost', $drivetype = 3)
Get-CimInstance -class Win32_LogicalDisk -computername $computername ` -filter "drivetype=$drivetype" | 
    Sort-Object -property DeviceID | Format-Table -property DeviceID,     
        @{label = 'FreeSpace(MB)'; expression = { $_.FreeSpace / 1MB -as [int] } },     
        @{label = 'Size(GB'; expression = { $_.Size / 1GB -as [int] } },     
        @{label = '%Free'; expression = { $_.FreeSpace / $_.Size * 100 -as [int] } }