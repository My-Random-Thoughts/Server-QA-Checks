<#
    DESCRIPTION: 
        If server is a Terminal Services Server ensure it has a licence server set.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            Terminal services server is licenced
        WARNING:
        FAIL:
            Terminal services server is not licenced
        MANUAL:
        NA:
            Not a terminal services server

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        Check-TerminalServer
#>

Function c-sys-17-terminal-services-licenced
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-17-terminal-services-licenced'

    #... CHECK STARTS HERE ...#

    If ((Check-TerminalServer $serverName) -eq $true)
    {
        Try
        {
            $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
            $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\TermService\Parameters\LicenseServers')
            If ($regKey) { $keyVal = $regKey.GetValue('SpecifiedLicenseServers') }
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

        If ([string]::IsNullOrEmpty($keyVal) -eq $false)
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'Terminal services server is licenced'
            $result.data    = '' + $keyVal
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Terminal services server is not licenced'
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a terminal services server'
    }

    Return $result
}