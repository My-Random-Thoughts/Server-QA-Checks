<#
    DESCRIPTION: 
        Check all local users to ensure that no non-standard accounts exist.  Unless the server is not in a domain, there should be no additional user accounts.
        Example standard accounts include "ASPNET", "__VMware"


    PASS:    No additional local accounts exist
    WARNING:
    FAIL:    One or more local accounts exist
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-acc-01-local-users
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Local Users'
    $result.check  = 'c-acc-01-local-users'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string] $query1 = "SELECT Name FROM Win32_UserAccount WHERE LocalAccount='True'"
        $script:appSettings['IgnoreTheseUsers'] | ForEach { $query1 += ' AND NOT Name LIKE "%{0}%"' -f $_ }
        [array]  $check  = Get-WmiObject -ComputerName $serverName -Query $query1 -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Name

        [string] $query2 = "SELECT PartOfDomain FROM Win32_ComputerSystem"
        [boolean]$domain = Get-WmiObject -ComputerName $serverName -Query $query2 -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty PartOfDomain
    }
    Catch
    {
        $result.result  = 'Error'
        $result.message = 'SCRIPT ERROR'
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($domain -eq $true)
    {
        If ($check.Count -gt 0)
        {
            $result.result  = 'Fail'
            $result.message = 'One or more local accounts exist'
            $check | ForEach { $result.data += '{0},#' -f $_ }
        }
        Else
        {
            $result.result  = 'Pass'
            $result.message = 'No additional local accounts'
        }
    }
    Else
    {
        $result.result  = 'Warning'
        $result.message = 'This is a workgroup server, is this correct.?'
    }

    Return $result
}