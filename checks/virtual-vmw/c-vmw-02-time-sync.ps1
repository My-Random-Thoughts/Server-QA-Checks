<#
    DESCRIPTION: 
        Check that VMware Host Time Sync is disabled



    PASS:    VMware tools time sync is disabled
    WARNING:
    FAIL:    VMware tools time sync is enabled
    MANUAL:  Unable to check the VMware time sync status
    NA:      Not a virtual machine

    APPLIES: Virtuals

    REQUIRED-FUNCTIONS: Check-VMware
#>

Function c-vmw-02-time-sync
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'VMware Time Sync'
    $result.check  = 'c-vmw-02-time-sync'

    #... CHECK STARTS HERE ...#

    If ((Check-VMware $serverName) -eq $true)
    {
        Try
        {
            [string]$check = ''

            If ($serverName -eq $env:ComputerName) {
                $check = Invoke-Command                           -ScriptBlock { &"$env:ProgramFiles\VMware\VMware Tools\VMwareToolBoxCmd.exe" timesync status } -ErrorAction SilentlyContinue
            }
            Else {
                $check = Invoke-Command -ComputerName $serverName -ScriptBlock { &"$env:ProgramFiles\VMware\VMware Tools\VMwareToolBoxCmd.exe" timesync status } -ErrorAction SilentlyContinue
            }
        }
        Catch { }

        If ($check -eq 'Disabled')
        {
            $result.result  = 'Pass'
            $result.message = 'VMware tools time sync is disabled'
        }
        ElseIf ($check -eq 'Enabled')
        {
            $result.result  = 'Fail'
            $result.message = 'VMware tools time sync is enabled'
        }
        Else
        {
            $result.result  = 'Manual'
            $result.message = 'Unable to check the VMware time sync status'
            $result.data    = 'Open vSphere client, locatate "{0}", select Edit Settings, Options tab, Select VMware Tools, make sure "Synchronize guest time with host" is not enabled' -f $serverName
        }
    }
    Else
    {
        $result.result  = 'N/A'
        $result.message = 'Not a virtual machine'
    }

    Return $result
}