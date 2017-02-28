<#
    DESCRIPTION: 
        Check that remote desktop is enabled and that Network Level Authentication (NLA) is set.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    RESULTS:
        PASS:
            Secure remote desktop and NLA enabled
        WARNING:
            Network Level Authentication is not set
        FAIL:
            Secure remote desktop disabled
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        Check-NameSpace
#>

Function c-sys-16-remote-desktop
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-16-remote-desktop'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        If ((Check-NameSpace -serverName $serverName -namespace 'Cimv2\TerminalServices') -eq $true)
        {
            [string]$query1 = 'Select AllowTSConnections FROM Win32_TerminalServiceSetting'
            [string]$check1 = Get-WmiObject -ComputerName $serverName -Query $query1 -Namespace ROOT\Cimv2\TerminalServices -Authentication PacketPrivacy -Impersonation Impersonate | Select-Object -ExpandProperty AllowTSConnections

            [string]$query2 = 'Select UserAuthenticationRequired FROM Win32_TSGeneralSetting'
            [string]$check2 = Get-WmiObject -ComputerName $serverName -Query $query2 -Namespace ROOT\Cimv2\TerminalServices -Authentication PacketPrivacy -Impersonation Impersonate | Select-Object -ExpandProperty UserAuthenticationRequired
        }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If (($check1 -eq '1') -and ($check2 -eq '1'))
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'Secure remote desktop enabled'
    }
    Else
    {
        If ($check1 -eq '0')
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Secure remote desktop disabled'
        }
        Else
        {
            $result.result  = $script:lang['Warning']
            $result.message = 'Secure remote desktop enabled'
            $result.data    = 'Network Level Authentication is not set'
        }
    }

    Return $result
}