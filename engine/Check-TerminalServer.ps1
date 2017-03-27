Function Check-TerminalServer
{
    Param ([string]$ServerName)
    Try {
        If ((Check-NameSpace -serverName $ServerName -namespace 'ROOT\Cimv2\TerminalServices' -ErrorAction Stop) -eq $true) {
            If ((Get-WmiObject -ComputerName $ServerName -Namespace ROOT\Cimv2\TerminalServices -List 'Win32_TerminalServiceSetting' -ErrorAction Stop).Name -eq 'Win32_TerminalServiceSetting') {
                $query = "SELECT TerminalServerMode FROM Win32_TerminalServiceSetting"
                $check = Get-WmiObject -ComputerName $ServerName -Query $query -Namespace ROOT\Cimv2\TerminalServices -Authentication PacketPrivacy -Impersonation Impersonate -ErrorAction Stop | Select-Object TerminalServerMode
                If ($check.TerminalServerMode -eq 1) { Return $true }
        } } }
    Catch { Return $false }
    Return $false
}

Function Check-NameSpace
{
    Param ([string]$ServerName, [string]$NameSpace)
    $NameSpace = $NameSpace.Trim('\')
    ForEach ($leaf In $NameSpace.Split('\')) {
        [string]$path += $leaf + '\'
        Try { [string]$wmio = Get-WmiObject -ComputerName $ServerName -Namespace $path.TrimEnd('\') -Class '__Namespace' -ErrorAction Stop | Select-Object -ExcludeProperty Name } Catch { }
        If ($wmio -eq '') { Return $false } Else { $wmio = '' } }
    Return $true
}
