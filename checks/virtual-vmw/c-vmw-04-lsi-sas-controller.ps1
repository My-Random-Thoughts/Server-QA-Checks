<#
    DESCRIPTION: 
        Check Windows disk controller is set correctly.
        Default setting is "LSI logic SAS"


    PASS:    Disk controller set correctly
    WARNING:
    FAIL:    No SCSI controllers found / Disk controller not set correctly
    MANUAL:
    NA:      Not a virtual machine

    APPLIES: Virtuals

    REQUIRED-FUNCTIONS: Check-VMware
#>

Function c-vmw-04-lsi-sas-controller
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'VMware Disk Controller'
    $result.check  = 'c-vmw-04-lsi-sas-controller'

    #... CHECK STARTS HERE ...#

    If ((Check-VMware $serverName) -eq $true)
    {
        Try
        {
            [string]$query = 'SELECT DriverName, Name FROM Win32_SCSIController WHERE NOT DriverName = ""'
            $script:appSettings['IgnoreTheseControllerTypes'] | ForEach { $query += ' AND NOT DriverName LIKE "%{0}%"' -f $_ }
            [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty DriverName 
        }
        Catch
        {
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }

        If ($check.Count -gt 0)
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'Disk controller set correctly'

            $check | ForEach { If ($_ -ne $script:appSettings['DiskControllerDeviceType']) { $result.data += '{0},#' -f $_ } }
            If ([string]::IsNullOrEmpty($result.data) -eq $false)
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'Disk controller not set correctly'
            }
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'No SCSI controllers found'
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a virtual machine'
    }

    Return $result
}