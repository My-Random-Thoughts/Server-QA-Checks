<#
    DESCRIPTION: 
        Check McAfee anti virus is installed and updating automatically.
        Also checks that virus definitions are up to date.


    PASS:    McAfee product found, DATs are OK
    WARNING:
    FAIL:    McAfee product not found, install required / DATs are not up-to-date / No DAT version found
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS: Win32_Product
#>

Function c-com-01-mcafee-antivirus-installed
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-com-01-mcafee-antivirus-installed'

    #... CHECK STARTS HERE ...#

    [string]$verCheck = Win32_Product -serverName $serverName -displayName $script:appSettings['ProductName']
    If ([string]::IsNullOrEmpty($verCheck) -eq $false)
    {
        [string]$verNeed  = $script:appSettings['ProductVersion']

        # Check AV Version
        If ($verCheck -ge $verNeed)
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'McAfee product  found, '
            $result.data    = 'Version {0}, ' -f $verCheck
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'McAfee product found, but wrong version, '
            $result.data    = 'Version {0} found. Expected version: {1}, ' -f $verCheck, $script:appSettings['ProductVersion']
        }

        # Check DAT Update date
        Try
        {
            [datetime]$dtVal = '01/01/1901'
            $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
            $regKey = $reg.OpenSubKey('Software\Wow6432Node\McAfee\AVEngine')
            If ($regKey) { $dtVal = $regKey.GetValue('AVDatDate') }
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
        Else
        {
            $result.result   = $script:lang['Fail']
            $result.message += 'No DAT version found'
        }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = '{0} not found, install required' -f $script:appSettings['ProductName']
    }

    Return $result
}