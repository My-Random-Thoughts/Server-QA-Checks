<#
    DESCRIPTION: 
        Checks the builtin group memberships to make sure specific users or groups are members.
        If there is only one entry in "GroupMembers", then "AllMustExist" will be forced to "TRUE"
        This is check 3 of 3 that can be used to check different groups.

    PASS:    No additional users exist / Additional users exist
    WARNING: Invalid group name
    FAIL:    Additional users exist
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
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

            [System.Collections.ArrayList]$check2 = @()    # GROUP MEMBERSHIP list
            [System.Collections.ArrayList]$check3 = @()    # CHECK NAME list
            ForEach ($Item In $check1)                             { If ($script:appSettings['GroupMembers'] -notcontains $Item) { $check2.Add($Item) | Out-Null } }
            ForEach ($Item In $script:appSettings['GroupMembers']) { If (                            $check1 -notcontains $Item) { $check3.Add($Item) | Out-Null } }

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
