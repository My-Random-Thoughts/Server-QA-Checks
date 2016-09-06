Function Check-NameSpace
{
    Param ( [string]$serverName, [string]$namespace )
    [string]$find = $namespace;  [string]$ns = 'ROOT'
    If ($namespace -like '*\*') { [string]$find = $namespace.Split('\')[-1]; [string]$ns = 'ROOT\' + $namespace.replace('\{0}' -f $find, '') }
    [array] $wmin = Get-WmiObject -ComputerName $serverName -Namespace $ns -Class '__Namespace' | Select-Object -ExpandProperty Name
    If ($wmin -contains $find) { Return $true } Else { Return $false }
}