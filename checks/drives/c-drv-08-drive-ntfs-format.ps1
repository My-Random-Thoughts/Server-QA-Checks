<#
    DESCRIPTION: 
        Ensure all drives are formatted as NTFS.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            All drives are formatted as NTFS
        WARNING:
        FAIL:
            One or more drives were found not formatted as NTFS
        MANUAL:
            Unable to get drive information, please check manually
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-drv-08-drive-ntfs-format
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-drv-08-drive-ntfs-format'
 
    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT *  FROM Win32_LogicalDisk WHERE DriveType = "3"'    # Filter on DriveType=3 (Fixed Drives)
        [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object Name, FileSystem
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    $countFailed = 0
    $result.data = ''
    If ($check -ne $null)
    {
        $check | ForEach {
            If ($_.FileSystem -ne 'NTFS')
            {
                If ($_.FileSystem -eq $null) { $_.FileSystem = 'Not Formatted' }
                $result.data += '{0} ({1}),#' -f $_.Name, $_.FileSystem
                $countFailed += 1
            }
        }
    
        If ($countFailed -ne 0)
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'One or more drives were found not formatted as NTFS'
        }
        Else
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'All drives are formatted as NTFS'
        }
    }
    Else
    {
        $result.result  = $script:lang['Manual']
        $result.message = 'Unable to get drive information, please check manually'
        $result.data    = 'All drives need to be formatted as NTFS'
    }
    Return $result
}