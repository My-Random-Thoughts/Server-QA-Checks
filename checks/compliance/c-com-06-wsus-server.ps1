<#
    DESCRIPTION: 
        Check that a WSUS server has been specified and that the correct port is open to the management server.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            WSUS server configured, port {port} open to {server}
        WARNING:
        FAIL:
            WSUS server configured, port {port} not open to {server}
            WSUS server has not been configured
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        Check-Port
#>

Function c-com-06-wsus-server
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-com-06-wsus-server'

    #... CHECK STARTS HERE ...#

    Try
    {
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('Software\Policies\Microsoft\Windows\WindowsUpdate')
        If ($regKey) { [string]$keyVal = ($regKey.GetValue('WUServer')).ToLower() }
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
        $result.message = 'WSUS server configured'
        $result.data    = $keyVal

        $keyVal = $keyVal.Replace('http://', '').Replace('https://', '')
        If ($keyVal.Contains(':') -eq $true) { [string]$name = ($keyVal.Split(':')[0]); [string]$port = $keyVal.Split(':')[1] }
        Else {                                 [string]$name =  $keyVal;                [string]$port = 80                    }

        [boolean]$portTest = (Check-Port -serverName $name -Port $port)
        If   ($portTest -eq $true) {                   $result.data += (',#Port {0} open to {1}'     -f $port, $name.ToLower()) }
        Else { $result.result = $script:lang['Fail'];  $result.data += (',#Port {0} not open to {1}' -f $port, $name.ToLower()) }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'WSUS server has not been configured'
    }

    Return $result
}
