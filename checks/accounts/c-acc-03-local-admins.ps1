<#
    DESCRIPTION: 
        Check the local administrators group to ensure no non-standard accounts exist.
        If there is a specific application requirement for local administration access then these need to be well documented.

    REQUIRED-INPUTS:
        IgnoreTheseUsers - List of know user or groups accounts to ignore

    DEFAULT-VALUES:
        IgnoreTheseUsers = ('Domain Admins', 'Enterprise Admins')

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            No local administrators found
        WARNING:
            This is a workgroup server, is this correct.?
        FAIL:
            One or more local administrator accounts exist
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-acc-03-local-admins
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-acc-03-local-admins'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query1    = 'SELECT * FROM Win32_Group WHERE SID="S-1-5-32-544" AND LocalAccount="True"'
        [object]$WMIObject = Get-WmiObject -ComputerName $serverName -Query $query1 -Namespace ROOT\Cimv2
        [array] $check     = $WMIObject.GetRelated('Win32_Account', 'Win32_GroupUser', '', '', 'PartComponent', 'GroupComponent', $false, $null) | Select-Object -ExpandProperty Name

        [System.Collections.ArrayList]$check2 = @()
        $check | ForEach { $check2 += $_ }

        [string] $query2 = "SELECT PartOfDomain FROM Win32_ComputerSystem"
        [boolean]$domain = Get-WmiObject -ComputerName $serverName -Query $query2 -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty PartOfDomain
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }
 
    If ($domain -eq $true)
    {
        ForEach ($ck In $check)
        {
            ForEach ($exc In $script:appSettings['IgnoreTheseUsers'])
            {
                If ($ck -eq $exc) { $check2.Remove($ck) }
            }
        }

        If ($check2.count -gt 0)
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'One or more local administrator accounts exist'
            $check2 | ForEach { $result.data += '{0},#' -f $_ }
        }
        Else
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'No local administrators found'
        }
    }
    Else
    {
        $result.result  = $script:lang['Warning']
        $result.message = 'This is a workgroup server, is this correct.?'
    }

    Return $result
}