<#
    DESCRIPTION: 
        If a CD/DVD drive is present on the server confirm it is configured as "R:".

    REQUIRED-INPUTS:
        DVDDriveLetter - Drive letter of the CD/DVD drive

    DEFAULT-VALUES:
        DVDDriveLetter = 'R:'

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            CD/DVD drive set correctly
        WARNING:
        FAIL:
            CD/DVD drive found, but not configured as {letter}
        MANUAL:
        NA:
            No CD/DVD drives found

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-drv-04-cd-dvd-drive
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-drv-04-cd-dvd-drive'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT DeviceID FROM Win32_LogicalDisk WHERE DriveType="5"'    # DriveType 5 is CD/DVD Drive
        [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty DeviceID
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If (($check.Count -eq 0 ) -or ([string]::IsNullOrEmpty($check) -eq $true))
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'No CD/DVD drives found'
    }
    Else
    {
        [boolean]$found = $false
        $check | ForEach {
            If ($_ -eq $script:appSettings['DVDDriveLetter']) { $found = $true }
            $result.data += '{0},#' -f $_
        }

        If ($found -eq $true)
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'CD/DVD drive set correctly'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'CD/DVD drive found, but not configured as {0}' -f $script:appSettings['DVDDriveLetter']
        }
    }

    Return $result
}
