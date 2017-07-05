<#
    DESCRIPTION: 
        Check that all the memory assigned to a server is visible to the OS.
        
    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            All assigned memory is visible
        WARNING:
        FAIL:
            Not all assigned memory is visible
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sys-22-all-ram-visible
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-22-all-ram-visible'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        [string]  $query1 = 'SELECT TotalPhysicalMemory FROM Win32_ComputerSystem'
        [double]  $check1 = Get-WmiObject -ComputerName $serverName -Query $query1 -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty TotalPhysicalMemory

        [string]  $query2 = 'SELECT Capacity FROM Win32_PhysicalMemory'
        [double[]]$check2 = Get-WmiObject -ComputerName $serverName -Query $query2 -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Capacity
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    # Add up all values from Win32_PhysicalMemory 
    [double]$ramTotal = 0
    ForEach ($ram In $check2) { $ramTotal += $ram }

    # Get 5% range for system memory
    [double]$lowerRange = $check1 - (($check1 / 100) * 5)
    [double]$upperRange = $check1 + (($check1 / 100) * 5)

    If (($ramTotal -gt $lowerRange) -and ($ramTotal -lt $upperRange))
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'All assigned memory is visible'
        $result.data    = ('Installed: {0}gb' -f ($ramTotal / 1GB).ToString('0.00'))
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Not all assigned memory is visible'
        $result.data    = ('Installed: {0}gb,#Visible: {1}gb' -f ($ramTotal / 1GB).ToString('0.00'), ($check1 / 1GB).ToString('0.00'))

        [string]$queryOS = 'SELECT Caption FROM Win32_OperatingSystem'
        [string]$checkOS = Get-WmiObject -ComputerName $serverName -Query $queryOS -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Caption
        If ($checkOS -like '*2008 R2 Standard*') { If (($check1 / 1GB) -eq 32) { $result.data += (',#{0} has a memory limit of only 32gb.' -f $checkOS.Trim()) } }
    }

    Return $result
}
