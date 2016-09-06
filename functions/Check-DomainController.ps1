Function Check-DomainController
{
    Param ( [string] $serverName )
    Try {
        $query = "SELECT DomainRole FROM Win32_ComputerSystem"
        $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object DomainRole
        If ($check.DomainRole -eq 4 -or $check.DomainRole -eq 5) { Return $true } }
    Catch { Return $false }
    Return $false
}
