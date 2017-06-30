<#
    DESCRIPTION: 
        Check that a specific list of services exist on the target server.  The friendly display name should be used.

    REQUIRED-INPUTS:
        SerivcesToCheck - List of services to check.  Enter the display name of the service.
        AllMustExist    - "True|False" - Should all services exist for a Pass.?

    DEFAULT-VALUES:
        SerivcesToCheck = ('')
        AllMustExist    = 'True'

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            All services were found
            One or more services were found
        WARNING:
        FAIL:
            One or more services were not found
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sys-22-installed-services
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-22-installed-services'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT DisplayName FROM Win32_Service WHERE DisplayName="dummyValue"'
        $script:appSettings['SerivcesToCheck'] | ForEach { $query += ' OR DisplayName="{0}"' -f $_ }
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
        ForEach ($service In $check)
        {
            


        }
    }

    If ($result.message -eq '')
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'All auto-start services are running'
        $result.data    = ''
    }
    
    Return $result
}
