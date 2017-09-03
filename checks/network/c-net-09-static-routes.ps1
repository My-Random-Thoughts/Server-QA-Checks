<#
    DESCRIPTION:
        Checks to make sure the specified static routes have been added.  Add routes to check as: StaticRoute01 = ("source", "mask", "gateway").
        To check for no extra persistent routes, use: StaticRoute01 = ("None", "", "").  Up to 99 routes can be checked.
        You must edit the settings file manually for more than the currently configured.

    REQUIRED-INPUTS:
        AllMustExist  - "True|False" - Should all static route entries exist for a Pass.?
        StaticRoute01 - List of IPs for a single static route to check.  Order is: Destination, Mask, Gateway|IPv4
        StaticRoute02 - List of IPs for a single static route to check.  Order is: Destination, Mask, Gateway|IPv4
        StaticRoute03 - List of IPs for a single static route to check.  Order is: Destination, Mask, Gateway|IPv4
        StaticRoute04 - List of IPs for a single static route to check.  Order is: Destination, Mask, Gateway|IPv4
        StaticRoute05 - List of IPs for a single static route to check.  Order is: Destination, Mask, Gateway|IPv4
        DestinationMustNotExist - Destination IP that must not exist in the route table|IPv4
        
    DEFAULT-VALUES:
        AllMustExist  = 'False'
        StaticRoute01 = ('', '', '')
        StaticRoute02 = ('', '', '')
        StaticRoute03 = ('', '', '')
        StaticRoute04 = ('', '', '')
        StaticRoute05 = ('', '', '')
        DestinationMustNotExist = ''

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            Required static routes are present
        WARNING:
        FAIL:
            One or more static routes are missing or incorrect
            All entered static routes are missing
        MANUAL:
        NA:
            No static routes to check

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-net-09-static-routes
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-net-09-static-routes'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT Destination, Mask, NextHop FROM Win32_IP4PersistedRouteTable'
        [object]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object Destination, Mask, NextHop
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    [boolean]$noneEntry     = $false
    [boolean]$RoutesToCheck = $false
    Try
    {
        For ($i = 1; $i -le 99; $i++)
        {
            [string[]]$routeEntry = $script:appSettings["StaticRoute$(($i -as [string]).PadLeft(2, '0'))"]
            If ([string]::IsNullOrEmpty($routeEntry[0]) -eq $false) { $RoutesToCheck = $true; Break }
        }
        If (($script:appSettings['StaticRoute01'][0]) -eq 'None') { $noneEntry = $true }
    }
    Catch {}

    If ([string]::IsNullOrEmpty($DestinationMustNotExist) -eq $false)
    {
        ForEach ($item In $check)
        {
            If ($item.Destination -eq $DestinationMustNotExist)
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'Static route exists that must not'
                $result.data    = $DestinationMustNotExist
                Return $result
            }
        }
    }

    If ([string]::IsNullOrEmpty($check) -eq $true)
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'No static routes present'
    }
    ElseIf ($RoutesToCheck -eq $false)
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'No static routes to check'
        Return $result
    }
    ElseIf ($noneEntry -eq 'None')
    {
        If ([string]::IsNullOrEmpty($check) -eq $false)
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Static routes are present, they need removing'
            $result.data    = 'Dest: {0}, Mask: {1}, Gateway: {2},#' -f $check.Destination, $check.Mask, $check.NextHop
        }
        Else
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'No static routes are present'
        }
    }
    Else
    {
        [int]   $entryCount    = 0
        [int]   $ignoreCount   = 0
        [string]$ignoreEntries = ''
        For ($i = 1; $i -le 99; $i++)
        {
            [string[]]$routeEntry = $script:appSettings["StaticRoute$(($i -as [string]).PadLeft(2, '0'))"]
            If ([string]::IsNullOrEmpty($routeEntry) -eq $false)
            {
                If ([string]::IsNullOrEmpty($routeEntry[0]) -eq $false)
                {
                    $entryCount++
                    [boolean]$found = $false
                    ForEach ($item In $check)
                    {
                        If ($item.Destination -eq $routeEntry[0])
                        {
                            $found = $true
                            If ($item.Mask    -ne $routeEntry[1]) { $result.data += '' + $routeEntry[0] + ' (Wrong Mask),#'    }
                            If ($item.NextHop -ne $routeEntry[2]) { $result.data += '' + $routeEntry[0] + ' (Wrong Gateway),#' }
                        }
                    }

                    If ($found -eq $false)
                    {
                        If ($script:appSettings['AllMustExist'] -eq 'True') { $result.data += "$($routeEntry[0]) (Missing),#" }
                        Else {                              $ignoreCount++; $ignoreEntries += "$($routeEntry[0]) (Missing),#" }
                    }
                }
            }
            $routeEntry = $null
        }

        If ($ignoreCount -eq $entryCount)
        {
            $result.message = 'All entered static routes are missing'
            $result.data    = $ignoreEntries
        }

        If ($result.data -eq '')
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'Required static routes are present'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            If ([string]::IsNullOrEmpty($result.message) -eq $true) { $result.message = 'One or more static routes are missing or incorrect' }
        }
    }

    Return $result
}
