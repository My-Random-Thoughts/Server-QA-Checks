<#
    DESCRIPTION: 
        Checks the Microsoft recommendations to help protect against speculative execution side-channel vulnerabilities
        Information taken from: https://support.microsoft.com/help/4072698

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            All registry settings and patches are correct
        WARNING:
        FAIL:
            One or more registry settings or patches are not correct
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sec-18-speculative-execution
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-18-speculative-execution'

    #... CHECK STARTS HERE ...#

    [string]$regKeyValues   = ''

    Try
    {
        # First check if the patch is installed
        [string]$query = 'SELECT Caption FROM Win32_OperatingSystem'
        [string]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Caption
        [string]$patch = ''
        
        If     ($check -like '*2008 R2*') { $patch = 'KB4056897' }
        ElseIf ($check -like '*2012 R2*') { $patch = 'KB4056898' }
        ElseIf ($check -like '*2016*')    { $patch = 'KB4056890' }
        Else
        {
            $result.result  = $script:lang['Not-Applicable']
            $result.message = 'Operating system not supported'
            $result.data    = '{0}' -f $check
            Return $result
        }

        [string]$patchInstalled = ''
        $session  = [activator]::CreateInstance([type]::GetTypeFromProgID('Microsoft.Update.Session', $serverName)) 
        $searcher = $session.CreateUpdateSearcher()
        $history  = $searcher.GetTotalHistoryCount()
        If ($history -gt 0) { $patchInstalled = ($searcher.QueryHistory(0, 99999999) | Where-Object { $_.Title -like "%$patch%" }) }
        If ([string]::IsNullOrEmpty($patchInstalled) -eq $true) { $result.data = 'Patch ' + $patch + ' (missing),#' }

        # Second check the known registry keys
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)

        $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management')    #
        If ($regKey) { [string]$keyVal1 = $regKey.GetValue('FeatureSettingsOverride') }                    # Should be: 0
        If ($keyVal1 -ne '0') { $result.data += 'FeatureSettingsOverride (invalid),#' }
        Try { $regKey.Close() } Catch { $result.data += 'FeatureSettingsOverride (missing),#' }

        $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management')    #
        If ($regKey) { [string]$keyVal2 = $regKey.GetValue('FeatureSettingsOverrideMask') }                # Should be: 3
        If ($keyVal2 -ne '3') { $result.data += 'FeatureSettingsOverrideMask (invalid),#' }
        Try { $regKey.Close() } Catch { $result.data += 'FeatureSettingsOverrideMask (missing),#' }

        $regKey = $reg.OpenSubKey('SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization')           #
        If ($regKey) { [string]$keyVal3 = $regKey.GetValue('MinVmVersionForCpuBasedMitigations') }         # Should be: 1.0
        If ($keyVal3 -ne '1.0') { $result.data += 'MinVmVersionForCpuBasedMitigations (invalid),#' }
        Try { $regKey.Close() } Catch { $result.data += 'MinVmVersionForCpuBasedMitigations (missing),#' }

        $regKey = $reg.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\QualityCompat')               #
        If ($regKey) { [string]$keyVal4 = $regKey.GetValue('cadca5fe-87d3-4b96-b7fb-a231484277cc') }       # Should be: 0
        If ($keyVal4 -ne '0') { $result.data += 'QualityCompat (invalid),#' }
        Try { $regKey.Close() } Catch { $result.data += 'QualityCompat (missing),#' }

        $reg.Close()
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ([string]::IsNullOrEmpty($result.data) -eq $true)
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'All registry settings and patches are correct'
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'One or more registry settings or patches are not correct'
    }

    Return $result
}
