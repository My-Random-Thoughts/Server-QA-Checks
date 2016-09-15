<#
    DESCRIPTION: 
        Checks to make sure that the guest user account has been disabled.
        The guest account is located via the well known SID.


    PASS:    Guest account is disabled
    WARNING:
    FAIL:    Guest account has not been disabled
    MANUAL:
    NA:      Guest account does not exist

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-acc-06-guest-account
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-acc-06-guest-account'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT Name, Disabled FROM Win32_UserAccount WHERE LocalAccount="True" AND SID LIKE "%-501"'    # Local Guest account SID always ends in '-501'
        [object]$guest = Get-WmiObject  -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object Name, Disabled
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ([string]::IsNullOrEmpty($guest) -eq $true)
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Guest account does not exist'
    }
    Else
    {
        If ($guest.Disabled -eq $true)
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'Guest account is disabled'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Guest account has not been disabled'
            $result.data    = $guest.Name
        }
    }

    Return $result
}