<#
    DESCRIPTION: 
        If server is Domain Controller or a Terminal Server ensure RSA authentication manager is installed and PIN is required to access server.



    PASS:    {0} found
    WARNING:
    FAIL:    RSA software not found
    MANUAL:
    NA:      Not a domain controller or terminal services server

    APPLIES: Domain Controllers

    REQUIRED-FUNCTIONS: Win32_Product, Check-DomainController, Check-TerminalServer
#>

Function c-sec-13-rsa-authentication
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-13-rsa-authentication'

    #... CHECK STARTS HERE ...#

    If (((Check-DomainController $serverName) -eq $true) -or ((Check-TerminalServer $serverName) -eq $true))
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
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }

        If ($found -eq $true)
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'RSA software found'
            $result.data    = '{0}, Version {1}' -f $prodName, $prodVer
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'RSA software not found'
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a domain controller or terminal services server'
    }

    Return $result
}
