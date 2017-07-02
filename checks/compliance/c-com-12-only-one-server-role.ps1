<#
    DESCRIPTION: 
        Check that only one server role or feature is installed

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            No extra server roles or features exist
        WARNING:
        FAIL:
            One or more extra server roles or features exist
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-com-12-only-one-server-role
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-com-12-only-one-server-role'
 
    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$queryOS = 'SELECT Caption FROM Win32_OperatingSystem'
        [string]$checkOS = Get-WmiObject -ComputerName $serverName -Query $queryOS -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Caption

        If ($checkOS -like '*2008')        # 2008
        {
            [string]$query = "SELECT Name, ID FROM Win32_ServerFeature WHERE ParentID = '0'"
            [array] $installedRoles = (Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2)
        }
        ElseIf ($checkOS -like '*201*')    # 2012, 2016
        {
            [string]$ignoreList     = '|.NET Framework 4.5 Features|.NET Framework 4.6 Features|File and Storage Services|
                                       |SMB 1.0/CIFS File Sharing Support|User Interfaces and Infrastructure|
                                       |Windows Defender Features|Windows PowerShell|WoW64 Support|'
            [array] $installedRoles = Get-WindowsFeature -ComputerName $serverName | Where-Object { ($_.Depth -eq 1) -and ($_.InstallState -eq 'Installed') -and 
                                                                                                    ($ignoreList.Contains("|$($_.DisplayName)|") -eq $false) } | Select-Object DisplayName
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

    If (([string]::IsNullOrEmpty($installedRoles) -eq $true) -or ($installedRoles.Count -eq 0))
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'No extra server roles or features exist'
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'One or more extra server roles or features exist'
        $installedRoles | ForEach { $result.data += '{0},#' -f $_.DisplayName }
    }

    Return $result
}
