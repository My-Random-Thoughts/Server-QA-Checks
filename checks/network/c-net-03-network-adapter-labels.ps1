<#
    DESCRIPTION: 
        Check network interfaces are labelled so their purpose is easily identifiable.
        FAIL if any Adapter Names are "Local Area Connection x" or "Ethernet x"


    PASS:    All adapters renamed from default
    WARNING:
    FAIL:    An adapter was found with the default name
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-net-03-network-adapter-labels
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Network Adapter Names'
    $result.check  = 'c-net-03-network-adapter-labels'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT NetConnectionID FROM Win32_NetworkAdapter WHERE NetConnectionID = ""'
        ('Local Area Connection', 'Ethernet') | ForEach { $query += ' OR NetConnectionID LIKE "%{0}%"' -f $_ }
        [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty NetConnectionID
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    $result.result  = $script:lang['Pass']
    $result.message = 'All adapters renamed from default'

    If ($check.Count -gt 0)
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'An adapter was found with the default name'
        $check | ForEach { $result.data += '{0},#' -f $_ }
    }

    Return $result
}