Function Check-HyperV
{
    Param ([string]$serverName)
    $wmiBIOS = Get-WmiObject -ComputerName $serverName -Class Win32_BaseBoard -Namespace ROOT\Cimv2 -ErrorAction Stop | Select-Object Product
    If ($wmiBIOS.Product -eq 'Virtual Machine') { Return $true } Else { Return $false }
}

Function Check-NameSpace
{
    Param ([string]$serverName, [string]$namespace)
    [string]$find = $namespace;  [string]$ns = 'ROOT'
    If ($namespace -like '*\*') { [string]$find = $namespace.Split('\')[-1]; [string]$ns = 'ROOT\' + $namespace.replace('\{0}' -f $find, '') }
    [array] $wmin = Get-WmiObject -ComputerName $serverName -Namespace $ns -Class '__Namespace' -ErrorAction Stop | Select-Object -ExpandProperty Name
    If ($wmin -contains $find) { Return $true } Else { Return $false }
}
