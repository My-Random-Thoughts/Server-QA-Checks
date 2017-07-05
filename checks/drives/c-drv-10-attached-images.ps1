<#
    DESCRIPTION: 
        Check to see if any floppy or CD/DVD images are attached to the server

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            No Floppy or CD/DVD images attached
        WARNING:
        FAIL:
            One or more Floppy or CD/DVD images attached
        MANUAL:
        NA:
            No Floppy or CD/DVD drives found

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-drv-10-attached-images
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-drv-10-attached-images'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT DeviceID FROM Win32_LogicalDisk WHERE DriveType="2" OR DriveType="5"'    # DriveType 2 is Removable, 5 is CD/DVD Drive
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
        $result.message = 'No Floppy or CD/DVD drives found'
    }
    Else
    {
        [string]$found = ''
        $check | ForEach { Try { If ((Get-ChildItem -Path $_ -ErrorAction SilentlyContinue).Count -gt 0) { $found += "$_, " } } Catch { } }

        If ($found -eq '')
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'No Floppy or CD/DVD images attached'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'One or more Floppy or CD/DVD images attached'
            $result.data    = $found
        }
    }

    Return $result
}
