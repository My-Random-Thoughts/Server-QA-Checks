<#
    DESCRIPTION: 
        Ensure all drives types are set to BASIC and with a partition style of MBR.

    REQUIRED-INPUTS:
        IgnoreOffline - "True|False" - Ignore any drives that are marked as offline

    DEFAULT-VALUES:
        IgnoreOffline = 'True'

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            All drive types are BASIC, with partition styles of MBR
        WARNING:
        FAIL:
            One or more partition styles are not MBR
            One or more drives types are not BASIC
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-drv-09-partition-type
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-drv-09-partition-type'
 
    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT Name, Type FROM Win32_DiskPartition WHERE (NOT Type = "Installable File System")'
        [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object Name, Type
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If (([string]::IsNullOrEmpty($check) -eq $false) -and ($check.Count -gt 0))
    {
        [int]$gptA = 0; [int]$gptB = 0; [int]$gptC = 0; [array]$data = @()
        ForEach ($part In $check)
        {
            If (($part.Type).StartsWith('GPT: Basic'))   {                                                         $gptA++; $data += ($($part.Name).Split(',')[0])   }    # BASIC   + GPT
            If (($part.Type).StartsWith('GPT: Logical')) {                                                         $gptC++; $data += ($($part.Name).Split(',')[0])   }    # DYNAMIC + GPT
            If (($part.Type).StartsWith('Logical'))      {                                                         $gptB++; $data += ($($part.Name).Split(',')[0])   }    # DYNAMIC + MBR
            If (($part.Type).StartsWith('GPT: Unknown')) { If ($script:appSettings['IgnoreOffline'] -eq 'False') { $gptD++; $data += ($($part.Name).Split(',')[0]) } }    # OFFLINE + GPT
        }

        $result.result  = $script:lang['Fail']
        $result.data    = (($data | Select-Object -Unique) -join ', ')

        If (($gptA -gt 0) -or ($gptC -gt 0)) { $result.message += 'One or more partition styles are not MBR,#' }
        If (($gptB -gt 0) -or ($gptC -gt 0)) { $result.message += 'One or more drives types are not BASIC,#'   }
        If  ($gptD -gt 0)                    { $result.message += 'One of more drives are unknown'             }

        If ($script:appSettings['IgnoreOffline'] -eq 'True') { $result.message += 'Ignoring unknown drive types' }
    }
    Else
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'All drive types are BASIC, with partition styles of MBR'
        $result.data    = $_.Exception.Message
    }

    Return $result
}
