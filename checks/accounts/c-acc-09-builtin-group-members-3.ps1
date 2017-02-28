<#
    DESCRIPTION: 
        Checks the builtin group memberships to make sure specific users or groups are members.  If there is only one entry in "GroupMembers", then "AllMustExist" will be set to "TRUE".
        !nThis is check 3 of 3 that can be used to check different groups.

    REQUIRED-INPUTS:
        AllMustExist - "True|False" - Do all group members need to exist for a "Pass"
        GroupMembers - List of users or groups that should listed as a member
        GroupName    - Local group name to check

    DEFAULT-VALUES:
        AllMustExist = 'False'
        GroupMembers = ('')
        GroupName    = ''

    RESULTS:
        PASS:
            No additional users exist
            Additional users exist
        WARNING:
            Invalid group name
        FAIL:
            Additional users exist
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-acc-09-builtin-group-members-3
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-acc-09-builtin-group-members-3'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query     = "SELECT * FROM Win32_Group WHERE Name='$($script:appSettings['GroupName'])' AND LocalAccount='True'"
        [object]$WMIObject = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2

        If ([string]::IsNullOrEmpty($WMIObject) -eq $false)
        {
            [array]$check1 = $WMIObject.GetRelated('Win32_Account', 'Win32_GroupUser', '', '', 'PartComponent', 'GroupComponent', $false, $null) | Select-Object -ExpandProperty Name

            [array]$check2 = @()    # GROUP MEMBERSHIP list
            [array]$check3 = @()    # CHECK NAME list
            ForEach ($Item In $check1) { If ($script:appSettings['GroupMembers'] -notcontains $Item) { $check2 += $Item } }
            If ([string]::IsNullOrEmpty($script:appSettings['GroupMembers']) -eq $false) {
                ForEach ($Item In $script:appSettings['GroupMembers']) { If ($check1 -notcontains $Item) { $check3 += $Item } }
            }

            $check2 = ($check2 | Select-Object -Unique)
            If (($check2.Count -eq 0) -and ($check3.Count -eq 0))
            {
                $result.result  = $script:lang['Pass']
                $result.message = 'No additional users exist'
                $result.data    = $script:appSettings['GroupName']
            }
            Else
            {
                If (($script:appSettings['GroupMembers'].Count) -eq 1) { $script:appSettings['AllMustExist'] = 'True' }
                If  ($script:appSettings['AllMustExist'] -eq 'True')
                {
                    $result.result  = $script:lang['Fail']
                    $result.message = 'Additional users exist'
                    $result.data    = "$($script:appSettings['GroupName']),#In Group: $($check2 -join ', '),#In Check: $($check3 -join ', ')"
                }
                Else
                {
                    $result.result  = $script:lang['Pass']
                    $result.message = 'Additional users exist'
                    $result.data    = "$($script:appSettings['GroupName']),#In Group: $($check2 -join ', '),#In Check: $($check3 -join ', ')"
                }
            }
        }
        Else
        {
            $result.result  = $script:lang['Warning']
            $result.message = 'Invalid group name'
            $result.data    = $script:appSettings['GroupName']
        }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    Return $result
}