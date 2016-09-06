<#
    DESCRIPTION: 
        Check local disk array management agent is installed on the server.
        ** ONLY CHECKS IF SOFTWARE INSTALLED **


    PASS:
    WARNING:
    FAIL:    Disk management software not found, install required
    MANUAL:  {0} found
    NA:      Not a physical machine

    APPLIES: Physicals

    REQUIRED-FUNCTIONS: Win32_Product, Check-VMware
#>

Function c-drv-07-disk-management-agent
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Disk Management Agent'
    $result.check  = 'c-drv-07-disk-management-agent'
    
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
            $result.result  = 'Manual'
            $result.message = '{0} found'   -f $prodName
            $result.data    = 'Version {0}' -f $prodVer
        }
        Else
        {
            $result.result  = 'Fail'
            $result.message = 'Disk management software not found, install required'
        }
    }
    Else
    {
        $result.result  = 'N/A'
        $result.message = 'Not a physical machine'
    }

    Return $result
}