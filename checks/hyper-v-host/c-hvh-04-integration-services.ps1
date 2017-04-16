<#
    DESCRIPTION: 
        Check the version of the Integration Services.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:    
        WARNING:
        FAIL:
            Registry setting not found
        MANUAL:
            Integration services found
        NA:
            Not a Hyper-V server

    APPLIES:
        Hyper-V Host Servers

    REQUIRED-FUNCTIONS:
        Check-NameSpace
#>

Function c-hvh-04-integration-services
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-hvh-04-integration-services'
 
    #... CHECK STARTS HERE ...#

    If ((Check-NameSpace -ServerName $serverName -NameSpace 'ROOT\Virtualization') -eq $true)
    {
        Try
        {
            $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
            $regKey = $reg.OpenSubKey('SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization\GuestInstaller\Version')
            If ($regKey) { [string]$keyVal = $regKey.GetValue('Microsoft-Hyper-V-Guest-Installer') }
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
            $result.result  = $script:lang['Manual']
            $result.message = 'Integration services found'
            $result.data    = ('Version: {0}' -f $keyVal)
        }
        Else
        {
            $result.result  = $script:lang['fail']
            $result.message = 'Registry setting not found'
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a Hyper-V host server'
    }

    Return $result
}
