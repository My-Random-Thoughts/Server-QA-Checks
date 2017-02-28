<#
    DESCRIPTION: 
        Check relevant SCCM agent process is running, and that the correct port is open to the management server.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    RESULTS:
        PASS:
            SCCM agent found, port {port} open to {server}
        WARNING:
        FAIL:
            SCCM agent found, agent not configured with port and/or servername
            SCCM agent found, port {port} not open to {server}
            SCCM agent not found, install required
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        Test-Port
#>

Function c-com-03-sccm-installed
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-com-03-sccm-installed'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT Name FROM Win32_Process WHERE Name="CcmExec.exe"'
        [string]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Name
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    Try
    {
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('Software\Microsoft\CCM')
        If ($regKey) {
            [string]               $valPort = $regKey.GetValue('Port')           # SCCM 2007
            [string]               $valName = $regKey.GetValue('NetworkName')    # SCCM 2007
            If ($valPort -eq '') { $valPort = $regKey.GetValue('HttpsPort') }    # SCCM 2010+
            If ($valName -eq '') { $valName = $regKey.GetValue('SMSSLP')    }    # SCCM 2010+

            # Fall back check for hostname check
            If ($valName -eq '') { $regKey  = $reg.OpenSubKey('Software\Microsoft\CCM\FSP');
                                   $valName = $regKey.GetValue('HostName'); }
        }
        Try {$regKey.Close() } Catch {}
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
        If (([string]::IsNullOrEmpty($valName) -eq $false) -and ([string]::IsNullOrEmpty($valPort) -eq $false))
        {
            [boolean]$portTest = (Test-Port -serverName $valName -Port $valPort)
            If ($portTest -eq $true)
            {
                $result.result  = $script:lang['Pass']
                $result.message = 'SCCM agent found'
                $result.data    = 'Port {0} open to {1}' -f $valPort, $valName.ToLower()
            }
            Else
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'SCCM agent found'
                $resilt.data    = 'Port {0} not open to {1}' -f $valPort, $valName.ToLower()
            }
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'SCCM agent found'
            $result.data    = 'Agent not configured with port and/or servername'
        }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'SCCM agent not found, install required'
    }

    Return $result
}
