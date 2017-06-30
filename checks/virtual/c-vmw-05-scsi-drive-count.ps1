<#
    DESCRIPTION: 
        Checks to see if there are are more than 8 drives attached to the same SCSI adapter.
        
    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            More than 7 drives exist, but on different SCSI adapters
        WARNING:
        FAIL:
            More than 7 drives exist on one SCSI adapter
        MANUAL:
        NA:
            Not a virtual machine
            There are less than 8 drives attached to server

    APPLIES:
        Virtual Servers

    REQUIRED-FUNCTIONS:
        Check-VMware
#>

Function c-vmw-05-scsi-drive-count
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-vmw-05-scsi-drive-count'

    #... CHECK STARTS HERE ...#

    If ((Check-VMware $serverName) -eq $true)
    {
        Try
        {
            [string]$query = "SELECT SCSIPort, SCSITargetID FROM Win32_DiskDrive WHERE Caption <> 'Microsoft Virtual Disk'"
            [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object SCSIPort, SCSITargetID
        }
        Catch
        {
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }

        If ($check.Count -gt 7)
        {
            [boolean]$found = $false
            [array]$group = $check | Group-Object -Property SCSIPort -NoElement | Sort-Object SCSIPort
            $group | ForEach { $result.data += 'Adapter: {0}: Drive count: {1},#' -f $_.Name, $_.Count; If ($_.Count -gt 7) { $found = $true } }

            If ($found -eq $true)
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'More than 7 drives exist on one SCSI adapter'
            }
            Else
            {
                $result.result  = $script:lang['Pass']
                $result.message = 'More than 7 drives exist, but on different SCSI adapters'
            }
        }
        Else
        {
            $result.result  = $script:lang['Not-Applicable']
            $result.message = 'There are less than 8 drives attached to server'
            $result.data    = 'Count: ' + $check.Count
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a virtual machine'
    }

    Return $result
}
