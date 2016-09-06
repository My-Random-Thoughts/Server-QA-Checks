<#
    DESCRIPTION:
        Check local network management agent is installed on the server.
        ** ONLY CHECKS IF SOFTWARE INSTALLED **


    PASS:    {0} found
    WARNING:
    FAIL:    Network management software not found, install required
    MANUAL:
    NA:      Not a physical machine

    APPLIES: Physicals

    REQUIRED-FUNCTIONS: Win32_Product, Check-VMware
#>

Function c-net-06-network-agent
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Network Management Agent'
    $result.check  = 'c-net-06-network-agent'

    #... CHECK STARTS HERE ...#

    If ((Check-VMware $serverName) -eq $false)
    {
        Try
        {
            [boolean]$found = $false
            $script:appSettings['ProductNames'] | ForEach {
                [string]$verCheck = Win32_Product -serverName $serverName -displayName $_
                If ([string]::IsNullOrEmpty($verCheck) -eq $false)
                {
                    $found            = $true
                    [string]$prodName = $_
                    [string]$prodVer  = $verCheck
                }
            }
        }
        Catch
        {
            $result.result  = 'Error'
            $result.message = 'SCRIPT ERROR'
            $result.data    = $_.Exception.Message
            Return $result
        }

        If ($found -eq $true)
        {
            $result.result  = 'Pass'
            $result.message = '{0} found'   -f $prodName
            $result.data    = 'Version {0}' -f $prodVer
        }
        Else
        {
            $result.result  = 'Fail'
            $result.message = 'Network management software not found, install required'
        }
    }
    Else
    {
        $result.result  = 'N/A'
        $result.message = 'Not a physical machine'
    }

    Return $result
}