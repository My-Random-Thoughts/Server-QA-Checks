<#
    DESCRIPTION: 
        Check network interfaces for known teaming names, manually check they are configured correctly.  Fail if no teams found or if server is a virtual.  Checked configuration is:
        Teaming Mode: "Static Independent";  Load Balancing Mode: "Address Hash";  Standby Adapter: (set).

    REQUIRED-INPUTS:
        NetworkTeamNames - List of network teaming adapters

    DEFAULT-VALUES:
        NetworkTeamNames = ('HP Network Teaming', 'BASP Virtual Adapter')

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            Network team count: {number}
        WARNING:
        FAIL:
            No teamed network adapter(s) found
            There are no network teams configured on this server
            Native teaming enabled on virtual machine
            Team configuration is not set correctly
        MANUAL:
            Teamed network adpater(s) found, check they are configured correctly
        NA:
            Not a physical server
            Operating system not supported

    APPLIES:
        Physical Servers

    REQUIRED-FUNCTIONS:
        Check-VMware
        Check-HyperV
#>

Function c-net-07-network-teaming
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-net-07-network-teaming'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT Caption FROM Win32_OperatingSystem'
        [string]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Caption

        If ($check -like '*200*')    # 2003, 2008
        {
            [string]$query1 = 'SELECT ProductName, NetConnectionID FROM Win32_NetworkAdapter WHERE ProductName = "dummyValue"'
            $script:appSettings['NetworkTeamNames'] | ForEach { $query1 += ' AND ProductName = "{0}"' -f $script:appSettings['NetworkTeamNames'] }
            [array]$check1 = Get-WmiObject -ComputerName $serverName -Query $query1 -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty NetConnectionID
        }
        ElseIf ($check -like '*201*')    # 2012, 2016
        {
            [string]$query1 = 'SELECT Name, LoadBalancingAlgorithm, TeamingMode FROM MSFT_NetLbfoTeam'
            [array] $check1 = Get-WmiObject -ComputerName $serverName -Query $query1 -Namespace ROOT\StandardCimv2 | Select-Object Name, LoadBalancingAlgorithm, TeamingMode | Sort-Object Name

            If ([string]::IsNullOrEmpty($check1) -eq $false)
            {
                [string]$query2 = 'SELECT Name, Team, AdministrativeMode, FailureReason, OperationalMode FROM MSFT_NetLbfoTeamMember'
                [array] $check2 = Get-WmiObject -ComputerName $serverName -Query $query2 -Namespace ROOT\StandardCimv2 | Select-Object Name, Team, AdministrativeMode, FailureReason, OperationalMode | Sort-Object Name

                [string]$query3 = 'SELECT Team, VlanID FROM MSFT_NetLbfoTeamNic'
                [array] $check3 = Get-WmiObject -ComputerName $serverName -Query $query3 -Namespace ROOT\StandardCimv2 | Select-Object Team, VlanID
            }
            Else
            {
                [array]$check1 = ('NOTEAMS')    # 
            }
        }
        Else
        {
            [array]$check1 = ('UNKNOWN')    # Desktop OS, Unsupported
        }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }


    If ($check -like '*200*')    # 2003, 2008
    {
        If (((Check-VMware $serverName) -eq $false) -and ((Check-HyperV $serverName) -eq $false))
        {
            If ($check1.Count -gt 0)
            {
                $result.result  = $script:lang['Manual']
                $result.message = 'Teamed network adpater(s) found, check they are configured correctly'
                $check1 | ForEach { $result.data += '{0},#' -f $_ }
            }
            Else
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'No teamed network adapter(s) found'
            }
        }
        Else
        {
            $result.result  = $script:lang['Not-Applicable']
            $result.message = 'Not a physical server'
        }
    }
    ElseIf ($check -like '*201*')    # 2012, 2016
    {
        If ($check1 -eq 'NOTEAMS')
        {
            If (((Check-VMware $serverName) -eq $true) -or ((Check-HyperV $serverName) -eq $true))
            {
                $result.result  = $script:lang['Not-Applicable']
                $result.message = 'Not a phsical server'
                $result.data    = ''
            }
            Else
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'There are no network teams configured on this server'
                $result.data    = 'All phyiscal servers should have teamed network adapters'
            }
        }
        Else
        {
            If (((Check-VMware $serverName) -eq $true) -or ((Check-HyperV $serverName) -eq $true))
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'Native teaming enabled on virtual machine'
                $result.data    = 'Virtual machines should not be using network teaming'
            }
            Else
            {
                [array]$teams = @()
                ForEach ($team In $check1)
                {
                    [PSCustomObject]$newTeam = New-Object -TypeName PSObject -Property @{'name'=''; 'lba'=''; 'tm'=''; 'adapters'=@(); 'standby'=''}
                    $newTeam.name = $team.Name
                    $newTeam.lba  = $team.LoadBalancingAlgorithm
                    $newTeam.tm   = $team.TeamingMode

                    ForEach ($nic In $check2)
                    {
                        If ($nic.Team -eq $team.Name)
                        {
                            $newTeam.adapters += $nic.Name
                            If (($nic.AdministrativeMode -eq '1') -and ($nic.FailureReason -eq '1') -and ($nic.OperationalMode -eq '1')) { $newTeam.standby = $nic.Name }
                        }
                    }
                    $teams += $newTeam
                }

                If ($teams.Count -gt 0)
                {
                    [boolean]$pass = $true
                    $result.message = 'Network team count: '+ $teams.Count
                    ForEach ($team In $teams)
                    {
                        [string]$vlan = $check3[$check3.Team.IndexOf($team.name)].VlanID
                        If ($vlan -eq '') { $vlan = 'none' }
                        $result.data += '{0} (vlan: {1}): ' -f $team.name, $vlan

                        Switch ($team.tm)
                        {
                            '0' { $result.data += 'Static Teaming, '    ; $pass = $false }
                            '1' { $result.data += 'Static Independent, '                 }    # Default Config
                            '2' { $result.data += 'LACP, '              ; $pass = $false }
                        }

                        Switch ($team.lba)
                        {
                            '0' { $result.data += 'Address Hash, '                       }    # Default Config
                            '4' { $result.data += 'Hyper-V Port, '      ; $pass = $false }
                            '5' { $result.data += 'Dynamic, '           ; $pass = $false }
                        }

                        If ($team.standby -eq '')
                        {
                            $result.data += 'No standby NIC.#';
                            $pass = $false
                        }
                        Else
                        {
                            $result.data += $team.standby + '.#'
                        }
                    }

                    If ($pass -eq $true)
                    {
                        $result.result  = $script:lang['Pass']
                    }
                    Else
                    {
                        $result.result  = $script:lang['Fail'];
                        $result.message += ', Team configuration is not set correctly'
                    }
                }
                Else
                {
                    $result.result  = $script:lang['Fail']
                    $result.message = 'There are no network teams configured on this server'
                    $result.data    = 'All phyiscal servers should have teamed network adapters'
                }
            }
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Operating system not supported'
        $result.data    = '{0}' -f $check
    }
    Return $result
}
