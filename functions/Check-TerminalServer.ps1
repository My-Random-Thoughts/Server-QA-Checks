Function Check-TerminalServer
{
    Param ( [string] $serverName )
    Try {
        # CHECK: Terminal Server...
        If ((Check-NameSpace -serverName $serverName -namespace 'Cimv2\TerminalServices') -eq $true) {
            If ((Get-WmiObject -ComputerName $serverName -Namespace ROOT\Cimv2\TerminalServices -List 'Win32_TerminalServiceSetting').Name -eq 'Win32_TerminalServiceSetting') {
                $query = "SELECT TerminalServerMode FROM Win32_TerminalServiceSetting"
                $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2\TerminalServices -Authentication PacketPrivacy -Impersonation Impersonate | Select-Object TerminalServerMode
                If ($check.TerminalServerMode -eq 1) { Return $true }
        } } }
    Catch { Return $false }
    Return $false
}

Function Check-NameSpace
{
    Param ( [string]$serverName, [string]$namespace )
    [string]$find = $namespace;  [string]$ns = 'ROOT'
    If ($namespace -like '*\*') { [string]$find = $namespace.Split('\')[-1]; [string]$ns = 'ROOT\' + $namespace.replace('\{0}' -f $find, '') }
    [array] $wmin = Get-WmiObject -ComputerName $serverName -Namespace $ns -Class '__Namespace' | Select-Object -ExpandProperty Name
    If ($wmin -contains $find) { Return $true } Else { Return $false }
}