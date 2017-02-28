<#
    DESCRIPTION: 
        Check windows is licensed.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    RESULTS:
        PASS:
            Windows is licenced, Port 1688 open to KMS Server {server}
        WARNING:
        FAIL:
            Windows is licenced, Port 1688 not open to KMS Server {server}
            Windows licence check failed
            Windows not licenced
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        Test-Port
#>

Function c-sys-02-windows-license
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-02-windows-license'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        If ((Get-WmiObject -ComputerName $serverName -Namespace ROOT\Cimv2 -List 'SoftwareLicensingProduct').Name -eq 'SoftwareLicensingProduct')
        {
            [string]$query1 = 'SELECT LicenseStatus FROM SoftwareLicensingProduct WHERE ApplicationID="55c92734-d682-4d71-983e-d6ec3f16059f" AND NOT LicenseStatus = "0"'
            [array] $check1 = Get-WmiObject -ComputerName $serverName -Query $query1 -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty LicenseStatus
        }

        If ((Get-WmiObject -ComputerName $serverName -Namespace ROOT\Cimv2 -List 'SoftwareLicensingService').Name -eq 'SoftwareLicensingService')
        {
            [string]$query2 = "SELECT KeyManagementServiceMachine, DiscoveredKeyManagementServiceMachineName FROM SoftwareLicensingService"
            [object]$check2 = Get-WmiObject -ComputerName $serverName -Query $query2 -Namespace ROOT\Cimv2 | Select KeyManagementServiceMachine, DiscoveredKeyManagementServiceMachineName
        }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    [string]$kms    = ''
    [string]$status = ''
    If ($check1.Count -gt 0)
    {
        Switch ($check1[0])
        {
                  1 { $status = 'Licensed';                      Break }    # <-- Requried for PASS
                  2 { $status = 'Out-Of-Box Grace Period';       Break }
                  3 { $status = 'Out-Of-Tolerance Grace Period'; Break }
                  4 { $status = 'Non-Genuine Grace Period';      Break }
                  5 { $status = 'Notification';                  Break }
                  6 { $status = 'Extended Grace';                Break }
            Default { $status = 'Unknown'                              }
        }
    }
    Else
    {
        $status = 'Not Licensed'
    }    

    If ($check2.DiscoveredKeyManagementServiceMachineName -ne '') { $kms = $check2.DiscoveredKeyManagementServiceMachineName }
    If ($check2.KeyManagementServiceMachine               -ne '') { $kms = $check2.KeyManagementServiceMachine               }

    If ($kms -ne '')
    {
        [boolean]$portTest = Test-Port -serverName $kms -Port 1688
        If ($portTest -eq $true)
        {
            $result.result  = $script:lang['Pass']
            $result.data    = ('Port 1688 open to KMS Server {0}' -f $kms.ToLower())
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.data    = ('Port 1688 not open to KMS Server {0}' -f $kms.ToLower())
        }
    }
    Else
    {
        $result.result  = $script:lang['Warning']
        $result.data    = 'Not using a KMS server'
    }

    If ($status -eq 'Licensed')
    {
        $result.message = 'Windows is licenced'
    }
    ElseIf ($status -eq '')
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Windows licence check failed'
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Windows not licenced'
        $result.data    = ('Status: {0},#{1}' -f $status, $result.data)
    }

    Return $result
}
