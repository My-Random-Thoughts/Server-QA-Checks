<#
    DESCRIPTION: 
        Check sentinel monitoring agent is installed, and that the correct port is open to the management server



    PASS:    Sentinel agent found, Port {0} open to {1}
    WARNING:
    FAIL:    Sentinel agent not found, install required / Port {0} not open to {1}
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS: Win32_Product, Test-Port
#>

Function c-com-07-sentinel-agent-installed
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-com-07-sentinel-agent-installed'

    #... CHECK STARTS HERE ...#

    [string]$verCheck = Win32_Product -serverName $serverName -displayName 'NetIQ Sentinel Agent'
    If ([string]::IsNullOrEmpty($verCheck) -eq $false)
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'Sentinel agent found,#'
        $result.data    = 'Version {0}' -f $verCheck

        Try
        {
            $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
            $regKey = $reg.OpenSubKey('Software\Wow6432Node\NetIQ\Security Manager\Configurations')
            If ($regKey) { [string[]]$regAgt = ($regKey.GetSubKeyNames()) }
            Try {$regKey.Close() } Catch {}

            $regKey = $reg.OpenSubKey("Software\Wow6432Node\NetIQ\Security Manager\Configurations\$($regAgt[0])\Operations\Agent\Consolidators")
            If ($regKey) {
                [array]$valCons = @()
                ForEach ($key In (0..9))
                {
                    $valCons += $(New-Object -TypeName PSObject -Property @{'host' = $($regKey.GetValue("Consolidator $key Host")); `
                                                                            'port' = $($regKey.GetValue("Consolidator $key Port")); } )
                }
            }
            Try {$regKey.Close() } Catch {}
            $reg.Close()
        }
        Catch
        {
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }

        ForEach ($key In (0..9))
        {
            If ([string]::IsNullOrEmpty($($valCons[$key].host)) -eq $false)
            {
                $portTest = Test-Port -serverName $($valCons[$key].host) -Port $($valCons[$key].port)
                If ($portTest -eq $true) { $result.message += ('Port {0} open to {1}'     -f $($valCons[$key].port), $($valCons[$key].host))                                        }
                Else                     { $result.message += ('Port {0} not open to {1}' -f $($valCons[$key].port), $($valCons[$key].host)); $result.result = $script:lang['Fail'] }
            }
        }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Sentinel agent not found, install required'
    }

    Return $result
}
