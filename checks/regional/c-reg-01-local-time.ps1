<#
    DESCRIPTION: 
        Check that the server time is correct.  If a valid source is used, the time is also checked against that source.
        Maximum time difference allowed is 10 seconds.  Any longer and the check fails


    PASS:    Time source is set to a remote server, and is syncronsized correctly
    WARNING:
    FAIL:    Time source is set to a remote server, and is not syncronsized correctly / Time source is not set / Time source is not set correctly / Error getting required information / 
    MANUAL:  Not a supported operating system for this check
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-reg-01-local-time
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Local Date/Time'
    $result.check  = 'c-reg-01-local-time'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]  $query = 'SELECT Day, Month, Year, Hour, Minute, Second FROM Win32_LocalTime'
        [array]   $check = Get-WmiObject -ComputerName $serverName  -Query $query -Namespace ROOT\Cimv2 | Select  Day, Month, Year, Hour, Minute, Second
        [datetime]$rdt   = Get-Date -Year $check[0].Year -Month  $check[0].Month  -Day    $check[0].Day `
                                    -Hour $check[0].Hour -Minute $check[0].Minute -Second $check[0].Second

        Try
        {
            If ($serverName -eq $env:ComputerName) {
                [string]$source = Invoke-Command                           -ScriptBlock { &"$env:SystemRoot\System32\w32tm.exe" /query /source } -ErrorAction SilentlyContinue
            }
            Else {
                [string]$source = Invoke-Command -ComputerName $serverName -ScriptBlock { &"$env:SystemRoot\System32\w32tm.exe" /query /source } -ErrorAction SilentlyContinue
            }
            If ($source.Contains(',') -eq $true) { $source = ($source.Split(',')[0]) }
        }
        Catch
        {
            $result.result  = 'Error'
            $result.message = 'SCRIPT ERROR'
            $result.data    = $_.Exception.Message
            Return $result
        }
        
        If ([string]::IsNullOrEmpty($source) -eq $true)
        {
            $result.result  = 'Fail'
            $result.message = 'Time source is not set'
        }
        ElseIf (($source -eq 'Local CMOS Clock') -or ($source -eq 'Free-running System Clock'))
        {
            $result.result  = 'Fail'
            $result.message = 'Time source is not set correctly'
            $result.data    = '{0},#Time is {1}' -f $source, $rdt
        }
        ElseIf ($source -like '*The following error*')
        {
            $result.result  = 'Fail'
            $result.message = 'Error getting required information'
            $result.data    = '{0},#Time is {1}' -f $source, $rdt
        }
        ElseIf ($source -like '*The command /query is unknown*')    # Windows 2003 server
        {
            $result.result  = 'Manual'
            $result.message = 'Not a supported operating system for this check'
            $result.data    = 'Time is {0}' -f $rdt
        }
        Else
        {
            $offSet = (Get-NtpTime -NTPServer $source.Trim() -InputDateTime $rdt)
            If ($offSet -lt 10)
            {
                $result.result   = 'Pass'
                $result.message += 'Time source is set to a remote server, and is syncronsized correctly'
                $result.data    += 'Source: {0},#Time is about {1} seconds adrift' -f $source.Trim(), $offSet
            }
            Else
            {
                $result.result   = 'Fail'
                $result.message += 'Time source is set to a remote server, and is not syncronsized correctly'
                $result.data    += 'Source: {0},#Time is about {1} seconds adrift' -f $source.Trim(), $offSet
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

    Return $result
}

Function Get-NtpTime {
    Param ([string]$NTPServer, [datetime]$InputDateTime)
    $StartOfEpoch=New-Object DateTime(1900,1,1,0,0,0,[DateTimeKind]::Utc)   
    Function OffsetToLocal($Offset) { $StartOfEpoch.AddMilliseconds($Offset).ToUniversalTime() }
    [Byte[]]$NtpData = ,0 * 48
    $NtpData[0]      = 0x1B

    $Socket = New-Object Net.Sockets.Socket([Net.Sockets.AddressFamily]::InterNetwork, [Net.Sockets.SocketType]::Dgram, [Net.Sockets.ProtocolType]::Udp)
    $Socket.SendTimeOut    = 2000
    $Socket.ReceiveTimeOut = 2000
    Try { $Socket.Connect($NTPServer, 123) } Catch { Return 'Failed to connect to server' }
    Try { [Void]$Socket.Send($NtpData); [Void]$Socket.Receive($NtpData) } Catch { Return 'Failed to communicate with server' }
    $Socket.Shutdown('Both')
    $Socket.Close()

    $IntPart  = [System.BitConverter]::ToUInt32($NtpData[35..32],0)
    $FracPart = [System.BitConverter]::ToUInt32($NtpData[39..36],0)
    $CalcPart = $IntPart * 1000 + ($FracPart * 1000 / 0x100000000)
    $Offset =  ($CalcPart - ($InputDateTime.ToUniversalTime() - $StartOfEpoch).TotalMilliseconds)

    Return [Math]::Round($Offset/1000, 3)
}