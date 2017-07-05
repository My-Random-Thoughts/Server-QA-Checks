<#
    DESCRIPTION: 
        Ensure SMBv1 is disabled. 

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            SMBv1 is disabled
        WARNING:
        FAIL:
            SMBv1 is enabled
            Registry setting not found
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sec-17-smb1-disabled
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-17-smb1-disabled'

    #... CHECK STARTS HERE ...#

    Try
    {
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)

        $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters')
        If ($regKey) { [string]$keyVal1 = $regKey.GetValue('SMB1') }                 #: 0
        Try { $regKey.Close() } Catch { }

        $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\LanmanWorkstation')
        If ($regKey) { [string[]]$keyVal2 = $regKey.GetValue('DependOnService') }    #: Bowser, MRxSmb20, NSI
        Try { $regKey.Close() } Catch { }

        $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\services\mrxsmb10')
        If ($regKey) { [string]$keyVal3 = $regKey.GetValue('Start') }                #: 4
        Try { $regKey.Close() } Catch { }

        $reg.Close()
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    [int]$validCount = 0
    If (([string]::IsNullOrEmpty($keyVal1) -eq $false) -and ($keyVal1  -eq '0')) { $validCount++ } Else { $result.data += '\Services\LanmanServer\Parameters,#' }
    If ([string]::IsNullOrEmpty($keyVal2) -eq $false)
    {
        [string]$keyval2b = [string]::Join(',', $keyVal2)
        If ($keyVal2b -eq 'Bowser,MRxSmb20,NSI') { $validCount++ } Else { $result.data += '\Services\LanmanWorkstation,#' }
    }
    If (([string]::IsNullOrEmpty($keyVal3) -eq $false) -and ($keyVal3  -eq '4')) { $validCount++ } Else { $result.data += '\services\mrxsmb10,#' }

    If ($validCount -eq 3)
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'SMBv1 is disabled'
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'SMBv1 is enabled'
    }

    Return $result
}