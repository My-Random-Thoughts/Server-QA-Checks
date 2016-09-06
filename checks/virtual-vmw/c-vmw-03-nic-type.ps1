<#
    DESCRIPTION: 
        Check all virtual servers have network cards that are configured as VMXNET3



    PASS:    All active NICS configured correctly
    WARNING: No network adapters found
    FAIL:    One or more active NICs were found not to be VMXNET3
    MANUAL:
    NA:      Not a virtual machine

    APPLIES: Virtuals

    REQUIRED-FUNCTIONS: Check-VMware
#>

Function c-vmw-03-nic-type
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'VMware NIC Type'
    $result.check  = 'c-vmw-03-nic-type'
    
    #... CHECK STARTS HERE ...#

    If ((Check-VMware $serverName) -eq $true)
    {
        Try
        {
            [string]$query = 'SELECT Description FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = "True"'
            [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Description
        }
        Catch
        {
            $result.result  = 'Error'
            $result.message = 'SCRIPT ERROR'
            $result.data    = $_.Exception.Message
            Return $result
        }

        If ([string]::IsNullOrEmpty($check) -eq $true)
        {
            $result.result  = 'Warning'
            $result.message = 'No network adapters found'
        }
        Else
        {
            $result.result  = 'Pass'
            $result.message = 'All active NICS configured correctly'
            $check | ForEach { If ($_ -notlike ('*VMXNET3*')) { $result.data += '{0},#' -f $_ } }
        
            If ([string]::IsNullOrEmpty($result.data) -eq $false)
            {
                $result.result  = 'Fail'
                $result.message = 'One or more active NICs were found not to be VMXNET3'
            }
        }
    }
    Else
    {
        $result.result  = 'N/A'
        $result.message = 'Not a virtual machine'
    }

    Return $result
}