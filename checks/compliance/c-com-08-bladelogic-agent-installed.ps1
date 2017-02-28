<#
    DESCRIPTION: 
        Check BladeLogic monitoring agent is installed, and that the correct port is listening.
        Also check that the USERS.LOCAL file is configured correctly.

    REQUIRED-INPUTS:
        ListeningPort - Port number that the agent listens on|Integer
        CustomerCode  - Customer name found in USERS.LOCAL: ACME_L3AdminW:* rw,map=Administrator
        LocalAccount  - Mapped account name found in USERS.LOCAL: ACME_L3AdminW:* rw,map=Administrator

    DEFAULT-VALUES:
        ListeningPort = '4750'
        CustomerCode  = 'ACME'
        LocalAccount  = 'Administrator'

    RESULTS:
        PASS:
            BladeLogic agent found, and file confgiured
        WARNING:
        FAIL:
            BladeLogic agent not found, install required
            Required port not listening
            USERS.LOCAL not configured
            USERS.LOCAL not found
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        Win32_Product
#>

Function c-com-08-bladelogic-agent-installed
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-com-08-bladelogic-agent-installed'

    #... CHECK STARTS HERE ...#

    [string]$verCheck = Win32_Product -serverName $serverName -displayName 'BMC BladeLogic Server Automation RSCD Agent'
    If ([string]::IsNullOrEmpty($verCheck) -eq $false)
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'BladeLogic agent found'
        $result.data    = 'Version {0},#' -f $verCheck

        Try
        {
            # Check for listening port...
            [boolean]$found = $false
            $TCPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
            [System.Net.IPEndPoint[]]$Connections = $TCPProperties.GetActiveTcpListeners()
            ForEach ($Port In $Connections) { If ($($Port.Port) -eq $script:appSettings['ListeningPort']) { $found = $true } }

            If ($found -eq $true)
            {
                $result.data += 'Port {0} is listening,#' -f $script:appSettings['ListeningPort']
            }
            Else
            {
                $result.result  = $script:lang['Fail']
                $result.data   += 'Port {0} not listening,#' -f $script:appSettings['ListeningPort']
            }

            # Check USER.LOCAL configuration file
            If ((Test-Path -Path "\\$serverName\admin$\rsc\users.local") -eq $true)
            {
                [boolean] $found = $false
                [string[]]$file  = (Get-Content -Path "\\$serverName\admin$\rsc\users.local")
                ForEach ($line In $file) { If (($line.StartsWith($script:appSettings['CustomerCode']) -eq $true) -and ($line.EndsWith($script:appSettings['LocalAccount']) -eq $true)) { $found = $true } }

                If ($found -eq $true)
                {
                    $result.data += 'USERS.LOCAL configured correctly'
                }
                Else
                {
                    $result.result  = $script:lang['Fail']
                    $result.data   += 'USERS.LOCAL not configured'
                }
            }
            Else
            {
                $result.result  = $script:lang['Fail']
                $result.data   += 'USERS.LOCAL not found, or ADMIN$ share not enabled'
            }
        }
        Catch
        {
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'BladeLogic agent not found, install required'
    }

    Return $result
}
