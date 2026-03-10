Function Get-BigFolder {
<#
.SYNOPSIS
Lists sizes of directories in a given path in MB
.DESCRIPTION
Lists sizes of directories in a given path in MB. Default is current working directory
.PARAMETER PATH
Path to check subdirectories of
Default is current directory
.EXAMPLE
Get-Bigfolder -Path 'C:\Programdata'

Name                             Value
----                             -----
C:\programdata\Medialogix        1486
C:\programdata\Microsoft         219
C:\programdata\McAfee            80
C:\programdata\Oracle            69
C:\programdata\Citrix            62
C:\programdata\Package Cache     38
C:\programdata\Commvault Systems 2
C:\programdata\GroupPolicy       2
C:\programdata\TechSmith         1
C:\programdata\VMware            1
C:\programdata\Adobe             0
C:\programdata\ATI               0
C:\programdata\Microsoft Help    0
C:\programdata\Intel             0
C:\programdata\Xerox             0
C:\programdata\WinZip            0
#>
[cmdletbinding()]
    param (
        [Parameter(ValueFromPipeline=$False,
		          HelpMessage="Folder Path")]
                  [string[]]$PATH = "."
     )
    #List Folder Sizes
    $ITEMS = get-childitem -path $PATH -Force | Where-Object {$_.PSIscontainer -eq $TRUE}
    #Gather Folder Sizes  
    $DIRECTORIES = @{}  
    Foreach ($DIR in $ITEMS) {
        $SUBITEM = get-Childitem $DIR.FullName -recurse -force -erroraction silentlycontinue |
        Where-Object {$_.PSIsContainer -eq $FALSE} |
        Measure-Object -property Length -Sum | 
        Select-Object Sum 
        $DIRECTORIES.ADD($DIR.Fullname,($SUBITEM.sum / 1MB -as [int]))
   
    }
    $DIRECTORIES.GetEnumerator() | Sort-Object -Property Value -Descending | Format-Table -AutoSize
}