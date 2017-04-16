<#
    DESCRIPTION: 
        Check all VMs are running from a non-system drive.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            No virtual machines are using the system drive
        WARNING:
        FAIL:
            One or more virtual machines are using the system drive
        MANUAL:
        NA:
            Not a Hyper-V server
            No virtual machines exist on this host

    APPLIES:
        Hyper-V Host Servers

    REQUIRED-FUNCTIONS:
        Check-NameSpace
#>

Function c-hvh-03-vm-location
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-hvh-03-vm-location'
 
    #... CHECK STARTS HERE ...#

    If ((Check-NameSpace -ServerName $serverName -NameSpace 'ROOT\Virtualization') -eq $true)
    {
        Try
        {
            [string]$query1 = 'SELECT SystemDrive FROM Win32_OperatingSystem'
            [string]$check1 = Get-WmiObject -ComputerName $serverName -Query $query1 -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty SystemDrive
            [string]$query2 = 'SELECT * FROM Msvm_ComputerSystem WHERE Caption="Virtual Machine"'
            [object]$check2 = Get-WmiObject -ComputerName $serverName -Query $query2 -Namespace ROOT\Virtualization\v2
        }
        Catch
        {
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }

        If ($check2.Count -ne 0)
        {
            [string]$result.data = ''
            ForEach ($vm In $check2)
            {
                $VSSD = Get-WmiObject -ComputerName $serverName -Query "SELECT * FROM Msvm_VirtualSystemSettingData     WHERE ConfigurationID =              '$($VM.Name)'"  -Namespace ROOT\Virtualization\v2
                $SASD = Get-WmiObject -ComputerName $serverName -Query "SELECT * FROM Msvm_StorageAllocationSettingData WHERE      InstanceID LIKE 'Microsoft:$($VM.Name)%'" -Namespace ROOT\Virtualization\v2

                If ($($VSSD.ConfigurationDataRoot).Substring(0,2) -eq $check1) { $result.data += '{0} - Configuration,#' -f $VM.ElementName }
                ForEach ($SA In $SASD) {
                    [int]$driveNum = $(($SA.Parent).Split("\")[11])
                    $item = $SA
                    Do
                    {
                        $parent = ($item.Parent).Split('=')[1].Split('\\')[0].Split(':')[1].Trim('"')
                        $item = Get-WmiObject -ComputerName $serverName -Query "SELECT * FROM Msvm_VirtualSystemSettingData     WHERE ConfigurationID LIKE           '$parent%'" -Namespace ROOT\Virtualization\v2
                        $path = Get-WmiObject -ComputerName $serverName -Query "SELECT * FROM Msvm_StorageAllocationSettingData WHERE      InstanceID LIKE 'Microsoft:$parent%'" -Namespace ROOT\Virtualization\v2

                        If (($path.HostResource[$driveNum]).Substring(0,2) -eq $check1) { $result.data += '{0} - Disk {1},#' -f $VM.ElementName, $driveNum }
                    }
                    While ($item.Parent)
                }
            }

            If ($result.data -ne '')
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'One or more virtual machines are using the system drive'
            }
            Else
            {
                $result.result  = $script:lang['Pass']
                $result.message = 'No virtual machines are using the system drive'
            }
        }
        Else
        {
            $result.result  = $script:lang['Not-Applicable']
            $result.message = 'No virtual machines exist on this host'
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a Hyper-V host server'
    }

    Return $result
}
