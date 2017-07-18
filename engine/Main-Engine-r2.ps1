Function Show-HelpScreen
{
    Clear-Host
    Write-Header -Message $($script:lang['Help_01']) -Width $script:screenwidth
    Write-Host ' '$($script:lang['Help_02'])                                               -ForegroundColor Cyan
    Write-Colr '    QA.ps1 [-ComputerName] ','server01','[, server02, server03, ...]'      -Colour          Yellow, Yellow, Gray, Yellow, Gray
    Write-Colr '    QA.ps1 [-ComputerName] ','(Get-Content -Path x:\path\list.txt)'        -Colour          Yellow, Yellow, Gray, Yellow
    Write-Host ''
    Write-Host ''
    Write-Host ' '$($script:lang['Help_03'])                                               -ForegroundColor Cyan
    Write-Host '   '$($script:lang['Help_04'])                                             -ForegroundColor Cyan
    Write-Colr '      ', $($script:lang['Help_05'])                                        -Colour          Cyan, White
    Write-Colr '        QA.ps1 [-ComputerName] ','.'                                       -Colour          Yellow, Yellow, Gray, Yellow
    Write-Colr '        QA.ps1 [-ComputerName] ','server01'                                -Colour          Yellow, Yellow, Gray, Yellow
    Write-Host ''
    Write-Host '   '$($script:lang['Help_06'])                                             -ForegroundColor Cyan
    Write-Colr '      ', $($script:lang['Help_07'])                                        -Colour          Cyan, White
    Write-Colr '        QA.ps1 [-ComputerName] ','server01, server02, server03, ...'       -Colour          Yellow, Yellow, Gray, Yellow
    Write-Host ''
    Write-Colr '      ', $($script:lang['Help_08'])                                        -Colour          Cyan, White
    Write-Colr '        QA.ps1 [-ComputerName] ','(Get-Content -Path x:\path\list.txt)'    -Colour          Yellow, Yellow, Gray, Yellow
    Write-Host ''
    Write-Host ' '$script:lang['Help_09']                                                  -ForegroundColor Cyan

    [int]$iCnt = 10
    Do {
        If ([string]::IsNullOrEmpty($script:lang["Help_$iCnt"]) -eq $false) { Write-Host '   '$script:lang["Help_$iCnt"] -ForegroundColor White }
        $iCnt++
    } While ($iCnt -lt 20)

    Write-Host (DivLine -Width $script:screenwidth)                                        -ForegroundColor Yellow
    Write-Host ''
    Exit
}

###################################################################################################

Function Check-CommandLine
{
    If (Test-Path variable:help) { If ($Help -eq $true)
    {
        Show-HelpScreen
        Exit 
    } }

    # Resize window to be 120 wide and keep the height.
    # Also change the buffer size to be huge
    $gh = Get-Host
    $ws = $gh.UI.RawUI.WindowSize
    $wh = $ws.Height
    If ($ws.Width -le 120)
    {
        $ws.Height = 9999
        $ws.Width  =  120; $gh.UI.RawUI.Set_BufferSize($ws)
        $ws.Height =  $wh; $gh.UI.RawUI.Set_WindowSize($ws)
    }
    $script:screenwidth = ($ws.Width - 2)

    Clear-Host
    Write-Header -Message $script:lang['Header'] -Width $script:screenwidth

    [array]$serverFilter = @()
    If (Test-Path variable:ComputerName) { If ($ComputerName -ne $null) { $ComputerName | ForEach { If ($_.Length -gt 0) { $script:servers += $_.Trim() } } } }
    $script:servers | ForEach {
        If ($_ -eq '.') { $serverFilter += ${env:ComputerName}.ToLower() }
        Else { If ($_.Trim() -eq '-ComputerName') { $_ = '' }; If ($_.Trim().Length -gt 2) { $serverFilter += $_.Trim().ToLower() } }
    }
    $script:servers = ($serverFilter | Select-Object -Unique | Sort-Object)
    If ([string]::IsNullOrEmpty($script:servers) -eq $true) { Show-HelpScreen; Exit }

    # Check admin status
    If (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Host ('  {0}' -f $script:lang['Admin-Warn_1']) -ForegroundColor Red
        Write-Host ('  {0}' -f $script:lang['Admin-Warn_2']) -ForegroundColor Red
        Write-Host ('')
        Break
    }
}

Function Start-QAProcess
{
    # Verbose information output
    [boolean]$verbose = ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose'))
    [boolean]$debug   = ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('DoNotPing'))
    If ($verbose -eq $true) { $script:ccTasks = 1 }

    # Write job information
    [int]$count = $script:qaChecks.Count
    Write-Host ($('  {0}' -f $script:lang['Scan-Head_1']) -f $count, $script:ccTasks) -ForegroundColor White
    Write-Host ($('  {0}' -f $script:lang['Scan-Head_2']) -f $script:checkTimeout   ) -ForegroundColor White

    # Progress bar legend
    Write-Host  " "
    Write-Host ("   $M $($script:lang['Passed'])")         -NoNewline -ForegroundColor Green; Write-Host ("   $M $($script:lang['Warning'])") -NoNewline -ForegroundColor Yellow
    Write-Host ("   $M $($script:lang['Failed'])")         -NoNewline -ForegroundColor Red  ; Write-Host ("   $M $($script:lang['Manual'])")  -NoNewline -ForegroundColor Cyan
    Write-Host ("   $M $($script:lang['Not-Applicable'])") -NoNewline -ForegroundColor Gray ; Write-Host ("   $M $($script:lang['Error'])")              -ForegroundColor Magenta
    Write-Host (DivLine -Width $script:screenwidth)                   -ForegroundColor Yellow

    [string]$ServerCounts = ''
    [string]$DebugMessage = ''
    If ($script:servers.Count -gt 1) { $ServerCounts = '  '+($($script:lang['ServerCount']) -f $($script:servers.Count)) }
    If ($debug -eq $true)            { $DebugMessage = 'Debug Mode - Ignoring Server Connection Checks'                  }

    If (($ServerCounts -ne '') -or ($DebugMessage -ne ''))
    {
        Write-Host ('{0}{1}' -f $ServerCounts, $DebugMessage.PadLeft($script:screenwidth - $ServerCounts.Length)) -ForegroundColor White
        Write-Host (DivLine -Width $script:screenwidth)                                                           -ForegroundColor Yellow
    }

    # Create required output folders
    New-Item -ItemType Directory -Force -Path ($script:qaOutput) | Out-Null
    If ($verbose -eq $true) { $pBlock = $M } Else { $pBlock = $T }
    If ($GenerateCSV -eq $true) { If (Test-Path -Path ($script:qaOutput + 'QA_Results.csv')) { Try { Remove-Item ($script:qaOutput + 'QA_Results.csv') -Force } Catch {} } }
    If ($GenerateXML -eq $true) { If (Test-Path -Path ($script:qaOutput + 'QA_Results.xml')) { Try { Remove-Item ($script:qaOutput + 'QA_Results.xml') -Force } Catch {} } }

    # Master job loop
    [int]$CurrentServerNumber = 0
    ForEach ($server In $script:servers)
    {
        $CurrentServerNumber++
        [array]$serverresults = @()
        [int]   $Padding      = ($script:servers.Count -as [string]).Length
        [string]$CurrentCount = ('({0}/{1})' -f $CurrentServerNumber.ToString().PadLeft($Padding), ($script:servers.Count))
        Write-Host ''
        Write-Colr '  ', $server.PadRight($script:screenwidth - $CurrentCount.Length - 2), $CurrentCount -Colour White, White, Yellow
        Write-Host '   ' -NoNewline

        # Make sure the computer is reachable
        If (($debug -eq $true) -or ((Test-Connection -ComputerName $server -Quiet -Count 1) -eq $true))
        {
            # Use the Check-Port function to make sure that the RPC port is listening
            If (($debug -eq $true) -or ((Check-Port -ServerName $server -Port 135) -eq $true))
            {
                If ($verbose -eq $true) { Write-Host $script:lang['Verbose-Info'] -ForegroundColor Yellow -NoNewline }
                Else {
                    For ([int]$i = 0; $i -lt $count; $i++) { Write-Host $B -ForegroundColor DarkGray -NoNewline }
                    Write-Host ''
                    Write-Host '   ' -ForegroundColor DarkGray -NoNewline
                }

                # RPC Connected, loop through the checks and start a job
                [array]    $jobs         = $script:qaChecks
                [int]      $jobIndex     = 0         # Which job is up for running
                [hashtable]$workItems    = @{ }      # Items being worked on
                [hashtable]$jobtimer     = @{ }      # Timers for jobs
                [boolean]  $workComplete = $false    # Is the script done with what it needs to do?

                While (-not $workComplete)
                {
                    # Process any finished jobs.
                    ForEach ($key In @() + $workItems.Keys)
                    {
                        # Time in seconds current job has been running for
                        [int]$elapsed = $jobtimer.Get_Item($workItems[$key].Name).Elapsed.TotalSeconds

                        # Process succesful jobs
                        If ($workItems[$key].State -eq 'Completed')
                        {
                            # $key is done.
                            [PSObject]$result = Receive-Job $workItems[$key]
                            If ($result -ne $null)
                            {
                                # add to results
                                $script:results += $result
                                $serverresults  += $result

                                # provide some pretty output on the console
                                Switch ($result.result)
                                {
                                    $script:lang['Pass']           { Write-Host $pBlock -ForegroundColor Green  -NoNewline; Break }
                                    $script:lang['Warning']        { Write-Host $pBlock -ForegroundColor Yellow -NoNewline; Break }
                                    $script:lang['Fail']           { Write-Host $pBlock -ForegroundColor Red    -NoNewline; Break }
                                    $script:lang['Manual']         { Write-Host $pBlock -ForegroundColor Cyan   -NoNewline; Break }
                                    $script:lang['Not-Applicable'] { Write-Host $pBlock -ForegroundColor Gray   -NoNewline; Break }
                                    $script:lang['Error']          { If ($result.data -like '*Access is denied*') {
                                                                         If ($workComplete -eq $false) {
                                                                             $result.message = $script:lang['AD-Message']    # ACCESS DENIED
                                                                             $script:failurecount++
                                                                             Write-Host ("$M " + $script:lang['AD-Write-Host']) -ForegroundColor Magenta -NoNewline
                                                                             $workComplete = $true } }
                                                                     Else { If ($workComplete -eq $false) { Write-Host $F -ForegroundColor Magenta -NoNewline } }
                                                                   }
                                    Default                        { Write-Host $F -ForegroundColor DarkGray -NoNewline; Break }
                                }
                            }
                            Else
                            {
                                # Job returned no data
                                $result          = newResult
                                $result.server   = $server
                                $result.name     = $workItems[$key].Name
                                $result.check    = $workItems[$key].Name
                                $result.result   = 'Error'
                                $result.message  = $script:lang['ND-Message']    # NO DATA
                                $result.data     = $script:lang['ND-Message']
                                $script:results += $result
                                $serverresults  += $result
                                Write-Host $F -ForegroundColor Magenta -NoNewline
                            }
                            $workItems.Remove($key)
                        
                        # Job failed or server disconnected
                        }
                        ElseIf (($workItems[$key].State -eq 'Failed') -or ($workItems[$key].State -eq 'Disconnected'))
                        {
                            $result          = newResult
                            $result.server   = $server
                            $result.name     = $workItems[$key].Name
                            $result.check    = $workItems[$key].Name
                            $result.result   = 'Error'
                            $result.message  = $script:lang['FD-Message']    # FAILED / DISCONNECTED
                            $result.data     = $script:lang['FD-Message']
                            $script:results += $result
                            $serverresults  += $result
                            Write-Host ("$M " + $script:lang['FD-Write-Host']) -ForegroundColor Magenta -NoNewline
                            $workItems.Remove($key)
                            $script:failurecount++
                            $workComplete = $true
                        }

                        # Check for timed out jobs and kill them
                        If ($workItems[$key])
                        {
                            If ($workItems[$key].State -eq 'Running' -and ($elapsed -ge $script:checkTimeout))
                            {
                                $result          = newResult
                                $result.server   = $server
                                $result.name     = $workItems[$key].Name
                                $result.check    = $workItems[$key].Name
                                $result.result   = 'Error'
                                $result.message  = $script:lang['TO-Message']    # TIMEOUT
                                $result.data     = $script:lang['TO-Message']
                                $script:results += $result
                                $serverresults  += $result
                                Try { Stop-Job -Job $workItems[$key]; Remove-Job -Job $workItems[$key] } Catch { }
                                Write-Host $F -ForegroundColor Magenta -NoNewline
                                $workItems.Remove($key)
                            }
                        }
                    }

                    # Start new jobs if there are open slots.
                    While (($workItems.Count -lt $script:ccTasks) -and ($jobIndex -lt $jobs.Length))
                    {
                        [string]$job             = ($jobs[$jobIndex].Substring(0, 8).Replace('-',''))  # c-xyz-01-gold-build --> cxyz01
                        [int]   $jobOn           =  $jobIndex + 1                                      # f-xyz-01-gold-build --> fxyz01
                        [int]   $numJobs         =  $jobs.Count
                        [string]$funcName        =  $jobs[$jobIndex]
                        [object]$initScript      =  Invoke-Expression "`$$job"

                        If ($verbose -eq $true)
                        {
                            Write-Host ''
                            Write-Host '   '$jobs[$jobIndex].ToString().PadRight($script:screenwidth - 9, '.')': ' -ForegroundColor Gray -NoNewline
                        }

                        # Run the required job...
                        $workItems[$job] = Start-Job -InitializationScript $initScript -ArgumentList $funcName, $server, $script:qaOutput `
                                                     -ScriptBlock { Invoke-Expression  -Command "$args[0] $args[1] $args[2]" } -Name $funcName

                        $stopWatch = [System.Diagnostics.StopWatch]::StartNew()
                        $jobtimer.Add($funcName, $stopWatch)
                        $jobIndex += 1
                    }

                    # If all jobs have been processed we are done - next server.
                    If ($jobIndex -eq $jobs.Length -and $workItems.Count -eq 0) { $workComplete = $true }
                
                    # Wait between status checks
                    Start-Sleep -Milliseconds $waitTime
                }
            }
            Else
            {
                # RPC not responding / erroring, unable to ping server
                $result          = newResult
                $result.server   = $server
                $result.name     = 'X'
                $result.check    = 'X'
                $result.result   = 'Error'
                $result.message  = $script:lang['RPC-Message']    # RPC FAILURE
                $script:results += $result
                $serverresults  += $result
                $script:failurecount++
                Write-Host ("$M " + $script:lang['RPC-Write-Host']) -ForegroundColor Magenta -NoNewline
            }
        }
        Else
        {
            # Unable to connect
            $result          = newResult
            $result.server   = $server
            $result.name     = 'X'
            $result.check    = 'X'
            $result.result   = 'Error'
            $result.message  = $script:lang['CF-Message']    # CONNECTION FAILURE
            $script:results += $result
            $serverresults  += $result
            $script:failurecount++
            Write-Host ("$M " + $script:lang['CF-Write-Host']) -ForegroundColor Magenta -NoNewline
        }

        Write-Host ''
        $origpos = $host.UI.RawUI.CursorPosition                                                # Set cursor position
        Write-Host '   Saving Check Results...' -ForegroundColor White -NoNewline               # and display message
        Export-Results -ResultsInput $serverresults -CurrentServerNumber $CurrentServerNumber
        $host.UI.RawUI.CursorPosition = $origpos; Write-Host ''.PadRight(30, ' ') -NoNewline    # then clear message

        # Show results counts
        $resultsplit = Get-ResultsSplit -serverName $server
        [int]$padding = ($script:qaChecks).Count - 19 - 30    # 19:??; 30:Message clearing above
        If ($padding -lt     3) { $padding = 3 }
        If ($verbose -eq $true) { $padding = ($script:screenwidth - 23) }    # 23: Length of results counters + 1
        Write-Colr ''.PadLeft($padding), $resultsplit.p.PadLeft(2), ', ', $resultsplit.w.PadLeft(2), ', ', $resultsplit.f.PadLeft(2), ', ', `
                                         $resultsplit.m.PadLeft(2), ', ', $resultsplit.n.PadLeft(2), ', ', $resultsplit.e.PadLeft(2) `
                     -Colour White, Green, White, Yellow, White, Red, White, Cyan, White, Gray, White, Magenta
    }
}

Function Get-ResultsSplit
{
    Param ( [string]$serverName )
    [string]$p = @($script:results | Where-Object  { $_.result -eq $script:lang['Pass']           -and $_.server -like $serverName }).Count.ToString()
    [string]$w = @($script:results | Where-Object  { $_.result -eq $script:lang['Warning']        -and $_.server -like $serverName }).Count.ToString()
    [string]$f = @($script:results | Where-Object  { $_.result -eq $script:lang['Fail']           -and $_.server -like $serverName }).Count.ToString()
    [string]$m = @($script:results | Where-Object  { $_.result -eq $script:lang['Manual']         -and $_.server -like $serverName }).Count.ToString()
    [string]$n = @($script:results | Where-Object  { $_.result -eq $script:lang['Not-Applicable'] -and $_.server -like $serverName }).Count.ToString()
    [string]$e = @($script:results | Where-Object  { $_.result -eq $script:lang['Error']          -and $_.server -like $serverName }).Count.ToString()

    [PSObject]$resultsplit = New-Object -TypeName PSObject -Property @{ 'p'=$p; 'w'=$w; 'f'=$f; 'm'=$m; 'n'=$n; 'e'=$e; }
    Return $resultsplit
}

Function Show-Results
{
    [string]$y = $script:failurecount
    [string]$x = (@($script:servers).Count - $y)
    $resultsplit = Get-ResultsSplit -serverName '*'
    [int]$w = $script:screenwidth - 2
    Write-Host ''
    Write-Host (DivLine -Width $script:screenwidth) -ForegroundColor Yellow

    [int]$rightPad = (($script:lang['Passed']).Length)
    If ((($script:lang['Warning']       ).Length) -gt $rightPad) { $rightPad = (($script:lang['Warning']       ).Length) }
    If ((($script:lang['Failed']        ).Length) -gt $rightPad) { $rightPad = (($script:lang['Failed']        ).Length) }
    If ((($script:lang['Manual']        ).Length) -gt $rightPad) { $rightPad = (($script:lang['Manual']        ).Length) }
    If ((($script:lang['Not-Applicable']).Length) -gt $rightPad) { $rightPad = (($script:lang['Not-Applicable']).Length) }
    If ((($script:lang['Error']         ).Length) -gt $rightPad) { $rightPad = (($script:lang['Error']         ).Length) }

    If ((($script:lang['Checked']).Length) -gt (($script:lang['Skipped']).Length)) { [int]$leftPad = (($script:lang['Checked']).Length) } Else { [int]$leftPad = (($script:lang['Skipped']).Length) }

    Write-Host ('  {0}{1}' -f ($script:lang['TotalCount_1']), (($script:lang['TotalCount_2']).PadLeft($w - (($script:lang['TotalCount_2']).Length)))) -ForegroundColor White
    Write-Host ('    {0}: {1}{2}:{3}' -f ($script:lang['Checked']).PadLeft($leftPad), $x.PadLeft(3), ($script:lang['Passed']        ).PadLeft($w - $rightPad - $leftPad - 7), ($resultsplit.p).PadLeft(4)) -ForegroundColor Green
    Write-Host ('    {0}: {1}{2}:{3}' -f ($script:lang['Skipped']).PadLeft($leftPad), $y.PadLeft(3), ($script:lang['Warning']       ).PadLeft($w - $rightPad - $leftPad - 7), ($resultsplit.w).PadLeft(4)) -ForegroundColor Yellow
    Write-Host (            '{0}:{1}' -f                                                             ($script:lang['Failed']        ).PadLeft($w - $rightPad            + 2), ($resultsplit.f).PadLeft(4)) -ForegroundColor Red
    Write-Host (            '{0}:{1}' -f                                                             ($script:lang['Manual']        ).PadLeft($w - $rightPad            + 2), ($resultsplit.m).PadLeft(4)) -ForegroundColor Cyan
    Write-Host (            '{0}:{1}' -f                                                             ($script:lang['Not-Applicable']).PadLeft($w - $rightPad            + 2), ($resultsplit.n).PadLeft(4)) -ForegroundColor Gray
    Write-Host (            '{0}:{1}' -f                                                             ($script:lang['Error']         ).PadLeft($w - $rightPad            + 2), ($resultsplit.e).PadLeft(4)) -ForegroundColor Magenta

    Write-Host (DivLine -Width $script:screenwidth) -ForegroundColor Yellow
}

Function Export-Results
{
    Param ( [array]$ResultsInput, [int]$CurrentServerNumber )
    [string]$html = @'
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
    <meta charset="utf-8">
    <title>QA Report</title>
    <style>
        @charset UTF-8;
        html body { font-family: Segoe UI, Verdana, Geneva, sans-serif; font-size: 12px; height: 100%; overflow: auto; color: #000; }
        .header1  { width: 99%; margin: 0px 10px 0px auto; }
        .header2  { width: 99%; margin: 0px 10px 0px auto; padding-top: 10px; clear: both; min-height: 80px; }

        .header1 > .headerCompany { float: left;  font-size: 266%; font-weight: bold; }
        .header1 > .headerQA      { float: left;  font-size: 266%; }
        .header1 > .headerDetails { float: right; font-size: 100%; text-align: right;  }
        .header1 > .headerDetails > .item { display:block; padding: 0 0 3px 0; }

        .header2 > .headerServer { float: left; font-size: 366%; font-weight: normal; line-height: 77px; text-transform: uppercase; }

        .header2 > .summary { float:right; background: #f8f8f8; height: 77px; width: 682px; padding-top: 10px; border-right: 1px solid #ccc; border-bottom: 1px solid #ccc; }

        .header2 > .summary > .summaryBox { float: left; height: 65px; width: 100px; text-align: center; margin-left: 10px; padding: 0px; border: 1px solid #000; }
        .header2 > .summary > .summaryBox > .code { font-size: 133%; padding-top: 5px; display: block; font-weight: bold; }
        .header2 > .summary > .summaryBox > .num  { font-size: 233%; }

        .sectionTitle    { padding: 5px; font-size: 233%; text-align: center; letter-spacing: 3px; display: block; }
        .sectionItem     { background: #707070; color: #ffffff; width: 99%; display: block; margin: 25px auto  5px auto; padding: 0; overflow: auto; }
        .checkItem       { background: #f8f8f8;                 width: 97%; display: block; margin: 10px auto 10px auto; padding: 0; overflow: auto; border-right: 1px solid #ccc; border-bottom: 1px solid #ccc; }
        .checkItem:hover { background: #f2f2f2; }

        .boxContainer { float: left; width: 80px; height: 77px; }
        .boxContainer > .check { position: relative; top: 0; left: 0; height: 65px; width: 100px; text-align: center; margin: 5px 0px 5px 5px; padding: 0px; border: 1px solid #fff; }
        .boxContainer > .check > .code { font-size: 133%; padding-top: 5px; font-weight: bold; display: block; }
        .boxContainer > .check > .num { font-size: 233%; }

        .contentContainer { margin-left: 100px; padding: 10px 10px 10px 15px; overflow: auto; }
        .checkContainer  { float: left; width: 45%; }
        .checkContainer  > .name { margin: 0 0 5px 0; font-weight: bold; font-size: 125%; }
        .resultContainer { float: left; width: 50%; }
        .resultContainer > .data > .dataHeader { font-weight: bold; margin-bottom: 5px; }
       
        .note                { text-decoration: none; }
        .note div.help       { display: none; }
        .note:hover          { cursor: help; position: relative; }
        .note:hover div.help { background: #ffffdd; border: #000000 3px solid; display: block; right: 10px; margin: 10px; padding: 15px; position: fixed; text-align: left; text-decoration: none; top: 10px; width: 600px; z-index: 100; }
        .note li             { display: table-row-group; list-style: none; }
        .note li span        { display: table-cell; vertical-align: top; padding: 3px 0; }
        .note li span:first-child { text-align: right; min-width: 120px; max-width: 120px; font-weight: bold; padding-right: 7px; }
        .note li span:last-child  { padding-left: 7px; border-left: 1px solid #000000; }

        .p { background: #b3ffb3 !important; }
        .w { background: #ffffb3 !important; }
        .f { background: #ffb3b3 !important; }
        .m { background: #b3b3ff !important; }
        .n { background: #e2e2e2 !important; }
        .e { background: #c80000 !important; color: #ffffff!important; }
    </style>
</head>
<body>
BODY_GOES_HERE
</body>
</html>
'@

    If ($SkipHTMLHelp -eq $true) { $html = $html.Replace('cursor: help;', 'cursor: default;') }

    [string]$dt1 = (Get-Date -Format 'yyyy/MM/dd HH:mm')                      # Used for script header information
    [string]$dt2 = $dt1.Replace('/','.').Replace(' ','-').Replace(':','.')    # Used for saving as part of filename : 'yyyy/MM/dd HH:mm'  -->  'yyyy.MM.dd-HH.mm'
    [string]$un  = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.ToLower()

    [string]$server = $ResultsInput[0].server
    $resultsplit = Get-ResultsSplit -serverName $server
    [string]$body = @"
    <div class="header1">
        <span class="headerCompany">$reportCompanyName</span>
        <span class="headerQA"     >&nbsp;$($script:lang['QA-Results'])</span>
        <div class="headerDetails">
            <span class="item">$($script:lang['Script-Version']): <b>$version</b></span>
            <span class="item">$($script:lang['Generated-By']):   <b>$un</b></span>
            <span class="item">$($script:lang['Generated-On']):   <b>$dt1</b></span>
            <span class="item">$($script:lang['Configuration']):  <b>$settingsFile</b></span>
        </div>
    </div>

    <div class="header2">
        <div class="headerServer">$server</div>
        <div class="summary">
            <div class="summaryBox p"><span class="code">$($script:lang['Passed']        )</span><span class="num">$($resultsplit.p)</span></div>
            <div class="summaryBox w"><span class="code">$($script:lang['Warning']       )</span><span class="num">$($resultsplit.w)</span></div>
            <div class="summaryBox f"><span class="code">$($script:lang['Failed']        )</span><span class="num">$($resultsplit.f)</span></div>
            <div class="summaryBox m"><span class="code">$($script:lang['Manual']        )</span><span class="num">$($resultsplit.m)</span></div>
            <div class="summaryBox n"><span class="code">$($script:lang['Not-Applicable'])</span><span class="num">$($resultsplit.n)</span></div>
            <div class="summaryBox e"><span class="code">$($script:lang['Error']         )</span><span class="num">$($resultsplit.e)</span></div>
        </div>
    </div>
    <div style="clear:both;"></div>

"@

    [string]$path = $script:qaOutput + $server + '_' + $dt2 + '.html'

    # Sort the results
    $ResultsInput = ($ResultsInput | Select-Object check, name, result, message, data | Sort-Object check)
    $reportTemplate = @'
    <div class="checkItem"><div class="boxContainer"><div class="check RESULT_COLOUR_CODE HELP_SECTION"><span class="code">SECTION_CODE</span><span class="num">CHECK_NUMBER</span>
    </div></div><div class="contentContainer"><span class="checkContainer"><div class="name row">CHECK_TITLE</div><div class="message row">CHECK_MESSAGE</div></span>
    <span class="resultContainer"><div class="data"><div class="dataHeader">Data</div><div class="dataItem">CHECK_DATA</div></div></span></div></div>
'@
    $reportChanges = ('RESULT_COLOUR_CODE', 'SECTION_CODE', 'CHECK_NUMBER', 'CHECK_TITLE', 'CHECK_MESSAGE', 'CHECK_DATA', 'HELP_SECTION')

    [string]$sectionNew = ''
    [string]$sectionOld = ''

    $ResultsInput | ForEach {
        Try { $sectionNew = ($_.check).Substring(2, 3) } Catch { $sectionNew = '' }
        If ($sectionNew -ne $sectionOld)
        {
            $sectionOld = $sectionNew
            [string]$selctionName = $script:sections[$sectionNew]
            $sectionRow = '<div class="sectionItem"><span class="sectionTitle">{0}</span></div>' -f $selctionName
        }
        Else { $sectionRow = '' }
        $body += $sectionRow

        $addCheck = $reportTemplate
        $addCheck = $addCheck.Replace('SECTION_CODE'  , ($_.check  ).SubString(2,3)        )
        $addCheck = $addCheck.Replace('CHECK_NUMBER'  , ($_.check  ).SubString(6,2)        )
        $addCheck = $addCheck.Replace('CHECK_TITLE'   , ($_.name   )                       )
        $addCheck = $addCheck.Replace('CHECK_MESSAGE' , ($_.message).Replace(',#',',<br/>'))
        If ([string]::IsNullOrEmpty($_.data) -eq $false) { $addCheck = $addCheck.Replace('CHECK_DATA', ($_.data   ).Replace(',#',',<br/>')) }
        Else                                             { $addCheck = $addCheck.Replace('CHECK_DATA', 'None')                              }

        Switch ($_.result)
        {
            $script:lang['Pass']           { $addCheck = $addCheck.Replace('RESULT_COLOUR_CODE',  'p') }
            $script:lang['Warning']        { $addCheck = $addCheck.Replace('RESULT_COLOUR_CODE',  'w') }
            $script:lang['Fail']           { $addCheck = $addCheck.Replace('RESULT_COLOUR_CODE',  'f') }
            $script:lang['Manual']         { $addCheck = $addCheck.Replace('RESULT_COLOUR_CODE',  'm') }
            $script:lang['Not-Applicable'] { $addCheck = $addCheck.Replace('RESULT_COLOUR_CODE',  'n') }
            $script:lang['Error']          { $addCheck = $addCheck.Replace('checkItem', 'checkItem e') }
        }

        If (-not $SkipHTMLHelp) { $addCheck = $addCheck.Replace('HELP_SECTION">', 'note">' + $(Add-HoverHelp -Check $($_.check).SubString(2,6).Replace('-', ''))) }
        Else                    { $addCheck = $addCheck.Replace('HELP_SECTION', '') }

        $body += $addCheck
    }

    $html = $html.Replace('BODY_GOES_HERE', $body)
    $html | Out-File $path -Force -Encoding utf8

    # CSV Output
    If ($GenerateCSV -eq $true)
    {
        [string]$path   =  $script:qaOutput + 'QA_Results.csv'
        [array] $outCSV =  @()
        [array] $cnvCSV = ($ResultsInput | Select-Object server, name, check, datetime, result, message, data | Sort-Object check, server | ConvertTo-Csv -NoTypeInformation)
        If ($CurrentServerNumber -gt 1) { $cnvCSV  = ($cnvCSV | Select-Object -Skip 1) }    # Remove header info for all but first server
        $cnvCSV | ForEach-Object { $outCSV += $_.Replace(',#',', ') }
        $outCSV | Out-File -FilePath $path -Encoding utf8 -Force -Append
    }

    # XML Output
    If ($GenerateXML -eq $true)
    {
        [string]$path = $script:qaOutput + 'QA_Results.xml'
        If ($CurrentServerNumber -eq 1) { '<?xml version="1.0" encoding="utf-8" ?><QAResultsFile></QAResultsFile>' | Out-File -FilePath $path -Encoding utf8 -Force }

        [string]$inXML  = (Get-Content -Path $path)
        [xml]   $cnvXML = ($ResultsInput | Select-Object server, name, check, datetime, result, message, data | Sort-Object check, server | ConvertTo-XML -NoTypeInformation)
        $inXML = $inXML -replace '</QAResultsFile>', "$($cnvXML.Objects.InnerXml)</QAResultsFile>"
        $inXML = $inXML.Replace(',#',', ')
        $inXML | Out-File -FilePath $path -Encoding utf8 -Force
    }
}

###################################################################################################

Function Add-HoverHelp
{
    Param ([string]$Check)
    [string]$help = ''
    If ($script:qahelp[$Check])
    {
        Try
        {
            [xml]$xml  = $script:qahelp[$Check]
                 $help = '<div class="help"><li><span>{0}<br/>{1}</span><span>{2}</span></li><br/>' -f $script:sections[$Check.Substring(0,3)], $check.Substring(3, 2), $xml.xml.description
            If ($xml.xml.ChildNodes.ToString() -like '*pass*'   ) { $help += '<li><span>{0}</span><span>{1}</span></li>' -f $script:lang['Pass'],           ($xml.xml.pass)    }
            If ($xml.xml.ChildNodes.ToString() -like '*warning*') { $help += '<li><span>{0}</span><span>{1}</span></li>' -f $script:lang['Warning'],        ($xml.xml.warning) }
            If ($xml.xml.ChildNodes.ToString() -like '*fail*'   ) { $help += '<li><span>{0}</span><span>{1}</span></li>' -f $script:lang['Fail'],           ($xml.xml.fail)    }
            If ($xml.xml.ChildNodes.ToString() -like '*manual*' ) { $help += '<li><span>{0}</span><span>{1}</span></li>' -f $script:lang['Manual'],         ($xml.xml.manual)  }
            If ($xml.xml.ChildNodes.ToString() -like '*na*'     ) { $help += '<li><span>{0}</span><span>{1}</span></li>' -f $script:lang['Not-Applicable'], ($xml.xml.na)      }
            $help += '<br/><li><span>{0}</span><span>{1}</span></li></div>' -f $script:lang['Applies-To'], ($xml.xml.applies).Replace(', ','<br/>')
            $help = $help.Replace('!n', '<br/>')
        }
        Catch { $help = $($_.Exception.Message) }    # No help if XML is invalid
    }
    Return $help
}

###################################################################################################

Function Check-Port
{
    Param ([string]$ServerName, [string]$Port)
    Try {
        $tcp  = New-Object System.Net.Sockets.TcpClient
        $con  = $tcp.BeginConnect($ServerName, $port, $null, $null)
        $wait = $con.AsyncWaitHandle.WaitOne(3000, $false)

        If (-not $wait) { $tcp.Close(); Return $false }
        Else {
            $failed = $false; $error.Clear()
            Try { $tcp.EndConnect($con) } Catch {}
            If (!$?) { $failed = $true }; $tcp.Close()
            If ($failed -eq $true) { Return $false } Else { Return $true }
    } } Catch { Return $false }
}

[string]$F  = ([char]9608).ToString()    # (Block) Full
[string]$T  = ([char]9600).ToString()    # (Block) Top
[string]$B  = ([char]9604).ToString()    # (Block) Bottom
[string]$M  = ([char]9632).ToString()    # (Block) Middle
[string]$L  = ([char]9472).ToString()    # Horizontal Line (Single)

[string]$TL = ([char]9556).ToString()    # Top Left Corner (Double)
[string]$TR = ([char]9559).ToString()    # Top Right Corner (Double)
[string]$BL = ([char]9562).ToString()    # Bottom Left Corner (Double)
[string]$V  = ([char]9553).ToString()    # Veritcal Line (Double)
[string]$H  = ([char]9552).ToString()    # Horizontal Line (Double)

Function Write-Colr
{
    Param ([String[]]$Text,[ConsoleColor[]]$Colour,[Switch]$NoNewline=$false)
    For ([int]$i = 0; $i -lt $Text.Length; $i++) { Write-Host $Text[$i] -Foreground $Colour[$i] -NoNewLine }
    If ($NoNewline -eq $false) { Write-Host '' }
}

Function Write-Header
{
    Param ([string]$Message,[int]$Width); $underline=''.PadLeft($Width-16,$L)
    $q=("$TL$H$H$H$H$H$H$H$H$H$H$H$TR    ",'','','',        "$V           $V    ",'','','',        "$V  ","$F$T$F $F$T$F","  $V    ",'',
        "$V  ","$F$B$F $F$T$F","  $V    ",'',        "$V  "," $T     ","  $V    ",'',        "$V  ",' CHECK ',"  $V","  $F$F",
        "$V  ",'       ',"  $V"," $F$F ",        "$V  ",'      ','',"$F$F$B $F$F  ",        "$BL$H$H$H$H$H$H$H$H",'',''," $T$F$F$T ")
    $s=('QA Script Engine','Written by Mike @ My Random Thoughts','support@myrandomthoughts.co.uk','','','',$Message,$version,$underline)
    [System.ConsoleColor[]]$c=('White','Gray','Gray','Red','Cyan','Red','Green','Yellow','Yellow');Write-Host ''
    For ($i=0;$i-lt$q.Length;$i+=4) { Write-Colr '  ',$q[$i],$q[$i+1],$q[$i+2],$q[$i+3],$s[$i/4].PadLeft($Width-19) -Colour Yellow,White,Cyan,White,Green,$c[$i/4] }
    Write-Host ''
}

Function DivLine { Param ([int]$Width); Return ' '.PadRight($Width + 1, $L) }

###################################################################################################

# COMPILER INSERT
[int]      $script:waitTime       = 100    # Time to wait between starting new tasks (milliseconds)
[int]      $script:screenwidth    = 120    #
[int]      $script:failurecount   =   0    #
[array]    $script:results        = @()    #
[array]    $script:servers        = @()    #
[hashtable]$script:sections       = @{'acc' = $script:lang['Accounts'];       #
                                      'com' = $script:lang['Compliance'];      # 
                                      'drv' = $script:lang['Drives'];          # List of sections, matched
                                      'hvh' = $script:lang['HyperV-Host'];     # with the check short name
                                      'net' = $script:lang['Network'];         # 
                                      'reg' = $script:lang['Regional'];        # These are displayed in
                                      'sec' = $script:lang['Security'];        # the HTML report file
                                      'sys' = $script:lang['System'];          #
                                      'vmw' = $script:lang['Virtual'];        #
                                     }
$tt = [System.Diagnostics.StopWatch]::StartNew()
Check-CommandLine
Start-QAProcess
Show-Results

$tt.Stop()
Write-Host '  '$script:lang['TimeTaken'] $tt.Elapsed.Minutes 'min,' $tt.Elapsed.Seconds 'sec' -ForegroundColor White
Write-Host '  '$script:lang['ReportsLocated'] $script:qaOutput                                -ForegroundColor White
Write-Host (DivLine -Width $script:screenwidth)                                               -ForegroundColor Yellow
Write-Host ''
Write-Host ''
