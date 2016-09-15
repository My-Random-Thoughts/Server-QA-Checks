<#
    DESCRIPTION: 
        Checks that the currently logged on user is a member of the domain
        and not a local user account


    PASS:    Currently logged on with domain user account
    WARNING: This is a workgroup server, is this correct.?
    FAIL:    Not currently logged on with current domain user account
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-sys-13-domain-user-logon
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Domain User Logon'
    $result.check  = 'c-sys-13-domain-user-logon'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$usrdom = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\')[0]  # <-- More secure than enviroment variable
        [string]$query  = "SELECT PartOfDomain, Domain FROM Win32_ComputerSystem"
        [object]$check  = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object PartOfDomain, Domain
        [string]$domain = ($check.Domain -split '\.')[0]
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($check.PartOfDomain -eq $true)
    {
        If ($usrdom -eq $domain)
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'Currently logged on with domain user account'
            $result.data    = $check.Domain
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Not currently logged on with current domain user account'
            $result.data    = 'User: {0}, Server: {1}' -f $usrdom, $check.Domain
        }
    }
    Else
    {
        $result.result  = $script:lang['Warning']
        $result.message = 'This is a workgroup server, is this correct.?'
        $result.data    = 'Workgroup: {0}' -f $domain
    }

    Return $result
}