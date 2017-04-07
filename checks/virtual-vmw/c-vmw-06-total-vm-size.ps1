<#
    DESCRIPTION: 
        Checks to see if the total VM size is less than 1TB.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            VM is smaller than 1TB
        WARNING:
            VM is larger than 1TB.  Make sure there is an engineering exception in place for this
        FAIL:
        MANUAL:
        NA:
            Not a virtual machine

    APPLIES:
        Virtual Servers

    REQUIRED-FUNCTIONS:
        Check-VMware
#>

Function c-vmw-06-total-vm-size
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-vmw-06-total-vm-size'

    #... CHECK STARTS HERE ...#

    If ((Check-VMware $serverName) -eq $true)
    {
        Try
        {
            [string]$query = "SELECT Size FROM Win32_LogicalDisk WHERE DriveType = '3'"
            [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Size
        }
        Catch
        {
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }

        [int]$size = 0
        $check | ForEach { $size += ($_ / 1GB) }
        If ($size -gt '1023')
        {
            $result.result  = $script:lang['Warning']
            $result.message = 'VM is larger than 1TB.  Make sure there is an engineering exception in place for this'
            $result.data    = $size.ToString() + ' GB'
        }
        Else
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'VM is smaller than 1TB'
            $result.data    = $size.ToString() + ' GB'
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a virtual machine'
    }

    Return $result
}