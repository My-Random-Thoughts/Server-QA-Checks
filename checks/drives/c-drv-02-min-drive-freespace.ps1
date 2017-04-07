<#
    DESCRIPTION: 
        Ensure all drives have a minimum amount of free space.  Measured as a percentage.

    REQUIRED-INPUTS:
        IgnoreTheseDrives       - List of drive letters to ignore
        MinimumDrivePercentFree - Minimum free space available on each drive as a percentage|Integer

    DEFAULT-VALUES:
        IgnoreTheseDrives       = ('A', 'B')
        MinimumDrivePercentFree = '17'

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            All drives have the required minimum free space of {size}%
        WARNING:
        FAIL:
            One or more drives were found with less than {size}% free space
        MANUAL:
            Unable to get drive information, please check manually
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-drv-02-min-drive-freespace
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-drv-02-min-drive-freespace'
 
    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT * FROM Win32_LogicalDisk WHERE DriveType = "3"'    # Filter on DriveType = 3 (Fixed Drives)
        $script:appSettings['IgnoreTheseDrives'] | ForEach { $query += ' AND NOT Name = "{0}"' -f $_ }
        [array]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object Name, FreeSpace, Size
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    $countFailed = 0
    If ($check -ne $null)
    {
        ForEach ($drive In $check)
        {
            $free = $drive.FreeSpace
            $size = $drive.Size
            If ($size -ne $null)
            {
                $percentFree  = [decimal]::Round(($free / $size) * 100)
                $result.data += $drive.Name + ' (' + $percentFree + '% free),#'
                If ($percentFree -lt $script:appSettings['MinimumDrivePercentFree']) { $countFailed += 1 }
            }
        }
    
        If ($countFailed -ne 0)
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'One or more drives were found with less than ' + $script:appSettings['MinimumDrivePercentFree'] + '% free space'
        }
        Else
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'All drives have the required minimum free space of ' + $script:appSettings['MinimumDrivePercentFree'] + '%'
        }
    }
    Else
    {
        $result.result  = $script:lang['Manual']
        $result.message = 'Unable to get drive information, please check manually'
        $result.data    = 'All drives need to have ' + $script:appSettings['MinimumDrivePercentFree'] + '% or more free'
    }
    Return $result
}