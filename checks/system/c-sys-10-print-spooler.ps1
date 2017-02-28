<#
    DESCRIPTION: 
        Check to see if any printers exist on the server. If printers exist, ensure the spooler directory is not stored on the system drive.

    REQUIRED-INPUTS:
        IgnoreThesePrinterNames - List of known printer names to ignore

    DEFAULT-VALUES:
        IgnoreThesePrinterNames = ('Send To OneNote', 'PDFCreator', 'Microsoft XPS Document Writer', 'Fax', 'WebEx Document Loader', 'Microsoft Print To PDF')

    RESULTS:
        PASS:
            Printers found, and spool directory is not set to default path
        WARNING:
        FAIL:
            Spool directory is set to the default path and needs to be changed, Registry setting not found
        MANUAL:
        NA:
            No printers found
            Print Spooler service is not running

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sys-10-print-spooler
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-10-print-spooler'

    #... CHECK STARTS HERE ...#

    Try
    {
        $svc = Get-Service -DisplayName 'Print Spooler' | Select-Object -ExpandProperty Status
        If ($svc -eq 'Running')
        {
            [string]$query = 'SELECT Name FROM Win32_Printer WHERE NOT Name="null"'
            $script:appSettings['IgnoreThesePrinterNames'] | ForEach { $query += ' AND NOT Name="{0}"' -f $_ }
            [array]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Name
        }
        Else
        {
            [array]$check = 'STOPPED'
        }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($check -eq 'STOPPED')
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Print Spooler service is not running'
    }
    ElseIf (($check -ne $null) -and ($check.Count -gt 0))
    {
        $check | ForEach { $result.data += '{0},#' -f $_ }        

        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\Print\Printers')
        If ($regKey) { $keyVal = $regKey.GetValue('DefaultSpoolDirectory') }
        Try { $regKey.Close() } Catch { }
        $reg.Close()

        If ([string]::IsNullOrEmpty($keyVal) -eq $false)
        {
            If ($keyVal -eq $("$env:SystemDrive\Windows\system32\spool\PRINTERS"))
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'Spool directory is set to the default path and needs to be changed'
                $result.data    = 'Location: {0},#{1}' -f $keyVal, $result.data
            }
            Else 
            {
                $result.result  = $script:lang['Pass']
                $result.message = 'Printers found, and spool directory is not set to default path'
                $result.data    = 'Location: {0},#{1}' -f $keyVal, $result.data
            }
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Registry setting not found'
            $result.data    = ''
        }
    }
    Else
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'No printers found'
    }

    Return $result
}