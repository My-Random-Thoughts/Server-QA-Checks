<#
    DESCRIPTION: 
        Check that the latest vmware tools are installed.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    RESULTS:
        PASS:
            VMware tools are up to date
        WARNING:
        FAIL:
            VMware tools can be upgraded
        MANUAL:
            Unable to check the VMware Tools upgrade status
        NA:
            Not a virtual machine

    APPLIES:
        Virtual Servers

    REQUIRED-FUNCTIONS:
        Check-VMware
#>

Function c-vmw-01-tools-version
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-vmw-01-tools-version'

    #... CHECK STARTS HERE ...#

    If ((Check-VMware $serverName) -eq $true)
    {
        Try
        {
            [string]$versi = ''
            [string]$check = ''
            If ($serverName -eq $env:ComputerName)
            {
                $versi = Invoke-Command                           -ScriptBlock { &"$env:ProgramFiles\VMware\VMware Tools\VMwareToolBoxCmd.exe" -v   } -ErrorAction SilentlyContinue
                $check = Invoke-Command                           -ScriptBlock { &"$env:ProgramFiles\VMware\VMware Tools\VMwareToolBoxCmd.exe" help } -ErrorAction SilentlyContinue
            }
            Else
            {
                $versi = Invoke-Command -ComputerName $serverName -ScriptBlock { &"$env:ProgramFiles\VMware\VMware Tools\VMwareToolBoxCmd.exe" -v   } -ErrorAction SilentlyContinue
                $check = Invoke-Command -ComputerName $serverName -ScriptBlock { &"$env:ProgramFiles\VMware\VMware Tools\VMwareToolBoxCmd.exe" help } -ErrorAction SilentlyContinue
            }

            If ($check -like '*upgrade*')
            {
                If ($serverName -eq $env:ComputerName) { $check = Invoke-Command                           -ScriptBlock { &"$env:ProgramFiles\VMware\VMware Tools\VMwareToolBoxCmd.exe" upgrade status } -ErrorAction SilentlyContinue }
                Else                                   { $check = Invoke-Command -ComputerName $serverName -ScriptBlock { &"$env:ProgramFiles\VMware\VMware Tools\VMwareToolBoxCmd.exe" upgrade status } -ErrorAction SilentlyContinue }
            }
        }
        Catch { }

        If ($check -like 'VMware Tools are up-to-date*')
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'VMware tools are up to date'
            $result.data    = 'Current Version: {0}' -f $versi
        }
        ElseIf ($check -like 'A new version of VMware Tools is available*')
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'VMware tools can be upgraded'
            $result.data    = 'Current Version: {0}' -f $versi
        }
        ElseIf ($check.StartsWith('Usage:') -eq $true)    # 'UPGRADE' option not available
        {                                                 # Older versions and some OSes.
            $result.result  = $script:lang['Manual']
            $result.message = 'Unable to check the VMware Tools upgrade status'
            $result.data    = 'Current version: {0}.  Open vSphere client, locate "{1}", check to see if the VMware tools can be upgraded, and do so if needed' -f $versi, $serverName
        }
        Else
        {
            $result.result  = $script:lang['Manual']
            $result.message = 'Unable to check the VMware Tools version or upgrade status'
            $result.data    = 'Open vSphere client, locate "{0}", check to see if the VMware tools can be upgraded, and do so if needed' -f $serverName
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a virtual machine'
    }

    Return $result
}