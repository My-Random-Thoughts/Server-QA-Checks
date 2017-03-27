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
