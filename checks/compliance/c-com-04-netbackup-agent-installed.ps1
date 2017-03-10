<#
    DESCRIPTION: 
        Check NetBackup agent is installed and that the correct port is open to the management server.
        Only applies to physical servers, or virtual servers with a list of known software installed.

    REQUIRED-INPUTS:
        ProductName         - Full name of the product to look for
        RequiredServerRoles - List of known software to check if installed

    DEFAULT-VALUES:
        ProductName         = 'Symantec NetBackup'
        RequiredServerRoles = ('Exchange', 'SQL')

    RESULTS:
        PASS:
            {product} found, Port 1556 open to {server}
        WARNING:
        FAIL:
            {product} not found
            Port 1556 not open to {server}
            Backup agent software not found, but this server has {role} installed which requires it
            Backup agent software not found, but this server is a domain controller which requires it
        MANUAL:
            Is this server backed up via VADP.?  Manually check vCenter annotations, and look for "NetBackup.VADP: 1"
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        Check-DomainController
        Check-VMware
        Check-Port
        Check-Software
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

    [string]$verCheck = Check-Software -serverName $serverName -displayName $script:appSettings['ProductName']
    If ($verCheck -eq '-1') { Throw 'Error opening registry key' }
    If ([string]::IsNullOrEmpty($verCheck) -eq $false)
    {
        $result.result  = $script:lang['Pass']
        $result.message = '{0} found'     -f $script:appSettings['ProductName']
        $result.data    = 'Version {0},#' -f $verCheck

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
            [boolean]$portTest = (Check-Port -serverName $server -Port 1556)
            If   ($portTest -eq $true)                   { $result.data += ('Port 1556 open to {0},#'     -f $server.ToLower()) }
            Else { $result.result = $script:lang['Fail'];  $result.data += ('Port 1556 not open to {0},#' -f $server.ToLower()) }
        }
    }
    Else
    {
        If ((Check-VMware $serverName) -eq $true)
        {
            # If backup software not installed, and is a VM, then check for additional software to see if it should be installed
            $found = $false
            $script:appSettings['RequiredServerRoles'] | ForEach {
                [string]$verExist = Check-Software -serverName $serverName -displayName $_
                If ($verCheck -eq '-1') { Throw 'Error opening registry key' }
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