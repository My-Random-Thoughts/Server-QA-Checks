<#
    DESCRIPTION: 
        Check Hyper-V is the only one installed.  See this list for IDs: https://msdn.microsoft.com/en-us/library/cc280268(v=vs.85).aspx

    REQUIRED-INPUTS:
        IgnoreTheseRoleIDs - List of IDs that can be ignored|Integer

    DEFAULT-VALUES:
        IgnoreTheseRoleIDs = ('20', '33', '67', '340', '417', '466', '477', '481', '487')

    DEFAULT-STATE:
        Enabled

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

    If ((Check-NameSpace -ServerName $serverName -NameSpace 'ROOT\Virtualization') -eq $true)
    {
        Try
        {
            [string]$queryOS = 'SELECT Caption FROM Win32_OperatingSystem'
            [string]$checkOS = Get-WmiObject -ComputerName $serverName -Query $queryOS -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Caption

            If ($checkOS -like '*2008*')       # 2008
            {
                [string]$query = "SELECT Name, ID FROM Win32_ServerFeature WHERE ParentID = '0'"
                [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2
            }
            ElseIf ($checkOS -like '*201*')    # 2012, 2016
            {
                [array] $check = (Get-WindowsFeature -ComputerName $serverName | Where-Object { ($_.Depth -eq 1) -and ($_.InstallState -eq 'Installed') } |
                                                                                 Select-Object @{N='Id'; E={$_.AdditionalInfo.NumericId}}) |
                                                                                 Select-Object -ExpandProperty Id
            }
            Else
            {
                $result.result  = $script:lang['Not-Applicable']
                $result.message = 'Operating system not supported'
                $result.data    = $checkOS
                Return $result
            }

            [System.Collections.ArrayList]$check2 = @()
            $check | ForEach { $check2.Add($_) | Out-Null }
            ForEach ($ck In $check) { ForEach ($exc In $script:appSettings['IgnoreTheseRoleIDs']) { If ($ck.Id -eq $exc) { $check2.Remove($exc) } } }
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
        $result.message = 'Not a Hyper-V host server'
    }

    Return $result
}
