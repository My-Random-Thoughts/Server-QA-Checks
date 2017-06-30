<#
    DESCRIPTION: 
        Check the page file is located on the system drive and is a fixed size.  The default setting is 4096MB (4GB).
        If the page file is larger a document detailing the tuning process used must exist and should follow Microsoft best tuning practices (http://support.microsoft.com/kb/2021748).

    REQUIRED-INPUTS:
        FixedPageFileSize - Fixed size in MB of the page file|Integer
        PageFileLocation  - Drive location of the page file

    DEFAULT-VALUES:
        FixedPageFileSize = '4096'
        PageFileLocation  = 'C:\'

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            Pagefile is set correctly
        WARNING: 
        FAIL:
            Pagefile is system managed
            Pagefile is not set correctly
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
        [string]  $query1 = 'SELECT Name, InitialSize, MaximumSize FROM Win32_PageFileSetting'
        [string]  $query2 = 'SELECT AutomaticManagedPagefile FROM Win32_ComputerSystem'
        [object[]]$check1 = Get-WmiObject -ComputerName $serverName -Query $query1 -Namespace ROOT\Cimv2                               | Select-Object Name, InitialSize, MaximumSize
        [string]  $check2 = Get-WmiObject -ComputerName $serverName -Query $query2 -Namespace ROOT\Cimv2 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty AutomaticManagedPagefile
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($check2 -eq $true)
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Pagefile is system managed'
        $result.data    = ''    # Set below
    }
    Else
    {
        If (($check1 -eq $null) -and ($check2 -eq $false))
        {
            $result.result  = $script:lang['Manual']
            $result.message = 'Unable to get page file information, please check manually'
            $result.data    = ''    # Set below
        }
        ElseIf ($check1 -ne $null)
        {
            If (($check1[0].MaximumSize -eq $script:appSettings['FixedPageFileSize']) -and ($check1[0].InitialSize -eq $script:appSettings['FixedPageFileSize']) -and ($check1[0].Name.ToLower().StartsWith($script:appSettings['PageFileLocation'].ToLower())))
            {
                $result.result  = $script:lang['Pass']
                $result.message = 'Pagefile is set correctly'
                $result.data    = 'Location: {0},#Fixed Size: {1}mb' -f $script:appSettings['PageFileLocation'], $script:appSettings['FixedPageFileSize']
            }
            Else
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'Pagefile is not set correctly'
                $result.data    = 'Location: {0},#Initial Size: {1}mb, Maximum Size: {2}mb' -f $check1[0].Name, $check1[0].InitialSize, $check1[0].MaximumSize
            }
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Pagefile does not exist on {0} drive' -f $script:appSettings['PageFileLocation']
            $result.data    = ''    # Set below
        }
    }

    If ($result.data -eq '')
    {
        $result.message += ',#It should be: location: {0}, fixed Size: {1}mb' -f $script:appSettings['PageFileLocation'], $script:appSettings['FixedPageFileSize']
        $result.data = ('It should be set as follows,#A fixed custom size of {0}mb and located on the {1} drive' -f $script:appSettings['FixedPageFileSize'], $script:appSettings['PageFileLocation'])
    }

    Return $result
}