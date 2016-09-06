<#
    DESCRIPTION: 
        Check hibernation is turned off



    PASS:    Hibernation is currently disabled
    WARNING:
    FAIL:    Hibernation is currently enabled
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-sys-15-hibernation
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Hibernation'
    $result.check  = 'c-sys-15-hibernation'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query1 = 'SELECT SystemDrive FROM Win32_OperatingSystem'
        [string]$check1 = Get-WmiObject -ComputerName $serverName -Query $query1 -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty SystemDrive
        If ([string]::IsNullOrEmpty($check1) -eq $false)
        {
            # Dev Note: Do not change " to ', it will break this check
            [string]$query2 = "Associators of {Win32_Directory.Name='" + $check1 + "\'} WHERE ResultClass=CIM_DataFile"
            [string]$check2 = Get-WmiObject -ComputerName $serverName -Query $query2 -Namespace ROOT\Cimv2 | Where-Object {$_.name -match 'hiberfil.sys'} | Select-Object -ExpandProperty Name
        }
    }
    Catch
    {
        $result.result  = 'Error'
        $result.message = 'SCRIPT ERROR'
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($check2 -like '*hiberfil.sys')
    {
        $result.result  = 'Fail'
        $result.message = 'Hibernation is currently enabled'
        $result.data    = $check2
    }
    Else
    {
        $result.result  = 'Pass'
        $result.message = 'Hibernation is currently disabled'
        $result.data    = $check2
    }

    Return $result
}