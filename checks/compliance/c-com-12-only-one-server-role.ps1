<#
    DESCRIPTION: 
        Check that only one server role or feature is installed.  Several roles are ignored by default.

    REQUIRED-INPUTS:
        IgnoreTheseRoles - List of additional roles to ignore (Use the Name, not the DisplayName)

    DEFAULT-VALUES:
        IgnoreTheseRoles = ('')

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            One extra server role or feature installed
        WARNING:
        FAIL:
            One or more extra server roles or features installed
        MANUAL:
        NA:
            No extra server roles or features installed

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        Check-DomainController
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
        If ((Check-DomainController $serverName) -eq $false)
        {
            [string]$queryOS = 'SELECT Caption FROM Win32_OperatingSystem'
            [string]$checkOS = Get-WmiObject -ComputerName $serverName -Query $queryOS -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Caption

            If ($checkOS -like '*server*')
            {
                Import-Module -Name 'ServerManager'                                                                   # Windows 2008                 Windows 2012+
                [System.Collections.ArrayList]$gWinFe  = @(Get-WindowsFeature | Where-Object { ($_.Depth -eq 1) -and (($_.Installed -eq $true) -or ($_.InstallState -eq 'Installed')) } -ErrorAction Stop | Select-Object 'Name', 'DisplayName')
                [System.Collections.ArrayList]$installedRoles = $gWinFe.Clone()

                # These are installed by default on all 2008 R2 and above servers and can be ignored
                [System.Collections.ArrayList]$ignoreList =  ('NET-Framework-Features', 'NET-Framework', 'NET-Framework-45-Features', 'FileAndStorage-Services', 'Multipath-IO', 'RSAT', 'FS-SMB1',
                                                              'Telnet-Client', 'User-Interfaces-Infra', 'PowerShellRoot', 'PowerShell-ISE', 'Windows-Defender-Features', 'WoW64-Support')

                $ignoreList                             | ForEach { [string]$LookingFor = $_; $gWinFe | ForEach { If ($_.Name -eq $LookingFor) { [void]$installedRoles.Remove($_) } } }
                $script:appSettings['IgnoreTheseRoles'] | ForEach { [string]$LookingFor = $_; $gWinFe | ForEach { If ($_.Name -eq $LookingFor) { [void]$installedRoles.Remove($_) } } }
            }
            Else
            {
                $result.result  = $script:lang['Not-Applicable']
                $result.message = 'Operating system not supported'
                $result.data    = $checkOS
                Return $result
            }
        }
        Else
        {
            $result.result  = $script:lang['Not-Applicable']
            $result.message = 'Domain controllers are excempt from this check'
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
        $result.message = 'No extra server roles or features installed'
    }
    ElseIf ($installedRoles.Count -eq 1)
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'One extra server role or feature installed'
        $installedRoles | ForEach { $result.data += '{0},#' -f $_.DisplayName }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'One or more extra server roles or features installed'
        $installedRoles | ForEach { $result.data += '{0},#' -f $_.DisplayName }
    }

    Return $result
}
