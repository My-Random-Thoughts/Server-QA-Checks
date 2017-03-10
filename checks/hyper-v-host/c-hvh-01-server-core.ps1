<#
    DESCRIPTION: 
        Check Hyper-V is installed on Windows Server Core.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    RESULTS:
        PASS:
            Hyper-V is using Windows Server Core
        WARNING:
        FAIL:
            Hyper-V is not using Windows Server Core
        MANUAL:
        NA:
            Not a Hyper-V server

    APPLIES:
        Hyper-V Host Servers

    REQUIRED-FUNCTIONS:
        Check-HyperV
#>

Function c-hvh-01-server-core
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-hvh-01-server-core'
 
    #... CHECK STARTS HERE ...#

    If ((Check-HyperV $serverName) -eq $true)
    {
        Try
        {
            [string] $query   = 'SELECT Name FROM Win32_ServerFeature WHERE Name = "Server Graphical Shell"'
            [string] $check   = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Name

            If ([string]::IsNullOrEmpty($check) -eq $true)
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'Hyper-V is not using Windows Server Core'
            }
            Else
            {
                $result.result  = $script:lang['Pass']
                $result.message = 'Hyper-V is using Windows Server Core'
            }
        }
        Catch
        {
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a Hyper-V server'
    }

    Return $result
}
