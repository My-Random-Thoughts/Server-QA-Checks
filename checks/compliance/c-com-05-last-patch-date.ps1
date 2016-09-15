<#
    DESCRIPTION: 
        Check server is compliant with patch policy (must be patched to latest released patch level for this customer)
        Check date of last patch and FAIL if not within 35 days


    PASS:    Windows patches applied
    WARNING: Server not patched within the last {0} days / Operating system not supported by check
    FAIL:    Server not patched within the last {0} days / No last patch date - server has never been updated
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-com-05-last-patch-date
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-com-05-last-patch-date'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT Caption FROM Win32_OperatingSystem'
        [string]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Caption

        If ($check -notlike '*2003*')
        {
            $session  = [activator]::CreateInstance([type]::GetTypeFromProgID('Microsoft.Update.Session', $serverName)) 
            $searcher = $session.CreateUpdateSearcher()
            $history  = $searcher.GetTotalHistoryCount()
            If ($history -gt 0) { [datetime]$check = $searcher.QueryHistory(0, 1) | Select-Object -ExpandProperty Date } Else { [datetime]$check = 0 }
        }
        Else
        {
            $result.result  = $script:lang['Warning']
            $result.message = 'Operating system not supported by check'
            $result.data    = ''
            Return $result
        }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($check -ne 0)
    {
        [int]$days = ((Get-Date) - $check).Days
        If ($days -gt ($script:appSettings['MaximumLastPatchAgeAllowed'] * 2))
        {
            # 2 months (using default setting)
            $result.result  = $script:lang['Fail']
            $result.message = 'Server not patched within the last {0} days' -f ($script:appSettings['MaximumLastPatchAgeAllowed'] * 2)
            $result.data    = 'Last patched: {0} ({1} days ago)' -f $check, $days
        }
        ElseIf ($days -gt $script:appSettings['MaximumLastPatchAgeAllowed'])
        {
            # 1 month (using default setting)
            $result.result  = $script:lang['Warning']
            $result.message = 'Server not patched within the last {0} days' -f $script:appSettings['MaximumLastPatchAgeAllowed']
            $result.data    = 'Last patched: {0} ({1} days ago)' -f $check, $days
        }
        Else
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'Windows patches applied'
            $result.data    = 'Last patched: {0} ({1} days ago)' -f $check, $days
        }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'No last patch date - server has never been updated'
    }

    Return $result
}