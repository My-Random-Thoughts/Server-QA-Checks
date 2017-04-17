<#
    DESCRIPTION: 
        Check that all Windows 2012+ VMs are built as generation 2 VMs

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:    
            All VMs are the correct generation type
        WARNING:
        FAIL:
            One or more Windows 2012+ VMs are not generation 2 VMs
        MANUAL:
        NA:
            No VMs are located on this host
            Not a Hyper-V server

    APPLIES:
        Hyper-V Host Servers

    REQUIRED-FUNCTIONS:
        Check-NameSpace
#>

Function c-hvh-06-generation-type
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-hvh-06-generation-type'
 
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
                $VSMS = Get-WmiObject -Class 'Msvm_VirtualSystemManagementService' -Namespace ROOT\Virtualization\v2
                $Info = $VSMS.GetSummaryInformation($vm.__PATH, (106, 135))

                If ($($Info.SummaryInformation[0].GuestOperatingSystem) -like '*201*')    # 2012, 2016
                {
                    If (($Info.SummaryInformation[0].VirtualSystemSubType).Split(':')[3] -eq '1') { $result.data += "$($vm.ElementName),#" }
                }
            }

            If ($result.data -ne '')
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'One or more Windows 2012+ VMs are not generation 2 VMs'
            }
            ELse
            {
                $result.result  = $script:lang['Pass']
                $result.message = 'All VMs are the correct generation type'
            }
        }
        Else
        {
            $result.result  = $script:lang['Not-Applicable']
            $result.message = 'No VMs are located on this host'
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a Hyper-V host server'
    }

    Return $result
}
