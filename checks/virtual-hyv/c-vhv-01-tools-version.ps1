<#
    DESCRIPTION: 
        Check that the latest HyperV tools are installed



    PASS:    HyperV tools are up to date
    WARNING:
    FAIL:    HyperV tools can be upgraded
    MANUAL:  Unable to check the HyperV Tools upgrade status
    NA:      Not a virtual machine

    APPLIES: Virtuals

    REQUIRED-FUNCTIONS: Check-HyperV
#>

Function c-vhv-01-tools-version
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'HyperV Tools Version'
    $result.check  = 'c-vhv-01-tools-version'

    #... CHECK STARTS HERE ...#

    If ((Check-HyperV $serverName) -eq $true)
    {
        Try
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'Dummy Check'
            $result.data    = 'Dummy Check'
        }
        Catch
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Dummy Check'
            $result.data    = 'Dummy Check'
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a virtual machine'
    }

    Return $result
}