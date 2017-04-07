<#
    DESCRIPTION: 
        Checks to see if there are any addional firewall rules, and warns if there are any.  This ignores all default pre-configured rules, and netbackup ports rules (1556, 13724).

    REQUIRED-INPUTS:
        IgnoreTheseFirewallAppRules - List of known firewall rules to ignore

    DEFAULT-VALUES:
        IgnoreTheseFirewallAppRules = ('Microsoft', 'McAfee', 'macmnsvc', 'System Center', 'nbwin', 'Java', 'Firefox', 'Chrome')

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            No additional firewall rules exist
        WARNING:
            One or more additional firewall rules exist, check they are required
        FAIL:
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sec-14-firewall-rules
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-14-firewall-rules'

    #... CHECK STARTS HERE ...#

    Try
    {
        [array]$check  = @()
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('System\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules')
        If ($regKey)
        {
            ForEach ($key In $regKey.GetValueNames())
            {
                [PSObject]$HashProps = @{ Active=$null; AppPath=$null; Direction=$null; EmbedCtxt=$null; Name=$null; RemotePort=$null }
                ForEach  ($FireWallRule In ($regkey.GetValue($key) -split '\|'))
                {
                    Switch (($FireWallRule -split '=')[0])
                    {
                        'Active'    { [string]$HashProps.Active      = ($FireWallRule -split '=')[1] }
                        'App'       { [string]$HashProps.AppPath     = ($FireWallRule -split '=')[1] }
                        'Dir'       { [string]$HashProps.Direction   = ($FireWallRule -split '=')[1] }
                        'EmbedCtxt' { [string]$HashProps.EmbedCtxt   = ($FireWallRule -split '=')[1] }
                        'Name'      { [string]$HashProps.Name        = ($FireWallRule -split '=')[1] }
                        'RPort'     { [array] $HashProps.RemotePort += ($FireWallRule -split '=')[1] }
                    }
                }
                If ((($HashProps.Name       -notlike     '@*'  ) -or ($HashProps.EmbedCtxt  -notlike     '@*'   )) -and `
                    (($HashProps.RemotePort -notcontains '1556') -or ($HashProps.RemotePort -notcontains '13724'))) { $check += (New-Object -TypeName PSObject -Property $HashProps) }
            }
        }
        Try { $regKey.Close() } Catch { }
        $reg.Close()
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ([string]::IsNullOrEmpty($check) -eq $false)
    {
        [System.Collections.ArrayList]$check2 = @(); $check | ForEach { $check2 += $_ }
        $check2 = $check2 | Sort-Object Direction, Name
        If ($script:appSettings['IgnoreTheseFirewallAppRules'].Length -gt 1) {
            $check | ForEach-Object {
                ForEach ($exclude In $script:appSettings['IgnoreTheseFirewallAppRules']) {
                    If ($_.Name -match $exclude) { $check2.Remove($_) }
                }
            }
        }

        If ($check2.count -gt 0)
        {
            $result.result  = $script:lang['Warning']
            $result.message = 'One or more additional firewall rules exist, check they are required'
            $check2 | ForEach-Object {
                If ($_.Active -eq 'False') {$act=' (Disabled)'} Else {$act=''}
                $result.data += '({0}) {1}{2},#' -f $_.Direction, $_.Name, $act }
        }
        Else
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'No additional firewall rules exist'
        }
    }
    Else
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'No additional firewall rules exist'
    }

    Return $result
}