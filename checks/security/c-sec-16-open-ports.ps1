<#
    DESCRIPTION: 
        Returns a list of ports that are open, excluding anything higher than 49152
        IMPORTANT: THIS WORKS FOR LOCAL SERVERS ONLY


    PASS:    No extra ports are open
    WARNING:
    FAIL:    One or more extra ports are open
    MANUAL:
    NA:      This check is for local servers only

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-sec-16-open-ports
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-16-open-ports'

    #... CHECK STARTS HERE ...#

    If ($serverName -like "$env:ComputerName*")
    {
        Try
        {
            $TCPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
            [System.Net.IPEndPoint[]]$Connections = $TCPProperties.GetActiveTcpListeners() | Sort-Object -Property Port

            [System.Collections.ArrayList]$PortList = @()
            ForEach ($Port In $Connections.Port)
            {
                If (($script:appSettings['IgnoreThesePorts'] -notcontains $Port) -and ($Port -lt 49152)) { $PortList += $Port }
            }

            $PortList = ($PortList | Select-Object -Unique)    # Select Unique values only

            If ($PortList.Count -gt 0)
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'One or more extra ports are open'
                $result.data    = $($PortList -join ', ')
            }
            Else
            {
                $result.result   = $script:lang['Pass']
                $result.message += 'No extra ports are open'
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
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'This check is for local servers only'
        $result.data    = ''
    }

    Return $result
}
