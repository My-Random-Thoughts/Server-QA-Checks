Function Check-VMware
{
    Param ( [string] $serverName )
    $wmiBIOS = Get-WmiObject -ComputerName $serverName -Class Win32_BIOS -Namespace ROOT\Cimv2 | Select-Object SerialNumber
    If ($wmiBIOS.SerialNumber -like '*VMware*') { Return $true } Else { Return $false }        
}
