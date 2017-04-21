<#
    DESCRIPTION: 
        Check the page file is located on the system drive and is a fixed size.  The default setting is 4096MB (4GB).
        If the page file is larger a document detailing the tuning process used must exist and should follow Microsoft best tuning practices (http://support.microsoft.com/kb/2021748).

    REQUIRED-INPUTS:
        FixedPageFileSize - Fixed size in MB of the page file|Integer

    DEFAULT-VALUES:
        FixedPageFileSize = '4096'

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            Pagefile is set correctly
        WARNING: 
        FAIL:
            Pagefile is system managed, it should be set to a custom size of {size}mb
            Pagefile should be set on the system drive, to Custom, with Initial and Maximum sizes set to {size}mb
            Pagefile does not exist on {letter} drive
        MANUAL:
            Unable to get page file information, please check manually
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-drv-03-pagefile-size-location
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-drv-03-pagefile-size-location'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query1 = 'SELECT SystemDrive FROM Win32_OperatingSystem'
        [string]$check1 = Get-WmiObject -ComputerName $serverName -Query $query1 -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty SystemDrive
        If ([string]::IsNullOrEmpty($check1) -eq $false)
        {
            If ((Get-WmiObject -ComputerName $serverName -Namespace ROOT\Cimv2 -List 'Win32_PageFileSetting').Name -eq 'Win32_PageFileSetting')
            {
                [string]$query2 = 'SELECT Name, InitialSize, MaximumSize FROM Win32_PageFileSetting'
                [string]$query3 = 'SELECT AutomaticManagedPagefile FROM Win32_ComputerSystem'
                [object]$check2 = Get-WmiObject -ComputerName $serverName -Query $query2 -Namespace ROOT\Cimv2                               | Select-Object Name, InitialSize, MaximumSize
                [string]$check3 = Get-WmiObject -ComputerName $serverName -Query $query3 -Namespace ROOT\Cimv2 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty AutomaticManagedPagefile
            }
        }
        Else
        {
            [object] $check2 = $null
            [boolean]$check3 = $false
        }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($check3 -eq $true)
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Pagefile is system managed, it should be set to a custom size of {0}mb' -f $script:appSettings['FixedPageFileSize']
    }
    Else
    {
        If (($check2 -eq $null) -and ($check3 -eq $false))
        {
            $result.result  = $script:lang['Manual']
            $result.message = 'Unable to get page file information, please check manually'
            $result.data    = 'Pagefile should be set to Custom,#with Initial and Maximum sizes set to ' + $script:appSettings['FixedPageFileSize'] + 'mb'
        }
        ElseIf ($check2 -ne $null)
        {
            If ($check2.MaximumSize -eq 0) 
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'Pagefile is system managed, it should be set to a custom size of {0}mb' -f $script:appSettings['FixedPageFileSize']
            }
            ElseIf (($check2.MaximumSize -eq $script:appSettings['FixedPageFileSize']) -and ($check2.InitialSize -eq $script:appSettings['FixedPageFileSize'])) 
            {
                $result.result  = $script:lang['Pass']
                $result.message = 'Pagefile is set correctly'
            }
            Else
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'Pagefile should be set on the system drive, to Custom, with Initial and Maximum sizes set to ' + $script:appSettings['FixedPageFileSize'] + 'mb'
            }

            $result.data    = 'Location: {0},#Initial Size: {1}mb,#Maximum Size: {2}mb' -f $check2.Name, $check2.InitialSize, $check2.MaximumSize
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Pagefile does not exist on {0} drive' -f $check1
            $result.data    = ''
        }
    }

    Return $result
}
