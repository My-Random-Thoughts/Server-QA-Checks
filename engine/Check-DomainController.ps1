Function Check-DomainController
{
    Param ([string]$ServerName)
    Try {
        $query = "SELECT DomainRole FROM Win32_ComputerSystem"
        $check = Get-WmiObject -ComputerName $ServerName -Query $query -Namespace ROOT\Cimv2 -ErrorAction Stop | Select-Object DomainRole
        If ($check.DomainRole -eq 4 -or $check.DomainRole -eq 5) { Return $true } }
    Catch { Return $false }
    Return $false
}
