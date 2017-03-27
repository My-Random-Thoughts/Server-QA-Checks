<#
    DESCRIPTION: 
        Check power plan is set to High Performance.
        
    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    RESULTS:
        PASS:
            Power plan is set correctly
        WARNING:
        FAIL:
            Power plan is not set correctly
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        Check-NameSpace
#>

Function c-sys-14-power-plan
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-14-power-plan'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        If ((Check-NameSpace -ServerName $serverName -NameSpace 'ROOT\Cimv2\Power') -eq $true)
        {
            [string]$query = 'SELECT ElementName FROM Win32_PowerPlan WHERE IsActive="True"'
            [string]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2\Power -Authentication PacketPrivacy -Impersonation Impersonate | Select-Object -ExpandProperty ElementName
        }
        If ($check -eq '') { $check = '(Unknown)' }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($check -eq 'High Performance')
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'Power plan is set correctly'
        $result.data    = $check
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Power plan is not set correctly'
        $result.data    = $check
    }

    Return $result
}