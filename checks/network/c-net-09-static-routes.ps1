<#
    DESCRIPTION:
        Checks to make sure the specified static routes have been added.  Add routes to check as: StaticRoute01 = ("source", "mask", "gateway").
        To check for no extra persistent routes, use: StaticRoute01 = ("None", "", "").  Up to 99 routes can be checked.
        You must edit the settings file manually for more than the currently configured.

    REQUIRED-INPUTS:
        StaticRoute01 - List of IPs for a single static route to check.  Order is: Source, Mask, Gateway|IPv4
        StaticRoute02 - List of IPs for a single static route to check.  Order is: Source, Mask, Gateway|IPv4
        StaticRoute03 - List of IPs for a single static route to check.  Order is: Source, Mask, Gateway|IPv4
        StaticRoute04 - List of IPs for a single static route to check.  Order is: Source, Mask, Gateway|IPv4

    DEFAULT-VALUES:
        StaticRoute01 = ('', '', '')
        StaticRoute02 = ('', '', '')
        StaticRoute03 = ('', '', '')
        StaticRoute04 = ('', '', '')

    RESULTS:
        PASS:
            All static routes are present
        WARNING:
        FAIL:
            One or more static routes are missing or incorrect
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
        [string]$query1 = 'SELECT Destination, Mask, NextHop FROM Win32_IP4RouteTable'
        [object]$check1 = Get-WmiObject -ComputerName $serverName -Query $query1 -Namespace ROOT\Cimv2 | Select-Object Destination, Mask, NextHop
        
        [string]$query2 = 'SELECT Destination, Mask, NextHop FROM Win32_IP4PersistedRouteTable'
        [object]$check2 = Get-WmiObject -ComputerName $serverName -Query $query2 -Namespace ROOT\Cimv2 | Select-Object Destination, Mask, NextHop
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

    If ([string]::IsNullOrEmpty($check1) -eq $true)
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
        If ([string]::IsNullOrEmpty($check2) -eq $false)
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Static routes are present, they need removing'
        }
        Else
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'No static routes are present'
        }
    }
    Else
    {
        For ($i = 1; $i -le 99; $i++)
        {
            [string[]]$routeEntry = $script:appSettings["StaticRoute$(($i -as [string]).PadLeft(2, '0'))"]
            If ([string]::IsNullOrEmpty($routeEntry) -eq $false)
            {
                If ([string]::IsNullOrEmpty($routeEntry[0]) -eq $false)
                {
                    $pos = [array]::IndexOf($check1.Destination, $routeEntry[0])
                    If ($pos -ge 0)
                    {
                        If ($check1.Mask[$pos]    -ne $routeEntry[1]) { $result.data += '' + $routeEntry[0] + ' (Wrong Mask),#'    }
                        If ($check1.NextHop[$pos] -ne $routeEntry[2]) { $result.data += '' + $routeEntry[0] + ' (Wrong Gateway),#' }
                    }
                    Else { $result.data += '' + $routeEntry[0] + ' (Missing),#' }
                }
            }
            $routeEntry = $null
        }

        If ($result.data -eq '')
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'All static routes are present'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'One or more static routes are missing or incorrect'
        }
    }

    Return $result
}
