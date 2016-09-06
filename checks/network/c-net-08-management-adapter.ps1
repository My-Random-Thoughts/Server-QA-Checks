<#
    DESCRIPTION: 
        Check that a management network adapter exists.
        This must always be present on a server and labelled correctly


    PASS:    Management network adapter found
    WARNING:
    FAIL:    No management network adapter
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-net-08-management-adapter
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Management Adapter'
    $result.check  = 'c-net-08-management-adapter'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT NetConnectionID FROM Win32_NetworkAdapter WHERE NetConnectionID = ""'
        $script:appSettings['ManagementAdapterNames'] | ForEach { $query += ' OR NetConnectionID LIKE "%{0}%"' -f $_ }
        [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty NetConnectionID
    }
    Catch
    {
        $result.result  = 'Error'
        $result.message = 'SCRIPT ERROR'
        $result.data    = $_.Exception.Message
        Return $result
    }

    $result.result  = 'Fail'
    $result.message = 'No management network adapter'

    If ([string]::IsNullOrEmpty($check) -eq $false)
    {
        If ($check.Count -gt 0)
        {
            $result.result  = 'Pass'
            $result.message = 'Management network adapter found'
        }
    }
    Else
    {
        $result.result  = 'Fail'
        $result.message = 'No management network adapter'
    }

    Return $result
}