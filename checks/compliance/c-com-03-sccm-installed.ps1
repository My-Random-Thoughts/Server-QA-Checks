<#
    DESCRIPTION: 
        Check relevant SCCM agent is installed, and that the correct port is open to the management server



    PASS:    SCCM agent found, Port {0} open to {1}
    WARNING:
    FAIL:    SCCM agent not found, install required / SCCM agent found, Agent not configured with port and/or servername / SCCM agent found, Port {0} not open to {1}
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS: Test-Port
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
            [string]$valName = $regKey.GetValue('NetworkName'); If ($valName -eq '') { $valName = $regKey.GetValue('SMSSLP')    }
            [string]$valPort = $regKey.GetValue('Port')       ; If ($valPort -eq '') { $valPort = $regKey.GetValue('HttpsPort') }
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
                $result.message = 'SCCM agent found,#Port {0} open to {1}' -f $valPort, $valName
            }
            Else
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'SCCM agent found,#Port {0} not open to {1}' -f $valPort, $valName
            }
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'SCCM agent found,#Agent not configured with port and/or servername'
        }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'SCCM agent not found, install required'
    }

    Return $result
}
