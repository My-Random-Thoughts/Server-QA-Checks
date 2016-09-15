<#
    DESCRIPTION: 
        Check all local groups and ensure no additional groups exist. If there is a specific application requirement for local groups then
        these need to be documented with a designated team specified as the owner.
        If you use specific role groups, make sure they are excluded in the settings file.

    PASS:    No additional local accounts
    WARNING:
    FAIL:    One or more local groups exist
    MANUAL:
    NA:      Server is a domain controller

    APPLIES: All

    REQUIRED-FUNCTIONS: Check-DomainController
#>

Function c-acc-04-local-groups
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-acc-04-local-groups'

    #... CHECK STARTS HERE ...#

    Try
    {
        If ((Check-DomainController $serverName) -eq $false)
        {
            [string]$query = 'SELECT Name, SID FROM Win32_Group WHERE LocalAccount="True" AND NOT SID LIKE "S-1-5-32-%"'
            $script:appSettings['IgnoreTheseUsers'] | ForEach { $query += ' AND NOT Name LIKE "%{0}%"' -f $_ }
            [array]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Name
        }
        Else
        {
            [array]$check = '!!DCignore'
        }
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
        If ($check[0] -eq '!!DCignore')
        {
            $result.result  = $script:lang['Not-Applicable']
            $result.message = 'Server is a domain controller'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'One or more local groups exist'
            $check | ForEach { $result.data += '{0},#' -f $_ }
        }
    }
    Else
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'No additional local accounts'
    }
    Return $result
}