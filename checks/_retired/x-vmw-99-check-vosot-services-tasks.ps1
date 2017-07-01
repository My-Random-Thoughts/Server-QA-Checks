<#
    DESCRIPTION: 
        Checks against a specified VMware OS Optimisation Template.  Services and scheduled task setting specific checks only.
        !nNote: This is an experimental check

    REQUIRED-INPUTS:
        vosotXmlFile - Local path to the confoguration XML file for VMware OSOT|File

    DEFAULT-VALUES:
        vosotXmlFile = 'C:\ProgramData\VMware\OSOT\VMware Templates\636014.xml'

    DEFAULT-STATE:
        Skip

    RESULTS:
        PASS:
            All mandatory and recommended settings configured
        WARNING:
            All mandatory settings configured, recommended settings not configured
        FAIL:
            All mandatory and recommended settings not configured
        MANUAL:  
        NA:
            Not a virtual machine
            XML check file not applicable for this server

    APPLIES:
        Virtual Servers

    REQUIRED-FUNCTIONS:
        Check-VMware
#>

Function c-vmw-99-check-vosot-services-tasks
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-vmw-99-check-vosot-services-tasks'

    #... CHECK STARTS HERE ...#

    If ((Check-VMware $serverName) -eq $true)
    {
        Try
        {
            [int]$total_M = 0; [int]$count_M = 0    # Mandatory
            [int]$total_R = 0; [int]$count_R = 0    # Recommended
            [int]$total_O = 0; [int]$count_O = 0    # Optional

            # Load the XML
            [xml]$xml = New-Object System.Xml.XmlDataDocument
            If ((Test-Path -Path $script:appSettings['vosotXmlFile']) -eq $false) { Throw "Required XML file '$($script:appSettings['vosotXmlFile'])' missing" }
            Try { $xml.LoadXml($(Get-Content -Path $script:appSettings['vosotXmlFile'])) } Catch { Throw 'There was a problem loading the XML' }

            # Get current OS type
            [string[]]$osType  = ('Microsoft', 'Standard', 'Professional', 'Enterprise')
            [string]  $query   = "SELECT Caption, OSArchitecture, Version, ProductType FROM Win32_OperatingSystem"
            [object]  $osCheck = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object Caption, OSArchitecture, Version, ProductType
            $osType | ForEach { $osCheck.Caption = (($osCheck.Caption).Replace($_, '')).Trim() }

            # Compare current OS against the template allowed list
            [boolean] $runAgainst = $false
            [string[]]$runOnOS    = ($xml.sequence.runOnOs).Split(',')
            ForEach ($osEntry In ($xml.sequence.globalVarList.osCollection.osEntry))
            {
                If ($osEntry.ProductType -eq $osCheck.ProductType) { If ($runOnOS -contains $osEntry.osId) { $runAgainst = $true }
                Else { ForEach ($osSubEntry In $osEntry.osEntry) { If ($osSubEntry.OSArchitecture -eq $osCheck.OSArchitecture) { If ($runOnOS -contains $osSubEntry.osId) { $runAgainst = $true } } } } }
            }
            If ($runAgainst -eq $false) { Throw 'The specified XML file is not suitable for this OS version/type' }
            [string]$logFileName = "$serverName-vOSOT-Services-Tasks.log"

            If ((Test-Path -Path ('{0}OSOT'     -f $resultPath              )) -eq $false) { Try { New-Item    -Path ('{0}OSOT'     -f $resultPath              ) -ItemType Directory -Force | Out-Null } Catch {} }
            If ((Test-Path -Path ('{0}OSOT\{1}' -f $resultPath, $logFileName)) -eq $true)  { Try { Remove-Item -Path ('{0}OSOT\{1}' -f $resultPath, $logFileName)                     -Force | Out-Null } Catch {} }

            # Pre-load services and scheduled tasks
            [string]  $query    = "SELECT Name, Caption, StartMode FROM Win32_Service"
            [object[]]$service  = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object Name, Caption, StartMode
            [object]  $schedule = New-Object -ComObject('Schedule.Service'); $schedule.Connect($serverName)
            [object[]]$tasks    = Get-Tasks($schedule.GetFolder('\'))

            # Start master loop
            [boolean]$return = $false
            ForEach ($step In ($xml.GetElementsByTagName('step')))
            {
                Log-Output "$($($step.category).ToUpper().PadRight(12)): $($step.Name)"
                $return = $false

                If (($($step.action.type) -eq 'Service') -or ($($step.action.type) -eq 'SchTasks'))
                {
                    Switch ($($step.action.type))
                    {
                        'Service'      { $return = Check-Service  -Action ($step.action) -ServiceList $service }
                        'SchTasks'     { $return = Check-SchTasks -Action ($step.action) -TaskList    $tasks   }
                    }
                    
                    Switch ($($step.category))
                    {
                        'Mandatory'   { $total_M++; If ($return -eq $true) { $count_M++ } }
                        'Recommended' { $total_R++; If ($return -eq $true) { $count_R++ } }
                        'Optional'    { $total_O++; If ($return -eq $true) { $count_O++ } }
                    }
                }
            }

            # Compile the results
            If (($count_M -eq $total_M) -and ($count_R -eq $total_R)) { $result.result = $script:lang['Pass']   ; $result.message = 'All mandatory and recommended settings are correct' }
            If (($count_M -eq $total_M) -and ($count_R -ne $total_R)) { $result.result = $script:lang['Warning']; $result.message = 'One or more recommended settings are incorrect'     }
            If (($count_M -ne $total_M)                             ) { $result.result = $script:lang['Fail']   ; $result.message = 'One or more mandatory settings are incorrect'       }

            $result.data = ('Mandatory: {0}/{1},#Recommended: {2}/{3},#Optional: {4}/{5}' -f $count_M, $total_M, $count_R, $total_R, $count_O, $total_O)
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
        $result.message = 'Not a virtual machine'
    }

    Return $result
}

Function Log-Output ([string]$LogString)
{
    $LogString | Out-File -FilePath ('{0}OSOT\{1}-vOSOT-Services-Tasks.log' -f $resultPath, $serverName.ToUpper()) -Encoding ascii -Append
}

Function Get-Tasks
{
    Param ( [Object]$taskFolder )
    $tasks = $taskFolder.GetTasks(0)
    $tasks | ForEach-Object { $_ }
    Try {
        $taskFolders = $taskFolder.GetFolders(0)
        $taskFolders | ForEach-Object { Get-Tasks $_ $true } }
    Catch { }
}

Function Check-Service
{
    Param ([System.Xml.XmlElement]$Action, [object[]]$ServiceList)
    Try
    {
        [boolean]$found       = $false
        [boolean]$func_return = $false
        $ServiceList | ForEach {
            If (($_.Name -eq $($Action.params.serviceName)) -and ($($_.StartMode) -ne $($Action.params.startMode))) { $func_return = $false; $found = $true; Break }
        }

        # Return TRUE if the service is not found
        If ($found -eq $true)
        {
            If ($func_return -eq $false) { Log-Output "   Service should be: $($Action.params.startMode)" }
            Return $func_return
        }
        Else { Return $true }
    }
    Catch { Return $false }
}

Function Check-SchTasks
{
    Param ([System.Xml.XmlElement]$Action, [object[]]$TaskList)
    Try
    {
        [boolean]$found       = $false
        [boolean]$func_return = $false
        $TaskList | ForEach {
            If (($($_.Name) -eq $(Split-Path -Path $($Action.params.taskName) -Leaf)) -and ($(Split-Path -Path $($_.Path) -Parent) -eq "\$(Split-Path -Path $($Action.params.taskName))")) 
            {
                If ($($_.Enabled) -eq $True) { [string]$endis = 'ENABLED' } Else { [string]$endis = 'DISABLED' }
                If ($endis -ne $($Action.params.status)) { $func_return = $false; $found = $true; Break }
            }
        }

        If ($found -eq $true)
        {
            If ($func_return -eq $false) { Log-Output "   Scheduled task should be: '$($Action.params.status)'" }
            Return $func_return
        }
        Else { Return $true }
    }
    Catch { Return $false }
}
