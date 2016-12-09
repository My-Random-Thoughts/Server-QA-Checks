<#
    DESCRIPTION: 
        Check services and ensure all services set to start automatically are running (NetBackup Bare Metal Restore Boot Server, 
        NetBackup SAN Client Fibre Transport Service and .NET4.0 are all expected to be Automatic but not running)


    PASS:    All auto-start services are running
    WARNING:
    FAIL:    An auto-start service was found not running
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-sys-03-services-not-started
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-03-services-not-started'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT Name, DisplayName FROM Win32_Service WHERE StartMode="Auto" AND Started="False"'
        $script:appSettings['IgnoreTheseServices'] | ForEach {  $query += ' AND NOT DisplayName LIKE "%{0}%"' -f $_ }
        [array]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object Name, DisplayName
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($check.Count -gt 0)
    {
        $check | ForEach {
            Try
            {
                # Check for and ignore "Trigger Start" services
                $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
                $regKey = $reg.OpenSubKey("SYSTEM\CurrentControlSet\Services\$($_.Name)\TriggerInfo\0")
                Try { $regKey.Close() } Catch { }
                $reg.Close()
            }
            Catch { }

            If (-not $regKey)
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'An auto-start service was found not running'
                $result.data   += '{0},#' -f $($_.DisplayName)
            }
        }
    }
    Else
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'All auto-start services are running'
    }
    
    Return $result
}
