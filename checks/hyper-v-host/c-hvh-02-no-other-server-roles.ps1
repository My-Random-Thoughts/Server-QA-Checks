<#
    DESCRIPTION: 
        Check Hyper-V is the only one installed.  See this list for IDs: https://msdn.microsoft.com/en-us/library/cc280268(v=vs.85).aspx

    REQUIRED-INPUTS:
        IgnoreTheseRoleIDs - List of IDs that can be ignored|Integer

    DEFAULT-VALUES:
        IgnoreTheseRoleIDs = ('20', '67', '340', '417', '466', '477', '481', '487')

    RESULTS:
        PASS:
            No extra server roles or features exist
        WARNING:
        FAIL:
            One or more extra server roles or features exist
        MANUAL:
        NA:
            Not a Hyper-V server

    APPLIES:
        Hyper-V Host Servers

    REQUIRED-FUNCTIONS:
        Check-NameSpace
        Check-HyperV
#>

Function c-hvh-02-no-other-server-roles
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-hvh-02-no-other-server-roles'
 
    #... CHECK STARTS HERE ...#

    If ((Check-HyperV $serverName) -eq $true)
    {
        Try
        {
            # This will need to be change to use "Get-WindowsFeature" in 2012+
            [string]$query = "Select Name, ID FROM Win32_ServerFeature WHERE ParentID = '0'"
            [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2
            [System.Collections.ArrayList]$check2 = @()
            $check | ForEach { $check2 += $_ }

            ForEach ($ck In $check)
            {
                ForEach ($exc In $script:appSettings['IgnoreTheseRoleIDs'])
                {
                    If ($ck.ID -eq $exc) { $check2.Remove($ck) }
                }
            }
        }
        Catch
        {
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }

        If ($check2.Count -ne 0)
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'One or more extra server roles or features exist'
            $check2 | ForEach { $result.data += '{0},#' -f $_.Name }
        }
        Else
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'No extra server roles or features exist'
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a Hyper-V server'
    }

    Return $result
}
