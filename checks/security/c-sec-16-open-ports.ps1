<#
    DESCRIPTION: 
        Returns a list of ports that are open, excluding anything lower than 1024 and within the dynamic port range.  Will also exclude other well known ports.
        !nIMPORTANT: THIS WORKS FOR LOCAL SERVERS ONLY

    REQUIRED-INPUTS:
        IgnoreThesePorts - List of port numbers to ignore|Integer

    DEFAULT-VALUES:
        IgnoreThesePorts = ('5985', '5986', '8192')

    RESULTS:
        PASS:
            No extra ports are open
        WARNING:
        FAIL:
            One or more extra ports are open
        MANUAL:
        NA:
            This check is for local servers only

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
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

    # List of well known exclusions
    $script:appSettings['IgnoreThesePorts'] += '47001'    # WinRM Listener - 5985 and 5986 are in settings file
    $script:appSettings['IgnoreThesePorts'] +=  '1556'    # NetBackup Agent
    $script:appSettings['IgnoreThesePorts'] +=  '2381'    # HPE System Management Home Page
    $script:appSettings['IgnoreThesePorts'] +=  '4750'    # BladeLogic Agent
#   $script:appSettings['IgnoreThesePorts'] +=  '0000'    # 

    If ($serverName -like "$env:ComputerName*")
    {
        Try
        {
            $TCPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
            [System.Net.IPEndPoint[]]$Connections = $TCPProperties.GetActiveTcpListeners() | Sort-Object -Property Port

            [int]$portStart = -1; [int]$portCount = -1
            [string[]]$dynPorts = Invoke-Command -ScriptBlock { &"netsh.exe" int ipv4 show dynamicportrange tcp } -ErrorAction SilentlyContinue

            If ($dynPorts.Count -gt 0)
            {
                $portStart = ($dynPorts[3].Split(':')[1])
                $portCount = ($dynPorts[4].Split(':')[1])
            }

            If ($portStart -eq -1) { $portStart = 49152 }    # Default values for
            If ($portCount -eq -1) { $portCount = 16384 }    # dynamic port range
            [int]$portEnd   = ($portStart + $portCount)

            [array]$PortList = @()
            ForEach ($Port In $Connections.Port)
            {
                If (($script:appSettings['IgnoreThesePorts'] -notcontains $Port) -and ($Port -gt 1024) -and (($Port -lt $portStart) -or ($Port -gt $portEnd))) { $PortList += ($Port -as [string]) }
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

            $result.data += ',#Ignoring: 0-1024, '
            $script:appSettings['IgnoreThesePorts'] | Sort-Object | ForEach { $result.data += "$_, " }
            $result.data += "$portStart-$portEnd"
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
        $result.result  = $script:lang['Manual']
        $result.message = 'This check is for local servers only'
        $result.data    = "Run 'NBTSTAT -A' on the remote server and check the results.  Ignore the following ports:,#0-1024, "
        $script:appSettings['IgnoreThesePorts'] | Sort-Object | ForEach { $result.data += "$_, " }
        $result.data   += "49152-65535"
    }

    Return $result
}
