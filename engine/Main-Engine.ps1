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

    # Resize window to be 132 wide and keep the height.
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
    If (-not ([Security.Principal.WindowsPrincipal] `
              [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole( `
              [Security.Principal.WindowsBuiltInRole] 'Administrator'))
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
    [boolean]$debug   = ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Debug'))
    If ($verbose -eq $true) { $script:ccTasks = 1 }

    # Write job information
    [int]$count = $script:qaChecks.Count
    Write-Host ($('  {0}' -f $script:lang['Scan-Head_1']) -f $count, $script:ccTasks) -ForegroundColor White
    Write-Host ($('  {0}' -f $script:lang['Scan-Head_2']) -f $script:checkTimeout   ) -ForegroundColor White

    # Progress bar legend
    [string]$lP = $script:lang['Passed']; [string]$lW = $script:lang['Warning']       ; [string]$lF = $script:lang['Failed']
    [string]$lM = $script:lang['Manual']; [string]$lN = $script:lang['Not-Applicable']; [string]$lE = $script:lang['Error']
    Write-Host ('')
    Write-Host ('     ■ ' + $lP) -NoNewline -ForegroundColor Green; Write-Host ('     ■ ' + $lW) -NoNewline -ForegroundColor Yellow
    Write-Host ('     ■ ' + $lF) -NoNewline -ForegroundColor Red  ; Write-Host ('     ■ ' + $lM) -NoNewline -ForegroundColor Cyan
    Write-Host ('     ■ ' + $lN) -NoNewline -ForegroundColor Gray ; Write-Host ('     ■ ' + $lE)            -ForegroundColor Magenta
    Write-Host (DivLine -Width $script:screenwidth)                                                         -ForegroundColor Yellow

    [string]$ServerCounts = ''
    [string]$DebugMessage = ''
    If ($script:servers.Count -gt 1) { $ServerCounts = '  '+($($script:lang['ServerCount']) -f $($script:servers.Count)) }
    If ($debug -eq $true)            { $DebugMessage = 'Debug Mode - Ignoring Server Connection Checks'                   }

    If (($ServerCounts -ne '') -and ($DebugMessage -ne ''))
    {
        Write-Host ('{0}{1}' -f $ServerCounts, $DebugMessage.PadLeft($script:screenwidth - $ServerCounts.Length)) -ForegroundColor White
        Write-Host (DivLine -Width $script:screenwidth)                                                           -ForegroundColor Yellow
    }

    # Create required output folders
    New-Item -ItemType Directory -Force -Path ($script:qaOutput) | Out-Null
    If ($verbose -eq $true) { $pBlock = '■' } Else { $pBlock = '▀' }
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
            # Use the test-port function to make sure that the RPC port is listening
            If (($debug -eq $true) -or ((Test-Port $server) -eq $true))
            {
                If ($verbose -eq $true) { Write-Host $script:lang['Verbose-Info'] -ForegroundColor Yellow -NoNewline }
                Else {  For ([int]$i = 0; $i -lt $count; $i++) { Write-Host '▄' -ForegroundColor DarkGray -NoNewline }
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
                                    $script:lang['Pass']           { Write-Host $pBlock -ForegroundColor Green  -NoNewline ; Break }
                                    $script:lang['Warning']        { Write-Host $pBlock -ForegroundColor Yellow -NoNewline ; Break }
                                    $script:lang['Fail']           { Write-Host $pBlock -ForegroundColor Red    -NoNewline ; Break }
                                    $script:lang['Manual']         { Write-Host $pBlock -ForegroundColor Cyan   -NoNewline ; Break }
                                    $script:lang['Not-Applicable'] { Write-Host $pBlock -ForegroundColor Gray   -NoNewline ; Break }
                                    $script:lang['Error']          { If ($result.data -like '*Access is denied*') {
                                                                         If ($workComplete -eq $false) {
                                                                             $result.message = $script:lang['AD-Message']    # ACCESS DENIED
                                                                             $script:failurecount++
                                                                             Write-Host ('■ ' + $script:lang['AD-Write-Host']) -ForegroundColor Magenta -NoNewline
                                                                             $workComplete = $true } }
                                                                     Else { If ($workComplete -eq $false) { Write-Host '█' -ForegroundColor Magenta -NoNewline } }
                                                                   }
                                    Default                        { Write-Host '█' -ForegroundColor DarkGray -NoNewline; Break }
                                }
                            }
                            Else
                            {
                                # Job returned no data
                                $result          = newResult
                                $result.server   = $server
                                $result.name     = $script:lang['ND-Name']    # NO DATA
                                $result.check    = $workItems[$key].name
                                $result.result   = 'Error'
                                $result.message  = $script:lang['ND-Message']
                                $script:results += $result
                                $serverresults  += $result
                                Write-Host '■' -ForegroundColor Magenta -NoNewline
                            }
                            $workItems.Remove($key)
                        
                        # Job failed or server disconnected
                        }
                        ElseIf (($workItems[$key].State -eq 'Failed') -or ($workItems[$key].State -eq 'Disconnected'))
                        {
                            $result          = newResult
                            $result.server   = $server
                            $result.name     = $workItems[$key].State.ToUpper()
                            $result.check    = $workItems[$key].name
                            $result.result   = 'Error'
                            $result.message  = $script:lang['FD-Message']    # FAILED / DISCONNECTED
                            $script:results += $result
                            $serverresults  += $result
                            Write-Host ('■ ' + $script:lang['FD-Write-Host']) -ForegroundColor Magenta -NoNewline
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
                                $result.name     = $script:lang['TO-Name']    # TIMEOUT
                                $result.check    = $workItems[$key].name
                                $result.result   = 'Error'
                                $result.message  = $script:lang['TO-Message']
                                $script:results += $result
                                $serverresults  += $result
                                Try { Stop-Job -Job $workItems[$key]; Remove-Job -Job $workItems[$key] } Catch { }
                                Write-Host '█' -ForegroundColor Magenta -NoNewline
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
                Write-Host ('■ ' + $script:lang['RPC-Write-Host']) -ForegroundColor Magenta -NoNewline
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
            Write-Host ('■ ' + $script:lang['CF-Write-Host']) -ForegroundColor Magenta -NoNewline
        }

        Write-Host ''
        Export-Results -results_input $serverresults
        If ($result.result -ne 'Error')
        {
            $resultsplit = Get-ResultsSplit -serverName $server
            [int]$padding = ($script:qaChecks).Count - 19
            If ($padding -lt 3) { $padding = 3 }
            If ($verbose -eq $true) { $padding = ($script:screenwidth - 23) }
            Write-Colr ''.PadLeft($padding), $resultsplit.p.PadLeft(2), ', ', $resultsplit.w.PadLeft(2), ', ', $resultsplit.f.PadLeft(2), ', ', `
                                             $resultsplit.m.PadLeft(2), ', ', $resultsplit.n.PadLeft(2), ', ', $resultsplit.e.PadLeft(2) `
                         -Colour White, Green, White, Yellow, White, Red, White, Cyan, White, Gray, White, Magenta
        }
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
    Write-Host (        '    {0}:{1}' -f                                                             ($script:lang['Failed']        ).PadLeft($w - $rightPad            - 2), ($resultsplit.f).PadLeft(4)) -ForegroundColor Red
    Write-Host (        '    {0}:{1}' -f                                                             ($script:lang['Manual']        ).PadLeft($w - $rightPad            - 2), ($resultsplit.m).PadLeft(4)) -ForegroundColor Cyan
    Write-Host (        '    {0}:{1}' -f                                                             ($script:lang['Not-Applicable']).PadLeft($w - $rightPad            - 2), ($resultsplit.n).PadLeft(4)) -ForegroundColor Gray
    Write-Host (        '    {0}:{1}' -f                                                             ($script:lang['Error']         ).PadLeft($w - $rightPad            - 2), ($resultsplit.e).PadLeft(4)) -ForegroundColor Magenta

    Write-Host (DivLine -Width $script:screenwidth) -ForegroundColor Yellow
    Remove-Variable x, y, w, resultsplit -ErrorAction SilentlyContinue
}

Function Export-Results
{
    Param ( [array]$results_input )
    [string]$Head = @'
<style>
    @charset UTF-8;
    html body       { font-family: Verdana, Geneva, sans-serif; font-size: 12px; height: 100%; margin: 0; overflow: auto; }
    #header         { background: #0066a1; color: #ffffff; width: 100% }
    #headerTop      { padding: 10px; }

    .logo1          { float: left;  font-size: 25px; font-weight: bold; padding: 0 7px 0 0; }
    .logo2          { float: left;  font-size: 25px; }
    .logo3          { float: right; font-size: 12px; text-align: right; }

    .headerRow1     { background: #66a3c7; height: 5px; }
    .headerRow2     { background: #000000; height: 5px; }
    .serverRow      { background: #000000; color: #ffffff; font-size: 32px; padding: 10px; text-align: center; text-transform: uppercase; }
    .summary        { width: 100%; }
    .summaryName    { float: left; text-align: center; padding: 6px 0; width: 16.66%; }
    .summaryCount   { text-align: center; font-size: 45px; }

    .p { background: #b3ffbe!important; }
    .w { background: #ffdc89!important; }
    .f { background: #ff9787!important; }
    .m { background: #66a3c7!important; }
    .n { background: #c8c8c8!important; }
    .e { background: #c80000!important; color: #ffffff!important; }
    .x { background: #ffffff!important; }
    .s { background: #c8c8c8!important; }

    .note           { text-decoration: none; }
    .note div.help  { display: none; }
    .note:hover     { cursor: help; position: relative; }
    .note:hover div.help { background: #ffffdd; border: #000000 3px solid; display: block; left: 10px; margin: 10px; padding: 15px; position: fixed; text-align: left; text-decoration: none; top: 10px; width: 600px; z-index: 100; }
    .note li        { display: table-row-group; list-style: none; }
    .note li span   { display: table-cell; vertical-align: top; padding: 3px 0; }
    .note li span:first-child { text-align: right; min-width: 120px; max-width: 120px; font-weight: bold; padding-right: 7px; }
    .note li span:last-child  { padding-left: 7px; border-left: 1px solid #000000; }

    .sectionRow     { background: #0066a1; color: #ffffff; font-size: 13px; padding: 1px 15px!important; font-weight: bold; height: 25px!important; }
    table tr:hover td.sectionRow { background: #0066a1; }

    table           { background: #eaebec; border: #cccccc 1px solid; border-collapse: collapse; margin: 0; width: 100%; }
    table th        { background: #ededed; border-top: 1px solid #fafafa; border-bottom: 1px solid #e0e0e0; border-left: 1px solid #e0e0e0; height: 45px; min-width: 55px; padding: 0px 15px; text-transform: capitalize; }
    table tr        { text-align: center; padding-left: 15px; }
    table td        { background: #fafafa; border-top: 1px solid #ffffff; border-bottom: 1px solid #e0e0e0; border-left: 1px solid #e0e0e0; height: 55px; min-width: 55px; padding: 0px 10px; }
    table td:first-child   { min-width: 175px; width: 175px; text-align: left; }
    table tr:last-child td { border-bottom: 0; }
    table tr:hover td      { background: #f2f2f2; }
</style>
'@

    If ($SkipHTMLHelp -eq $true) { $Head = $Head.Replace('cursor: help;', 'cursor: default;') }

    [string]$dt1 = (Get-Date -Format 'yyyy/MM/dd HH:mm')
    [string]$dt2 = $dt1.Replace('/','.').Replace(' ','-').Replace(':','.')    # 'yyyy/MM/dd HH:mm'  -->  'yyyy.MM.dd-HH.mm'
    [string]$un  = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.ToLower()

    [string]$server = $results_input[0].server
    $resultsplit = Get-ResultsSplit -serverName $server
    [string]$body = @"
<div id="header">
    <div id="headerTop">
        <div class="logo1">$reportCompanyName</div>
        <div class="logo2">$($script:lang['QA-Results'])</div>
        <div class="logo3">$($script:lang['Script-Version']) <b>$version</b> ($settingsFile)
                      <br/>$($script:lang['Generated-By']) <b>$un</b> $($script:lang['On']) <b>$dt1</b></div>
        <div style="clear:both;"></div>
    </div>
    <div style="clear:both;"></div>
</div>
<div class="headerRow1"></div>
<div class="serverRow">$server</div>
<div class="summary">
    <div class="summaryName p"><b>$($script:lang['Passed']        )</b><br><span class="summaryCount">$($resultsplit.p)</span></div>
    <div class="summaryName w"><b>$($script:lang['Warning']       )</b><br><span class="summaryCount">$($resultsplit.w)</span></div>
    <div class="summaryName f"><b>$($script:lang['Failed']        )</b><br><span class="summaryCount">$($resultsplit.f)</span></div>
    <div class="summaryName m"><b>$($script:lang['Manual']        )</b><br><span class="summaryCount">$($resultsplit.m)</span></div>
    <div class="summaryName n"><b>$($script:lang['Not-Applicable'])</b><br><span class="summaryCount">$($resultsplit.n)</span></div>
    <div class="summaryName x"><b>$($script:lang['Error']         )</b><br><span class="summaryCount">$($resultsplit.e)</span></div>
</div>
<div style="clear:both;"></div>
<div class="headerRow2"></div>
"@

    [array] $core = @()
    [array] $cust = @()
    [string]$path = $script:qaOutput + $server + '_' + $dt2 + '.html'
    # Sort the results, adding the customer specific items at the end
    $results_input   | Select-Object name, check, result, message, data | ForEach-Object {
        If (($_.check) -eq 'X') { $core += $_ } Else { If ($script:sections.Keys -contains ($_.check).SubString(2,3)) { $core += $_ } Else { $cust += $_ } }
    }
    $core    = $core | Sort-Object check; $cust = $cust | Sort-Object check
    $outHTML = $core + $cust | ConvertTo-HTML -Head $Head -Title 'QA Results' -Body $Body

    $outHTML = Set-CellColour -Filter ('result -eq "' + $($script:lang['Pass'])           + '"') -InputObject $outHTML
    $outHTML = Set-CellColour -Filter ('result -eq "' + $($script:lang['Warning'])        + '"') -InputObject $outHTML
    $outHTML = Set-CellColour -Filter ('result -eq "' + $($script:lang['Fail'])           + '"') -InputObject $outHTML
    $outHTML = Set-CellColour -Filter ('result -eq "' + $($script:lang['Manual'])         + '"') -InputObject $outHTML
    $outHTML = Set-CellColour -Filter ('result -eq "' + $($script:lang['Not-Applicable']) + '"') -InputObject $outHTML
    $outHTML = Set-CellColour -Filter ('result -eq "' + $($script:lang['Error'])          + '"') -InputObject $outHTML -Row
    $outHTML = Format-HTMLOutput -InputObject $outHTML
    $outHTML | Out-File $path -Force -Encoding utf8

    # CSV Output
    If ($GenerateCSV -eq $true)
    {
        [string]$path   =  $script:qaOutput + 'QA_Results.csv'
        [array] $outCSV =  @()
        [array] $cnvCSV = ($results_input | Select-Object server, name, check, datetime, result, message, data | Sort-Object check, server | ConvertTo-Csv -NoTypeInformation)
        $cnvCSV | ForEach-Object { $outCSV += $_.Replace(',#',', ') }
        $outCSV | Out-File -FilePath $path -Encoding utf8 -Force -Append
    }

    If ($GenerateXML -eq $true)
    {
        [string]$path   =  $script:qaOutput + 'QA_Results.xml'
        [array] $outXML =  @()
        [array] $cnvXML = (($results_input | Select-Object server, name, check, datetime, result, message, data | Sort-Object check, server | ConvertTo-Xml -NoTypeInformation).OuterXml -as [string])
        $cnvXML | ForEach-Object { $outXML += $_.Replace(',#',', ') }
        $outXML | Out-File -FilePath $path -Encoding utf8 -Force -Append
    }
}

###################################################################################################

Function Format-HTMLOutput
{
    Param ( [Object[]]$InputObject )
    Begin { }
    Process
    {
        [string]$sectionNew = ''
        [string]$sectionOld = ''

        ForEach ($input In $InputObject)
        {
            [string]$line = $input
            If ($line.IndexOf('<tr><th') -ge 0)
            {
                [int]$count = 0
                [int]$func  = 0
                $search = $line | Select-String -Pattern '<th>(.*?)</th>' -AllMatches
                ForEach ($match in $search.Matches)
                {
                    If ($match.Groups[1].Value -eq 'check'  ) { $func  = $count }
                    $count++
                }
                If ($func -eq $search.Matches.Count) { Break }

                # Rename headers to language specific values
                $line = $line.Replace('<th>name</th>',    "<th>$($script:lang['HTML_Name']   )</th>")
                $line = $line.Replace('<th>check</th>',   "<th>$($script:lang['HTML_Check']  )</th>")
                $line = $line.Replace('<th>result</th>',  "<th>$($script:lang['HTML_Result'] )</th>")
                $line = $line.Replace('<th>message</th>', "<th>$($script:lang['HTML_Message'])</th>")
                $line = $line.Replace('<th>data</th>',    "<th>$($script:lang['HTML_Data']   )</th>")
            }

            [string]$sectionRow = ''
            If ($line -match '<tr><td')
            {
                $search = $line | Select-String -Pattern '<td(.*?)>(.*?)</td>' -AllMatches
                If ($search.Matches.Count -ne 0)
                {
                    Try
                    {
                        # Rename "check" names
                        [string]$old = $search.Matches[$func].Groups[2].Value
                        If (($old.StartsWith('c-') -eq $true) -or ($old.StartsWith('f-') -eq $true))
                        {
                            [string]$new = $old.Substring(0,8)
                            $line = $line.Replace($old, $new)
                        }

                        # Add line breaks for long lines in results - If the check supports it.
                        $line = $line.Replace(',#', ',<br/>')

                        # Add section headers
                        Try { $sectionNew = ($search.Matches[$func].Groups[2].Value).Substring(2, 3).Replace('-', '') } Catch { $sectionNew = '' }
                        If ($sectionNew -ne $sectionOld)
                        {
                            $sectionOld = $sectionNew
                            [string]$selctionName = $script:sections[$sectionNew]
                            $sectionRow = '<tr><td class="sectionRow" colspan="5">{0}</td></tr>' -f $selctionName
                        }
                        Else { $sectionRow = '' }
                    }
                    Catch { }
                }
            }
            ElseIf ($line.StartsWith('</table>') -eq $true) { $sectionRow = '<tr><td class="sectionRow" colspan="5">&nbsp;</td>' }

            Write-Output $sectionRow$line
         }
    }
    End { }
}

Function Set-CellColour
{
    Param ( [Object[]]$InputObject, [string]$Filter, [switch]$Row )
    Begin
    {
        $Property = ($Filter.Split(' ')[0])
        $Colour   = ($Filter.Split(' ')[2]).Substring(1,1).ToLower()

        If ($Filter.ToUpper().IndexOf($Property.ToUpper()) -ge 0)
        {
            $Filter = $Filter.ToUpper().Replace($Property.ToUpper(), '$value')
            Try { [scriptblock]$Filter = [scriptblock]::Create($Filter) } Catch { Exit }
        } Else { Exit }
    }
    
    Process
    {
        ForEach ($input In $InputObject)
        {
            [string]$line = $input
            If ($line.IndexOf('<tr><th') -ge 0)
            {
                [int]$index = 0
                [int]$count = 0
                [int]$func  = 0
                $search = $line | Select-String -Pattern '<th>(.*?)</th>' -AllMatches
                ForEach ($match in $search.Matches)
                {
                    If ($match.Groups[1].Value -eq 'check'  ) { $func  = $count }
                    If ($match.Groups[1].Value -eq $Property) { $index = $count }
                    $count++
                }
                If ($index -eq $search.Matches.Count) { Break }
            }

            If ($line -match '<tr><td')
            {
                $search = $line | Select-String -Pattern '<td>(.*?)</td>' -AllMatches
                If (($search -ne $null) -and ($search.Matches.Count -ne 0))
                {
                    Try { [string]$check = ($search.Matches[$func].Groups[1].Value).Substring(2, 6).Replace('-', '') } Catch { [string]$check = '' }
                    $value = $search.Matches[$index].Groups[1].Value -as [double]
                    If ($value -eq $null) { $value = $search.Matches[$index].Groups[1].Value }
                    If (Invoke-Command $Filter)
                    {
                        If ($Row -eq $true) { $line = $line.Replace('<td>', '<td class="e">') }    # There was an error with this server
                        Else
                        {
                            # Insert HTML hover help
                            [string]$note = '' + $value + '</td>'
                            If (-not $SkipHTMLHelp)
                            {
                                [string]$help = Add-HoverHelp -inputLine $line -check $check
                                If ($help -ne '') { $note = '<div class="help">{0}</div>{1}</td>' -f $help, $value }
                            }

                            # Change result status cell colour
                            $line = $line.Replace($search.Matches[$index].Value, ('<td class="{0} note">{1}' -f $Colour, $note))
                        }
                    }
                    Remove-Variable value -ErrorAction SilentlyContinue
                }
            }
            Write-Output $line
        }
    }
}

Function Add-HoverHelp
{
    Param ([string]$inputLine, [string]$check)
    [string]$help = ''
    If ($script:qahelp[$check])
    {
        Try
        {
            [xml]$xml  = $script:qahelp[$check]
                 $help = '<li><span>{0}<br/>{1}</span><span>{2}</span></li><br/>' -f $script:sections[$check.Substring(0,3)], $check.Substring(3, 2), $xml.xml.description
            If ($xml.xml.ChildNodes.ToString() -like '*pass*'   ) { $help += '<li><span>{0}</span><span>{1}</span></li>' -f $script:lang['Pass'],           ($xml.xml.pass)    }
            If ($xml.xml.ChildNodes.ToString() -like '*warning*') { $help += '<li><span>{0}</span><span>{1}</span></li>' -f $script:lang['Warning'],        ($xml.xml.warning) }
            If ($xml.xml.ChildNodes.ToString() -like '*fail*'   ) { $help += '<li><span>{0}</span><span>{1}</span></li>' -f $script:lang['Fail'],           ($xml.xml.fail)    }
            If ($xml.xml.ChildNodes.ToString() -like '*manual*' ) { $help += '<li><span>{0}</span><span>{1}</span></li>' -f $script:lang['Manual'],         ($xml.xml.manual)  }
            If ($xml.xml.ChildNodes.ToString() -like '*na*'     ) { $help += '<li><span>{0}</span><span>{1}</span></li>' -f $script:lang['Not-Applicable'], ($xml.xml.na)      }
            $help += '<br/><li><span>{0}</span><span>{1}</span></li>' -f $script:lang['Applies-To'], ($xml.xml.applies).Replace(', ','<br/>')
            $help = $help.Replace('!n', '<br/>')
        }
        Catch { $help = $($_.Exception.Message) }    # No help if XML is invalid
    }
    Return $help
}

###################################################################################################

Function Test-Port
{
    Param ( [string]$serverName )
    $tcp  = New-Object System.Net.Sockets.TcpClient
    $iar  = $tcp.BeginConnect($serverName, 135, $null, $null)
    $wait = $iar.AsyncWaitHandle.WaitOne(3000, $false)

    $failed = $false
    If (-not $wait)
    {
        # Connection timeout
        $tcp.Close()
        Return $false
    }
    Else
    {
        # Close the connection and report the error if there is one
        $error.Clear()
        Try { $tcp.EndConnect($iar) | Out-Null } Catch {}
        If (!$?) { $failed = $true }
        $tcp.Close()
    }
    If ($failed -eq $true) { Return $false } Else { Return $true }
}

Function Write-Colr
{
    Param ([String[]]$Text,[ConsoleColor[]]$Colour,[Switch]$NoNewline=$false)
    For ([int]$i = 0; $i -lt $Text.Length; $i++) { Write-Host $Text[$i] -Foreground $Colour[$i] -NoNewLine }
    If ($NoNewline -eq $false) { Write-Host '' }
}

Function Write-Header
{
    Param ([string]$Message,[int]$Width); $underline=''.PadLeft($Width-16,'─')
    $q=('╔═══════════╗    ','','','','║           ║    ','','','','║  ','█▀█ █▀█','  ║    ','','║  ','█▄█ █▀█','  ║    ','','║  ',' ▀     ','  ║    ','',
        '║  ',' CHECK ','  ║','  ██','║  ','       ','  ║',' ██ ','║  ','      ','','██▄ ██  ','╚════════','','',' ▀██▀ ')
    $s=('QA Script Engine','Written by Mike @ My Random Thoughts','support@myrandomthoughts.co.uk','','','',$Message,$version,$underline)
    [System.ConsoleColor[]]$c=('White','Gray','Gray','Red','Cyan','Red','Green','Yellow','Yellow');Write-Host ''
    For ($i=0;$i-lt$q.Length;$i+=4) { Write-Colr '  ',$q[$i],$q[$i+1],$q[$i+2],$q[$i+3],$s[$i/4].PadLeft($Width-19) -Colour Yellow,White,Cyan,White,Green,$c[$i/4] }
    Write-Host ''
}

Function DivLine { Param ([int]$Width); Return ' '.PadRight($Width + 1, '─') }

###################################################################################################

[int]      $script:ccTasks        =   5    # Number of concurrent tasks to perform (the higher the number the more resources you need)
[int]      $script:waitTime       = 100    # Time to wait between starting new tasks (milliseconds)
[int]      $script:checkTimeout   =  60    # Time to wait for each task to complete (seconds)
[int]      $script:screenwidth    = 120    #
[int]      $script:failurecount   =   0    #
[array]    $script:results        = @()    #
[array]    $script:servers        = @()    #
[hashtable]$script:sections       = @{'acc' = $script:lang['Accounts'];       #
                                      'com' = $script:lang['Compliance'];      # 
                                      'drv' = $script:lang['Drives'];          # List of sections, matched
                                      'hvh' = $script:lang['HyperV-Host'];     # with the check short name
                                      'net' = $script:lang['Network'];         # 
                                      'reg' = $script:lang['Regional'];        #
                                      'sec' = $script:lang['Security'];        # These are displayed in
                                      'sys' = $script:lang['System'];          # the HTML report file
                                      'vhv' = $script:lang['VMs-HyperV'];      #
                                      'vmw' = $script:lang['VMs-VMware'];     #
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
