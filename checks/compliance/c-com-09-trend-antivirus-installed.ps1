<#
    DESCRIPTION: 
        Check that Trend anti-virus is installed and virus definitions are up to date.

    REQUIRED-INPUTS:
        MaximumDATAgeAllowed - Maximum number of days that DATs are allowed to be out of date|Integer
        ProductName          - Full name of the Trend product
        ProductVersion       - Current version of the product that you are using|Decimal
        DATPathLocation      - Full path location of the DAT location|File

    DEFAULT-VALUES:
        MaximumDATAgeAllowed = '7'
        ProductName          = 'Trend Micro OfficeScan Client'
        ProductVersion       = '10.6'
        DATPathLocation      = 'C:\Program Files (x86)\Trend Micro\OfficeScan Client\'

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            Trend product found, DATs are OK
        WARNING:
        FAIL:
            Trend product not found, install required
            DATs are not up-to-date
            No DAT version found
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        Check-Software
#>

Function c-com-09-trend-antivirus-installed
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-com-09-trend-antivirus-installed'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$verCheck = Check-Software -serverName $serverName -displayName $script:appSettings['ProductName']
        If ($verCheck -eq '-1') { Throw 'Error opening registry key' }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ([string]::IsNullOrEmpty($verCheck) -eq $false)
    {
        [string]$verNeed  = $script:appSettings['ProductVersion']

        # Check AV Version
        If ($verCheck -ge $verNeed)
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'Trend product found, '
            $result.data    = 'Version {0}, ' -f $verCheck
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Trend product found, but wrong version, '
            $result.data    = 'Version {0} found. Expected version: {1},#' -f $verCheck, $script:appSettings['ProductVersion']
        }

        # Check DAT Update date
        Try
        {
            [string]$datName = 'icrc$oth.*'
            $script:appSettings['DATPathLocation'] = $script:appSettings['DATPathLocation'].Replace(':', '$')
            If (Test-Path -Path "\\$serverName\$($script:appSettings['DATPathLocation'])\")
            {
                [datetime]$dtVal = '01/01/1901'
                $dtVal = (Get-ItemProperty -Path "\\$serverName\$($script:appSettings['DATPathLocation'])\$datName" | Sort-Object LastWriteTime | Select-Object -Last 1).LastWriteTime

                If ($dtVal -ne '01/01/1901')
                {
                    $days = ((Get-Date) - $dtVal).Days
                    If ($days -le $script:appSettings['MaximumDATAgeAllowed'])
                    {
                        $result.result   = $script:lang['Pass']
                        $result.message += 'DATs are OK'
                        $result.data    += 'DATs {0} day(s) old' -f $days.ToString()
                    }
                    Else
                    {
                        $result.result   = $script:lang['Fail']
                        $result.message += 'DATs are not up-to-date'
                        $result.data    += 'DATs {0} day(s) old' -f $days.ToString()
                    }
                }
            }
            Else
            {
                $result.result   = $script:lang['Fail']
                $result.message += 'No DAT version found'
            }
        }
        Catch
        {
            $result.result   = $script:lang['Fail']
            $result.message += 'No DAT version found'
        }

        # Get master server name
        Try
        {
            $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
            $regKey = $reg.OpenSubKey('Software\Wow6432Node\TrendMicro\PC-cillinNTCorp\CurrentVersion\Internet Settings')
            If ($regKey) {
                [string]$regVal1 = $regKey.GetValue('Server')
                [string]$regVal2 = $regKey.GetValue('ServerPort')
            }
            Try {$regKey.Close() } Catch {}
            $reg.Close()
        }
        Catch
        {
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }

        If (($regVal1 -ne '') -and ($regVal2 -ne '')) { $result.data += "Master Server: $regVal1 : $regVal2" }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = '{0} not found, install required' -f $script:appSettings['ProductName']
    }

    Return $result
}