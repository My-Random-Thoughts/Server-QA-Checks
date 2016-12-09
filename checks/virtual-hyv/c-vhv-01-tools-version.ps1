<#
    DESCRIPTION: 
        Check that the latest HyperV integration services are installed



    PASS:    
    WARNING:
    FAIL:    Integration services not installed
    MANUAL:  Integration services found
    NA:      Not a virtual machine

    APPLIES: Virtuals

    REQUIRED-FUNCTIONS: Check-HyperV
#>

Function c-vhv-01-tools-version
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-vhv-01-tools-version'

    #... CHECK STARTS HERE ...#

    If ((Check-HyperV $serverName) -eq $true)
    {
        Try
        {
            $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
            $regKey = $reg.OpenSubKey('SOFTWARE\Microsoft\Virtual Machine\Auto')
            If ($regKey) { [string]$keyVal = $regKey.GetValue('IntegrationServicesVersion') }
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
            $result.message = 'Integration services not installed'
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a virtual machine'
    }

    Return $result
}