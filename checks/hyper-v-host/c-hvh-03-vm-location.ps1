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
            [string]$query = 'SELECT * FROM Msvm_ComputerSystem WHERE Caption="Virtual Machine"'
            [object]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Virtualization\v2
        }
        Catch
        {
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }

        If ($check.Count -ne 0)
        {
            [string]$result.data = ''
            ForEach ($vm In $check)
            {
                $VSSD = Get-WmiObject -ComputerName $serverName -Query "SELECT * FROM Msvm_VirtualSystemSettingData     WHERE ConfigurationID =              '$($VM.Name)'"  -Namespace ROOT\Virtualization\v2
                $SASD = Get-WmiObject -ComputerName $serverName -Query "SELECT * FROM Msvm_StorageAllocationSettingData WHERE      InstanceID LIKE 'Microsoft:$($VM.Name)%'" -Namespace ROOT\Virtualization\v2

                # Check config location
                If ((-not $($VSSD.ConfigurationDataRoot).StartsWith("$env:SystemDrive\ClusterStorage\")) -and ($($VSSD.ConfigurationDataRoot) -eq $env:SystemDrive))
                {
                    $result.data += '{0}: Configuration,#' -f $VM.ElementName
                }

                # Check hard disk location(s)
                ForEach ($SA In $SASD)
                {
                    [int]   $driveNum  = $(($SA.Parent).Split('\')[11])
                    [string]$drivePath = $SA.HostResource[$driveNum]
                    If ((-not ($drivePath.StartsWith("$env:SystemDrive\ClusterStorage\"))) -and (-not ($drivePath.ToLower()).EndsWith('.iso')))
                    {
                        $result.data += '{0}: Disk {1},#' -f $VM.ElementName, $SA.HostResource[$driveNum]
                    }
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
