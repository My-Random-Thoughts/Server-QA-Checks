<#
    DESCRIPTION: 
        Where SAN storage is used, ensure multipathing software is installed and Dual Paths are present and functioning.
        ** ONLY CHECKS IF SOFTWARE INSTALLED **


    PASS:
    WARNING:
    FAIL:    SAN storage software not found, install required
    MANUAL:  {0} found
    NA:      Not a physical machine

    APPLIES: Physicals

    REQUIRED-FUNCTIONS: Win32_Product, Check-VMware
#>

Function c-drv-06-san-storage
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'SAN Storage Software'
    $result.check  = 'c-drv-06-san-storage'
    
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
            $result.message = 'SAN storage software not found, install required'
        }
    }
    Else
    {
        $result.result  = 'N/A'
        $result.message = 'Not a physical machine'
    }

    Return $result
}