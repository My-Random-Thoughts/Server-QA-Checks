<#
    DESCRIPTION: 
        Check to see if a list of software title are installed.

    REQUIRED-INPUTS:
        ProductName - List of product names to check for.  Name should be the string found in install programs list (Add/Remove Programs / Programs And Features).
        AllMustExist - "True|False" - Should all entries exist for a Pass.?

    DEFAULT-VALUES:
        ProductName = ('')
        AllMustExist = 'True'

    DEFAULT-STATE:
        Skip

    RESULTS:
        PASS:
            All product titles were found
            One or more product titles were found
        WARNING:
        FAIL:
            One or more product titles were not found
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        Check-Software
#>

Function c-com-10-software-installed
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-com-10-software-installed'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$found   = ''
        [string]$missing = ''

        ForEach ($title In $script:appSettings['ProductName'])
        {
            If ($title -ne '')
            {
                $script:appSettings['Win32_Product'] = 'Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'    # Reset search path

                [string]$verCheck = Check-Software -serverName $serverName -displayName $title
                If ($verCheck -eq '-1') { Throw 'Error opening registry key' }
                If ([string]::IsNullOrEmpty($verCheck) -eq $true) { $missing += "$title,#" } Else { $found += ('{0} (v{1}),#' -f $title, $verCheck ) }
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

    If (($missing.Length -gt 0) -and ($script:appSettings['AllMustExist'] -eq 'True'))
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'One or more product titles were not found'
        $result.data    = $missing
    }
    ElseIf (($missing.Length -gt 0) -and ($script:appSettings['AllMustExist'] -eq 'False'))
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'One or more product titles were found'
        $result.data    = $found
    }
    Else
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'All product titles were found'
        $result.data    = ''
    }

    Return $result
}