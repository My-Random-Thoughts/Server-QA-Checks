<#
    DESCRIPTION:
        Check local network management agent is installed on the server.  This only checks that known software is installed.

    REQUIRED-INPUTS:
        ProductNames - List of software to check if installed

    DEFAULT-VALUES:
        ProductNames = ('HP Network Config Utility', 'Broadcom Advanced Control Suite', 'Broadcom Drivers and Management Applications')

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            {product} found
        WARNING:
        FAIL:
            Network management software not found, install required
        MANUAL:
        NA:
            Not a physical machine

    APPLIES:
        Physical Servers

    REQUIRED-FUNCTIONS:
        Check-Software
        Check-VMware
        Check-HyperV
#>

Function c-net-06-network-agent
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-net-06-network-agent'

    #... CHECK STARTS HERE ...#

    If (((Check-VMware $serverName) -eq $false) -and ((Check-HyperV $serverName) -eq $false))
    {
        Try
        {
            [boolean]$found = $false
            $script:appSettings['ProductNames'] | ForEach {
                [string]$verCheck = Check-Software -serverName $serverName -displayName $_
                If ($verCheck -eq '-1') { Throw 'Error opening registry key' }
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
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }

        If ($found -eq $true)
        {
            $result.result  = $script:lang['Pass']
            $result.message = '{0} found'   -f $prodName
            $result.data    = 'Version {0}' -f $prodVer
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Network management software not found, install required'
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a physical machine'
    }

    Return $result
}