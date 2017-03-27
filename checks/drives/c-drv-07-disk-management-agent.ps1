<#
    DESCRIPTION: 
        Check local disk array management agent is installed on the server.
        This only checks that known software is installed.  A manual check must be done to ensure it is configured correctly.

    REQUIRED-INPUTS:
        ProductNames - List of sofware to check if installed

    DEFAULT-VALUES:
        ProductNames = ('HP Array Configuration Utility', 'Dell OpenManage Server Administrator', 'Broadcom Drivers And Management Applications')

    RESULTS:
        PASS:
        WARNING:
        FAIL:
            Disk management software not found, install required
        MANUAL:
            {product} found
        NA:
            Not a physical machine

    APPLIES:
        Physical Servers

    REQUIRED-FUNCTIONS:
        Check-Software
        Check-VMware
        Check-HyperV
#>

Function c-drv-07-disk-management-agent
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-drv-07-disk-management-agent'
    
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
            $result.result  = $script:lang['Manual']
            $result.message = '{0} found'   -f $prodName
            $result.data    = 'Version {0}' -f $prodVer
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Disk management software not found, install required'
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a physical machine'
    }

    Return $result
}
