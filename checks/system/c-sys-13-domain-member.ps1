<#
    DESCRIPTION: 
        Checks that the server is a member of the domain.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    RESULTS:
        PASS:
            Server is a domain member
        WARNING:
            This is a workgroup server, is this correct.?
        FAIL:    
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sys-13-domain-member
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-13-domain-member'

    #... CHECK STARTS HERE ...#

    Try
    {
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
        $result.result  = $script:lang['Pass']
        $result.message = 'Server is a domain member'
        $result.data    = ($check.Domain)
    }
    Else
    {
        $result.result  = $script:lang['Warning']
        $result.message = 'This is a workgroup server, is this correct.?'
        $result.data    = 'Workgroup: {0}' -f $domain
    }

    Return $result
}