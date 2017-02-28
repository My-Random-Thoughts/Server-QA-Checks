<#
    DESCRIPTION: 
        Checks to see if the default local "Administrator" and "Guest" accounts have been renamed.

    REQUIRED-INPUTS:
        InvalidAdminNames - List of names that should not be used

    DEFAULT-VALUES:
        InvalidAdminNames = ('Administrator', 'Admin', 'Guest', 'Guest1')

    RESULTS:
        PASS:
            All local accounts have been renamed
        WARNING:
        FAIL:
            A local account was found that needs to be renamed
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-acc-02-local-account-names
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-acc-02-local-account-names'

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
        $result.message = 'A local account was found that needs to be renamed'
    }
    Else
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'Local accounts have been renamed'
    }
    
    Return $result
}
