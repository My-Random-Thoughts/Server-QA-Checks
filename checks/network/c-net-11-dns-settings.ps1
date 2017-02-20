<#
    DESCRIPTION: 
        Checks that all DNS servers are configured, and if required, in the right order



    PASS:    All DNS servers configured (and in the right order)
    WARNING:
    FAIL:    DNS Server count mismatch / Mismatched DNS servers / No DNS servers are configured / DNS Server list is not in the required order
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-net-11-dns-settings
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-net-11-dns-settings'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT DNSServerSearchOrder FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled="TRUE"'
        [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty DNSServerSearchOrder
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
        If (($check.Count) -ne ($script:appSettings['DNSServers'].Count))
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'DNS Server count mismatch'
            $result.data    = "Configured: $($check -join ', '),#Looking For: $($script:appSettings['DNSServers'] -join ', ')"
        }
        Else
        {
            If (($script:appSettings['OrderSpecific']) -eq 'TRUE')
            {
                For ($i=0; $i -le ($check.Count); $i++)
                {
                    If ($check[$i] -ne $script:appSettings['DNSServers'][$i]) { $result.message = 'DNS Server list is not in the required order'; Break }
                }
                If (($result.message) -ne '')
                {
                    $result.result = $script:lang['Fail']
                    $result.data   = "Configured: $($check -join ', '),#Looking For: $($script:appSettings['DNSServers'] -join ', ')"
                }
                Else
                {
                    $result.result  = $script:lang['Pass']
                    $result.message = 'All DNS servers configured and in the right order'
                    $result.data    = ($check -join ', ')
                }
            }
            Else
            {
                ForEach ($itemC In $check)
                {
                    [boolean]$Found = $false
                    ForEach ($itemS In $script:appSettings['DNSServers']) { If ($itemC -eq $itemS) { $Found = $true; Break } }
                    If ($Found -eq $false)
                    {
                        $result.result  = $script:lang['Fail']
                        $result.message = 'Mismatched DNS servers'
                        $result.data    = "Configured: $($check -join ', '),#Looking For: $($script:appSettings['DNSServers'] -join ', ')"
                    }
                }

                If (($result.message) -eq '')
                {
                    $result.result  = $script:lang['Pass']
                    $result.message = 'All DNS servers configured'
                    $result.data    = ($check -join ', ')
                }
            }
        }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'No DNS servers are configured'
        $result.data    = ''
    }

    Return $result
}
