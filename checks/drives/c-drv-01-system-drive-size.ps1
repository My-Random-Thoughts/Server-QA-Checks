<#
    DESCRIPTION: 
        Check the system drive is a minimum of 50gb for Windows 2008+ servers (some are reporting 49gb)
        


    PASS:    System drive ({0}) meets minimum required size
    WARNING:
    FAIL:    System drive ({0}) is too small, should be {1}gb
    MANUAL:  Unable to get drive size, please check manually
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-drv-01-system-drive-size
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'System Drive Size'
    $result.check  = 'c-drv-01-system-drive-size'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query1 = 'SELECT SystemDrive FROM Win32_OperatingSystem'
        [string]$check1 = Get-WmiObject -ComputerName $serverName -Query $query1 -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty SystemDrive
        If ([string]::IsNullOrEmpty($check1) -eq $false)
        {
            [string]$query2 = 'SELECT Size FROM Win32_LogicalDisk WHERE Name = "{0}"' -f $check1
            [string]$check2 = Get-WmiObject -ComputerName $serverName -Query $query2 -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Size
            [int]   $sizeGB = [decimal]::Round(($check2 / (1024*1024*1024)))
        }
        Else
        {
            [int]$sizeGB = -1
        }
    }
    Catch
    {
        $result.result  = 'Error'
        $result.message = 'SCRIPT ERROR'
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($sizeGB -ne -1)
    {
        If ($sizeGB -ge $script:appSettings['MinimumSystemDriveSize'])
        {
            $result.result  = 'Pass'
            $result.message = 'System drive ({0}) meets minimum required size' -f $check1
            $result.data    = 'Size: {0}gb' -f $sizeGB
        }
        Else
        {
            $result.result  = 'Fail'
            $result.message = 'System drive ({0}) is too small, should be {1}gb' -f $check1, $script:appSettings['MinimumSystemDriveSize']
            $result.data    = 'Size: {0}gb' -f $sizeGB
        }
    }
    Else
    {
        $result.result  = 'Manual'
        $result.message = 'Unable to get drive size, please check manually'
        $result.data    = 'System drive needs to be {0}gb or larger' -f $script:appSettings['MinimumSystemDriveSize']
    }

    Return $result
}