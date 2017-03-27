Function Check-VMware
{
    Param ([string]$ServerName)
    $wmiBIOS = Get-WmiObject -ComputerName $ServerName -Class Win32_BIOS -Namespace ROOT\Cimv2 -ErrorAction Stop | Select-Object SerialNumber
    If ($wmiBIOS.SerialNumber -like '*VMware*') { Return $true } Else { Return $false }        
}
