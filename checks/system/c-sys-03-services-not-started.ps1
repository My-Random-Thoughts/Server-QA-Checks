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
    $result.name   = 'Services Not Started'
    $result.check  = 'c-sys-03-services-not-started'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT DisplayName FROM Win32_Service WHERE StartMode="Auto" AND Started="False"'
        $script:appSettings['IgnoreTheseServices'] | ForEach {  $query += ' AND NOT DisplayName LIKE "%{0}%"' -f $_ }
        [array]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty DisplayName
    }
    Catch
    {
        $result.result  = 'Error'
        $result.message = 'SCRIPT ERROR'
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($check.Count -gt 0)
    {
        $result.result  = 'Fail'
        $result.message = 'An auto-start service was found not running'
        $check | ForEach { $result.data += '{0},#' -f $_ }
    }
    Else
    {
        $result.result  = 'Pass'
        $result.message = 'All auto-start services are running'
    }
    
    Return $result
}