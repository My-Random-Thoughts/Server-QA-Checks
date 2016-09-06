<#
    DESCRIPTION: 
        Checks all services to ensure no user accounts are assigned. If specific application service accounts are required then they should be domain 
        level accounts (not local) and restricted from interactice access by policy.


    PASS:    No services found running under a local accounts
    WARNING:
    FAIL:    One or more services was found to be running under local accounts
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-acc-05-service-logon-accounts
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Service Logon Accounts'
    $result.check  = 'c-acc-05-service-logon-accounts'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT DisplayName, StartName FROM Win32_Service WHERE NOT DisplayName=""'
        $script:appSettings['IgnoreTheseUsers'] | ForEach { $query += ' AND NOT StartName = "{0}"' -f $_ }
        [object]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object DisplayName, StartName
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
        $result.result  = 'Warning'
        $result.message = 'One or more services was found to be running under local accounts'
        $check | ForEach { $result.data += '{0} ({1}),#' -f $_.DisplayName, $_.StartName }
    }
    Else
    {
        $result.result  = 'Pass'
        $result.message = 'No services found running under a local accounts'
    }
    
    Return $result
}