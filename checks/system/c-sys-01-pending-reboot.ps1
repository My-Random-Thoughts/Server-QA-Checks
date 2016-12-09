<#
    DESCRIPTION: 
        Check for a pending reboot



    PASS:    Server is not waiting for a reboot
    WARNING:
    FAIL:    Server is waiting for a reboot
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-sys-01-pending-reboot
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-01-pending-reboot'
    
    #... CHECK STARTS HERE ...#

    Try {
        $result.data = ''
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)

        Try {
            $regKey = $reg.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing')
            If ($regKey) { ForEach ($regVal In $regKey) { If ($regVal -contains 'RebootPending') { $result.data += 'Pending trusted installer operations,#'; Break } } }
            Try { $regKey.Close() } Catch { }
        } Catch { }

        Try {
            $regKey = $reg.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update')
            If ($regKey) { ForEach ($regVal In $regKey.GetSubKeyNames()) { If ($regVal -contains 'RebootRequired') { $result.data += 'Pending windows updates,#'; Break } } }
            Try { $regKey.Close() } Catch { }
        } Catch { }

        Try {
            $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager')
            If ($regKey.GetValue('PendingFileRenameOperations') -ne $null)
            {
                ForEach ($pfro In $regKey.GetValue('PendingFileRenameOperations'))
                { If (($pfro -ne '') -and ($pfro -notlike '*VMwareDnD*')) { $result.data += 'Pending file rename operations,#'; Break } }
            }
            Try { $regKey.Close() } Catch { }
        } Catch { }

        Try {
            $regKey1 = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName\')
            $regKey2 = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName\')
            If ($regKey1.GetValue('ComputerName') -ne $regKey2.GetValue('ComputerName')) { $result.data += 'Pending computer rename,#' }
            Try { $regKey1.Close(); $regKey2.Close() } Catch { }
        } Catch { }

        $reg.Close()
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($result.data -eq '')
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'Server is not waiting for a reboot'
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Server is waiting for a reboot'
    }

    Return $result
}
