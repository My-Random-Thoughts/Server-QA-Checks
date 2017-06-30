<#
    DESCRIPTION: 
        Check the state of the HPe System Management Homepage service and version

    REQUIRED-INPUTS:
        MinimumVersion - Minimum installed version number allowed|Decimal
        ServiceState   - "Automatic|Manual|Disabled" - Default state of the service

    DEFAULT-VALUES:
        MinimumVersion = '7.6'
        ServiceState   = 'Disabled'

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            Service state and version are correct
        WARNING:
        FAIL:
            Service state is not correct
            Installed version is below the minimum set
            HPe SMH not installed
        MANUAL:
        NA:
            Not a HPe physical server

    APPLIES:
        All HPe Physical Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sys-19-hp-smh-version
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-19-hp-smh-version'
    
    #... CHECK STARTS HERE ...#

    If (isHPServer -eq $true)
    {
        Try
        {
            [string]$state = (Get-WmiObject -ComputerName $serverName -Class Win32_Service -Property StartMode -Filter "DisplayName='HP System Management Homepage'") | Select-Object -ExpandProperty StartMode
        }
        Catch
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'HP System Management Homepage not installed'
            $result.data    = ''
            Return $result
        }

        Try
        {
            $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
            $regKey = $reg.OpenSubKey('SOFTWARE\Hewlett-Packard\System Management Homepage')
            If ($regKey) {
                [string]$keyVal1 = $regKey.GetValue('InstallPath')
                [string]$keyVal2 = $regKey.GetValue('Version')
            }
            Else
            {
                $regKey = $reg.OpenSubKey('SOFTWARE\Wow6432Node\Hewlett-Packard\System Management Homepage')
                If ($regKey) {
                    [string]$keyVal1 = $regKey.GetValue('InstallPath')
                    [string]$keyVal2 = $regKey.GetValue('Version')
                }
            }
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

        $result.result  = $script:lang['Pass']
        $result.message = ''

        If ($state -ne $script:appSettings['ServiceState'])
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Service state is not correct,#'
        }

        If (($keyVal2 -as [version]) -lt ($script:appSettings['MinimumVersion'] -as [version]))
        {
            $result.result   = $script:lang['Fail']
            $result.message += 'Installed version is below the minimum set'
        }

        $result.data = "Install location: $keyVal1,#Installed version: $keyVal2"
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a HPe physical server'
        $result.data    = ''
    }

    Return $result
}

Function isHPServer
{
    $wmiBIOS = Get-WmiObject -ComputerName $ServerName -Class Win32_BIOS -Namespace ROOT\Cimv2 -ErrorAction Stop | Select-Object Manufacturer
    If ($wmiBIOS.Manufacturer -like 'HP*') { Return $true } Else { Return $false }
}