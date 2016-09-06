<#
    DESCRIPTION: 
        Check that remote desktop is enabled and that Network Level Authentication (NLA) is set



    PASS:    Secure remote desktop and NLA enabled
    WARNING: Network Level Authentication is not set
    FAIL:    Secure remote desktop disabled
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS: Check-NameSpace
#>

Function c-sys-16-remote-desktop
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Remote Desktop'
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
        $result.result  = 'Error'
        $result.message = 'SCRIPT ERROR'
        $result.data    = $_.Exception.Message
        Return $result
    }

    If (($check1 -eq '1') -and ($check2 -eq '1'))
    {
        $result.result  = 'Pass'
        $result.message = 'Secure remote desktop enabled'
    }
    Else
    {
        If ($check1 -eq '0')
        {
            $result.result  = 'Fail'
            $result.message = 'Secure remote desktop disabled'
        }
        Else
        {
            $result.result  = 'Warning'
            $result.message = 'Secure remote desktop enabled'
            $result.data    = 'Network Level Authentication is not set'
        }
    }

    Return $result
}