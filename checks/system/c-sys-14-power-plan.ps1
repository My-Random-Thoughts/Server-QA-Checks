<#
    DESCRIPTION: 
        Check power plan is set to High Performance.
        


    PASS:    Power plan is set correctly
    WARNING:
    FAIL:    Power plan is not set correctly
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS: Check-NameSpace
#>

Function c-sys-14-power-plan
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Power Plan'
    $result.check  = 'c-sys-14-power-plan'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        If ((Check-NameSpace -serverName $serverName -namespace 'Cimv2\Power') -eq $true)
        {
            [string]$query = 'SELECT ElementName FROM Win32_PowerPlan WHERE IsActive="True"'
            [string]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2\Power -Authentication PacketPrivacy -Impersonation Impersonate | Select-Object -ExpandProperty ElementName
        }
        If ($check -eq '') { $check = '(Unknown)' }
    }
    Catch
    {
        $result.result  = 'Error'
        $result.message = 'SCRIPT ERROR'
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($check -eq 'High Performance')
    {
        $result.result  = 'Pass'
        $result.message = 'Power plan is set correctly'
        $result.data    = $check
    }
    Else
    {
        $result.result  = 'Fail'
        $result.message = 'Power plan is not set correctly'
        $result.data    = $check
    }

    Return $result
}