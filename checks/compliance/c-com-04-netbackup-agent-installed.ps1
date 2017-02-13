<#
    DESCRIPTION: 
        Check NetBackup agent is installed and that the correct port is open to the management server



    PASS:    {0} found, Port 1556 open to {1}
    WARNING:
    FAIL:    {0} not found / Port 1556 not open to {0} / Backup agent software not found, but this server has {0} installed which requires it / Backup agent software not found, but this server is a domain controller which requires it
    MANUAL:  Is this server backed up via VADP.?  Manually check vCenter annotations, and look for "NetBackup.VADP: 1"
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS: Win32_Product, Test-Port, Check-DomainController, Check-VMware
#>

Function c-com-04-netbackup-agent-installed
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-com-04-netbackup-agent-installed'
    
    #... CHECK STARTS HERE ...#

    [string]$verCheck = Win32_Product -serverName $serverName -displayName $script:appSettings['ProductName']
    If ([string]::IsNullOrEmpty($verCheck) -eq $false)
    {
        $result.result  = $script:lang['Pass']
        $result.message = '{0} found,#' -f $script:appSettings['ProductName']
        $result.data    = 'Version {0}' -f $verCheck

        Try
        {
            $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
            $regKey = $reg.OpenSubKey('Software\Veritas\NetBackup\CurrentVersion\Config')
            If ($regKey) { [string[]]$valNames = $regKey.GetValue('Server') }
            Try {$regKey.Close()} Catch {}
            $reg.Close()
        }
        Catch
        {
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }

        ForEach ($server In $valNames)
        {
            [boolean]$portTest = (Test-Port -serverName $server -Port 1556)
            If   ($portTest -eq $true) {     $result.message += ('Port 1556 open to {0},#'     -f $server) }
            Else { $result.result = $script:lang['Fail'];  $result.message += ('Port 1556 not open to {0},#' -f $server) }
        }
    }
    Else
    {
        If ((Check-VMware $serverName) -eq $true)
        {
            # If backup software not installed, and is a VM, then check for additional software to see if it should be installed
            $found = $false
            $script:appSettings['RequiredServerRoles'] | ForEach {
                [string]$verExist = Win32_Product -serverName $serverName -displayName $_
                If ([string]::IsNullOrEmpty($verCheck) -eq $false)
                {
                    $result.result  = $script:lang['Fail']
                    $result.message = '{0} not found' -f $script:appSettings['ProductName']
                    $result.data    = 'Backup agent software not found, but this server has {0} installed which requires it' -f $_
                    $found          = $true
                }
            }

            If ((Check-DomainController $serverName) -eq $true)
            {
                $result.result  = $script:lang['Fail']
                $result.message = '{0} not found' -f $script:appSettings['ProductName']
                $result.data    = 'Backup agent software not found, but this server is a domain controller which requires it'
                $found          = $true
            }

            If ($found -eq $false)
            {
                $result.result  = $script:lang['Manual']
                $result.message = '{0} not found, VADP backup.?' -f $script:appSettings['ProductName']
                $result.data    = 'Is this server backed up via VADP.?  Manually check vCenter annotations, and look for "NetBackup.VADP: 1"'
            }
        }
        Else
        {
            # Physical server
            $result.result  = $script:lang['Fail']
            $result.message = '{0} not found' -f $script:appSettings['ProductName']
            $result.data    = ''
        }
    }
    
    Return $result
}