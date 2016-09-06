Function Check-HyperV
{
    Param ( [string] $serverName )
    $wmiBIOS = Get-WmiObject -ComputerName $serverName -Class Win32_BaseBoard -Namespace ROOT\Cimv2 | Select-Object Product
    If ($wmiBIOS.Product -eq 'Virtual Machine') { Return $true } Else { Return $false }
}

