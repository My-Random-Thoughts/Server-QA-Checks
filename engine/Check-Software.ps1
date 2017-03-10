$script:appSettings['Win32_Product'] = 'Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
Function Check-Software
{
    Param ([string]$ServerName, [string]$DisplayName)
    Try {
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey($script:appSettings['Win32_Product'])
        If ($regKey) { [array]$keyVal = $regKey.GetSubKeyNames() } }
    Catch { Return '-1' }

    $found = $false
    If (($regKey) -and ($keyVal.Count -gt 0)) {
        ForEach ($app In $keyVal) {
            $appKey = $regKey.OpenSubKey($app).GetValue('DisplayName')
            If ($appKey -like ("*$displayName*")) {
                $found = $true
                [string]$verCheck = $regKey.OpenSubKey($app).GetValue('DisplayVersion')
                If (-not $verCheck) { $verCheck = '0.1' } } }
        If ($found -eq $false) {
            If ($script:appSettings['Win32_Product'] -like '*Wow6432Node*') {
                $script:appSettings['Win32_Product'] = $script:appSettings['Win32_Product'].Replace('Wow6432Node', '')
                $verCheck = Check-Software -ServerName $serverName -DisplayName $displayName }
            Else { $verCheck = $null } } }
    Else { $verCheck = $null }
    Try { $regKey.Close() } Catch { }
    $reg.Close()
    Return $verCheck
}