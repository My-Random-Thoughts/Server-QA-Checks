Function Check-HyperV
{
    Param ([string]$ServerName)
    $wmiBIOS = Get-WmiObject -ComputerName $ServerName -Class Win32_BaseBoard -Namespace ROOT\Cimv2 -ErrorAction Stop | Select-Object Product
    If ($wmiBIOS.Product -eq 'Virtual Machine') { Return $true } Else { Return $false }
}