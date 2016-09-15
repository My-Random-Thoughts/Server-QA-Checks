<#
    DESCRIPTION:
        Checks to make sure the specified static routes have been added



    PASS:    All static routes are present
    WARNING:
    FAIL:    One or more static routes are missing or incorrect
    MANUAL:
    NA:      No static routes to check

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-net-09-static-routes
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Static Routes'
    $result.check  = 'c-net-09-static-routes'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT Destination, Mask, NextHop FROM Win32_IP4RouteTable'
        [object]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object Destination, Mask, NextHop
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    [boolean]$RoutesToCheck = $false
    For ($i = 1; $i -le 99; $i++)
    {
        [string[]]$routeEntry = $script:appSettings["StaticRoute$(($i -as [string]).PadLeft(2, '0'))"]
        If ([string]::IsNullOrEmpty($routeEntry) -eq $false) { $RoutesToCheck = $true; Break }
    }
    
    If ($RoutesToCheck -eq $false)
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'No static routes to check'
        Return $result
    }

    If ([string]::IsNullOrEmpty($check) -eq $true)
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'No static routes present'
    }
    Else
    {
        For ($i = 1; $i -le 99; $i++)
        {
            [string[]]$routeEntry = $script:appSettings["StaticRoute$(($i -as [string]).PadLeft(2, '0'))"]
            If ([string]::IsNullOrEmpty($routeEntry) -eq $false)
            {
                $pos = [array]::IndexOf($check.Destination, $routeEntry[0])
                If ($pos -ge 0)
                {
                    If ($check.Mask[$pos]    -ne $routeEntry[1]) { $result.data += '' + $routeEntry[0] + ' (Wrong Mask),#'    }
                    If ($check.NextHop[$pos] -ne $routeEntry[2]) { $result.data += '' + $routeEntry[0] + ' (Wrong Gateway),#' }
                }
                Else { $result.data += '' + $routeEntry[0] + ' (Missing),#' }
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