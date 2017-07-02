<#
    DESCRIPTION: 
        Check that Failover Clustering is not be installed on virtual servers.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Disabled

    RESULTS:
        PASS:
            Failover clustering is not installed
        WARNING:
        FAIL:
            Failover clustering is installed
        MANUAL:
        NA:
            Not a virtual server

    APPLIES:
        Virtual Servers

    REQUIRED-FUNCTIONS:
        Check-HyperV
        Check-VMware
#>

Function c-vmw-08-failover-clustering
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-vmw-08-failover-clustering'
 
    #... CHECK STARTS HERE ...#

    If (((Check-HyperV $serverName) -eq $true) -or ((Check-VMware $serverName) -eq $true))
    {
        Try
        {
            [string]$queryOS = 'SELECT Caption FROM Win32_OperatingSystem'
            [string]$checkOS = Get-WmiObject -ComputerName $serverName -Query $queryOS -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Caption

            If ($checkOS -like '*2008')        # 2008
            {
                [string]$query = "SELECT Name FROM Win32_ServerFeature WHERE Name='Failover Clustering'"
                [string]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Name
            }
            ElseIf ($checkOS -like '*201*')    # 2012, 2016
            {
                [string]$check = (Get-WindowsFeature -ComputerName $serverName -Name 'Failover-Clustering').InstallState    # Returns: 'Available' or 'Installed'
            }
            Else
            {
                $result.result  = $script:lang['Not-Applicable']
                $result.message = 'Operating system not supported'
                $result.data    = $checkOS
                Return $result
            }
        }
        Catch
        {
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }

        If (($check -eq 'Installed') -or ($check -eq 'Failover Clustering'))
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Failover clustering is installed'
        }
        Else
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'Failover clustering is not installed'
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a virtual server'
    }

    Return $result
}
