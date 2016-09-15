<#
    DESCRIPTION: 
        Checks to see if the local default accounts have been renamed.
        The "Administrator" and "Guest" accounts should be.


    PASS:    Local admin account has been renamed
    WARNING:
    FAIL:    A local admin account was found that needs to be renamed
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-acc-02-local-admin-name
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-acc-02-local-admin-name'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT Name FROM Win32_UserAccount WHERE LocalAccount="True"'
        [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Name
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    $accsFound = 0
    ForEach ($acc In $check)
    {
        $script:appSettings['InvalidAdminNames'] | ForEach {
            If ($acc -like $_)
            {
                $accsFound += 1
                $result.data += '{0},#' -f $acc
            }
        }
    }

    If ($accsFound -gt 0)
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'A local admin account was found that needs to be renamed'
    }
    Else
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'Local admin account has been renamed'
    }
    
    Return $result
}