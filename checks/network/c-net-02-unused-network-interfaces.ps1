<#
    DESCRIPTION: 
        Check there are no unused Network interfaces on the server. We define "not in use" by showing any ENABLED NICs set to DHCP
        All NICs should have a statically assigned IP address.


    PASS:    No DHCP enabled adapters found
    WARNING:
    FAIL:    DHCP enabled adapters found
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-net-02-unused-network-interfaces
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-net-02-unused-network-interfaces'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled="TRUE" AND DHCPEnabled="TRUE"'
        [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2
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
        $result.result  = $script:lang['Fail']
        $result.message = 'DHCP enabled adapters found'
        $check | ForEach {
            $nicName = $_.GetRelated('Win32_NetworkAdapter') | Select-Object -ExpandProperty NetConnectionID
            $result.data += '{0},#' -f $nicName
        }
    }
    Else
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'No DHCP enabled adapters found'
    }

    Return $result
}