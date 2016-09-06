<#
    DESCRIPTION: 
        Check Hyper-V is installed on server core



    PASS:    Hyper-V is using Windows Server Core
    WARNING:
    FAIL:    Hyper-V is not using Windows Server Core
    MANUAL:
    NA:      Not a Hyper-V server

    APPLIES: Hyper-V Hosts

    REQUIRED-FUNCTIONS: Check-NameSpace
#>

Function c-hvh-01-server-core
{
    Param ( [string]$serverName, [string]$resultPath )

    # Default Result Object
    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Server Core'
    $result.check  = 'c-hvh-01-server-core'
 
    # ...
    If ((Check-NameSpace -serverName $serverName -namespace 'virtualization') -and (Check-NameSpace -serverName $serverName -namespace 'virtualization\v2') -eq $true)
    {
        Try
        {
            [string] $query   = 'SELECT Name FROM Win32_ServerFeature WHERE Name = "Server Graphical Shell"'
            [string] $check   = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Name

            If ([string]::IsNullOrEmpty($check) -eq $true)
            {
                $result.result  = 'Fail'
                $result.message = 'Hyper-V is not using Windows Server Core'
            }
            Else
            {
                $result.result  = 'Pass'
                $result.message = 'Hyper-V is using Windows Server Core'
            }
        }
        Catch
        {
            $result.result  = 'Error'
            $result.message = 'SCRIPT ERROR'
            $result.data    = $_.Exception.Message
            Return $result
        }
    }
    Else
    {
        $result.result  = 'N/A'
        $result.message = 'Not a Hyper-V server'
    }

    Return $result
}