<#
    DESCRIPTION: 
        Where SAN storage is used, ensure multipathing software is installed and Dual Paths are present and functioning.
        This only checks that known software is installed.  A manual check must be done to ensure it is configured correctly.

    REQUIRED-INPUTS:
        ProductNames - List of software to check if installed

    DEFAULT-VALUES:
        ProductNames = ('HDLM GUI', 'SANsurfer', 'Emulex FC')

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
        WARNING:
        FAIL:
            SAN storage software not found, install required
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

Function c-drv-06-san-storage
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-drv-06-san-storage'
    
    #... CHECK STARTS HERE ...#

    If (((Check-VMware $serverName) -eq $false) -and ((Check-HyperV $serverName) -eq $false))
    {
        [string]$query = 'SELECT Caption FROM Win32_OperatingSystem'
        [string]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Caption

        If ($check -like '*201*')
        {
            $result.result  = $script:lang['Not-Applicable']
            $result.message = 'Windows 2012 and above use native multipathing'
        }
        Else
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
                $result.message = 'SAN storage software not found, install required'
            }
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a physical machine'
    }

    Return $result
}