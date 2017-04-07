<#
    DESCRIPTION: 
        Check that File And Print Services has been disabled on all adapters, except for those specified.

    REQUIRED-INPUTS:
        IgnoreTheseAdapters - List of names or partial names of network adapters to ignore

    DEFAULT-VALUES:
        IgnoreTheseAdapters = ('Production', 'PROD', 'PRD')

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            File And Print Services are disabled correctly
        WARNING:
        FAIL:
            File And Print Services are enabled
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-net-12-fileprint-services
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-net-12-fileprint-services'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT NetConnectionID, GUID FROM Win32_NetworkAdapter WHERE (NetConnectionStatus="2" OR NetConnectionStatus="7")'
        $script:appSettings['IgnoreTheseAdapters'] | ForEach { $query += ' AND (NOT NetConnectionID LIKE "%{0}%")' -f $_ }
        [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object NetConnectionID, GUID

        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('System\CurrentControlSet\Services\LanmanServer\Linkage')
        If ($regKey) { [string[]]$BindList = $regKey.GetValue('Bind') }
        Try {$regKey.Close()} Catch {}
        $reg.Close()
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    # Clean up and filter results
    [System.Collections.ArrayList]$arrBind = @()
    [System.Collections.ArrayList]$Enabled = @()
    ForEach ($item In $BindList) { If ($item.StartsWith('\Device\Tcpip_')) { $arrBind.Add($item.Split('_')[-1]) | Out-Null } }
    ForEach ($GUID In $check)    { If ($arrBind.Contains($GUID.GUID))      { $Enabled.Add($GUID)                | Out-Null } }

    If ($Enabled.Count -gt 0)
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'File And Print Services are enabled'
        $Enabled | ForEach { $result.data += "$($_.NetConnectionID),#" }
    }
    Else
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'File And Print Services are disabled correctly'
    }

    Return $result
}
