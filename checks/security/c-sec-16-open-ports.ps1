<#
    DESCRIPTION: 
        Returns a list of ports that are open, excluding anything lower than 1024 and higher than 49152.  Will also exclude other well known ports
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
        # List of well known exclusions
        $script:appSettings['IgnoreThesePorts'] +=  '5985'    # WinRM HTTP          #
        $script:appSettings['IgnoreThesePorts'] +=  '5986'    # WinRM HTTPS         # Microsoft
        $script:appSettings['IgnoreThesePorts'] += '47001'    # WinRM Listener      #
        #
        $script:appSettings['IgnoreThesePorts'] +=  '4750'    # BladeLogic Agent    #
        $script:appSettings['IgnoreThesePorts'] +=  '1556'    # NetBackup Agent     # Third Party
#       $script:appSettings['IgnoreThesePorts'] +=  '0000'    # 

        Try
        {
            $TCPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
            [System.Net.IPEndPoint[]]$Connections = $TCPProperties.GetActiveTcpListeners() | Sort-Object -Property Port

            [array]$PortList = @()
            ForEach ($Port In $Connections.Port)
            {
                If (($script:appSettings['IgnoreThesePorts'] -notcontains $Port) -and ($Port -lt 49152) -and ($Port -gt 1024)) { $PortList += ($Port -as [string]) }
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
