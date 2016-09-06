<#
    DESCRIPTION: 
        Checks for any mounted CD/DVD or floppy drives



    PASS:    No CD/ROM or floppy drives are mounted
    WARNING:
    FAIL:    One or more CD/ROM or floppy drives are mounted
    MANUAL:
    NA:      Not a virtual machine

    APPLIES: Virtuals

    REQUIRED-FUNCTIONS: Check-VMware
#>

Function c-vmw-07-cd-dvd-floppy-mounted
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Mounted drives'
    $result.check  = 'c-vmw-07-cd-dvd-floppy-mounted'
 
    #... CHECK STARTS HERE ...#

    If ((Check-VMware $serverName) -eq $true)
    {
        Try
        {
            [string]$query = "SELECT Name, VolumeName, Size FROM Win32_LogicalDisk WHERE DriveType='2' OR DriveType='5'"    # Filter on DriveType=2/5 (Removable and CD/DVD)
            [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object Name, VolumeName, Size
        }
        Catch
        {
            $result.result  = 'Error'
            $result.message = 'SCRIPT ERROR'
            $result.data    = $_.Exception.Message
            Return $result
        }

        $check | ForEach { If ($_.size -ne $null) { $result.data += '{0} ({1}),#' -f $_.Name, $_.VolumeName } }

        If ([string]::IsNullOrEmpty($result.data) -eq $false)
        {
            $result.result  = 'Fail'
            $result.message = 'One or more CD/ROM or floppy drives are mounted'
        }
        Else
        {
            $result.result  = 'Pass'
            $result.message = 'No CD/ROM or floppy drives are mounted'
            $result.data    = ''
        }
    }
    Else
    {
        $result.result  = 'N/A'
        $result.message = 'Not a virtual machine'
    }

    Return $result
}