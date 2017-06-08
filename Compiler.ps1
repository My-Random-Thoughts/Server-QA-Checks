<#
    Compiles all the needed powershell files for QA checks into one master script.
#>

Param ([string]$Settings, [switch]$Silent = $false)
Set-StrictMode -Version 2

If ([string]::IsNullOrEmpty($Settings)) { $Settings = 'default-settings.ini' }
[string]$version = ('v3.{0}.{1}' -f (Get-Date -Format 'yy'), (Get-Date -Format 'MMdd'))
[string]$date    = Get-Date -Format 'yyyy/MM/dd HH:mm'
[string]$path    = Split-Path (Get-Variable MyInvocation -ValueOnly).MyCommand.Path
Try { $gh = Get-Host;  [int]$ws = $gh.UI.RawUI.WindowSize.Width - 2 } Catch { [int]$ws = 80 }
If ($ws -lt 80) { $ws = 80 }

###################################################################################################
# Required Functions                                                                              #
###################################################################################################

[string]$F  = ([char]9608).ToString()
[string]$T  = ([char]9600).ToString()
[string]$B  = ([char]9604).ToString()
[string]$M  = ([char]9632).ToString()
[string]$L  = ([char]9472).ToString()

[string]$TL = ([char]9556).ToString()
[string]$TR = ([char]9559).ToString()
[string]$BL = ([char]9562).ToString()
[string]$V  = ([char]9553).ToString()
[string]$H  = ([char]9552).ToString()

Function Write-Host2 ([string]$Message, [consolecolor]$ForegroundColor = ($Host.UI.RawUI.ForegroundColor), [switch]$NoNewline = $false)
{
    If ($Silent -eq $false) { Write-Host $Message -NoNewline:$NoNewline -ForegroundColor $ForegroundColor }
}

Function Write-Colr
{
    Param ([String[]]$Text,[ConsoleColor[]]$Colour,[Switch]$NoNewline=$false)
    For ([int]$i = 0; $i -lt $Text.Length; $i++) { Write-Host2 $Text[$i] -Foreground $Colour[$i] -NoNewLine }
    If ($NoNewline -eq $false) { Write-Host2 '' }
}

Function Write-Header
{
    Param ([string]$Message,[int]$Width); $underline=''.PadLeft($Width-16,$H)
    $q=("$TL$H$H$H$H$H$H$H$H$H$H$H$TR    ",'','','',        "$V           $V    ",'','','',        "$V  ","$F$T$F $F$T$F","  $V    ",'',
        "$V  ","$F$B$F $F$T$F","  $V    ",'',        "$V  "," $T     ","  $V    ",'',        "$V  ",' CHECK ',"  $V","  $F$F",
        "$V  ",'       ',"  $V"," $F$F ",        "$V  ",'      ','',"$F$F$B $F$F  ",        "$BL$H$H$H$H$H$H$H$H",'',''," $T$F$F$T ")
    $s=('QA Script Engine','Written by Mike @ My Random Thoughts','support@myrandomthoughts.co.uk','','','',$Message,$version,$underline)
    [System.ConsoleColor[]]$c=('White','Gray','Gray','Red','Cyan','Red','Green','Yellow','Yellow');Write-Host2 ''
    For ($i=0;$i-lt$q.Length;$i+=4) { Write-Colr '  ',$q[$i],$q[$i+1],$q[$i+2],$q[$i+3],$s[$i/4].PadLeft($Width-19) -Colour Yellow,White,Cyan,White,Green,$c[$i/4] }
    Write-Host2 ''
}

Function DivLine { Param ([int]$Width); Return ' '.PadRight($Width, $L) }
Function Load-IniFile
{
    Param ([string]$InputFile)
    If ($InputFile.ToLower().EndsWith('.ini') -eq $false) { $InputFile += '.ini' }
    If ((Test-Path -Path $InputFile) -eq $false)
    {
        Switch (Split-Path -Path (Split-Path -Path $InputFile -Parent) -Leaf)
        {
            'i18n'     { [string]$errMessage = '  ERROR: Language ' }
            'settings' { [string]$errMessage = '  ERROR: Settings ' }
            Default    { [string]$errMessage = (Split-Path -Path (Split-Path -Path $InputFile -Parent) -Leaf) }
        }
        Write-Host2 ($errMessage + 'file "{0}" not found.' -f (Split-Path -Path $InputFile -Leaf)) -ForegroundColor Red
        Write-Host2  '        '$InputFile                                                          -ForegroundColor Red
        Write-Host2 ''
        Break
    }

    [string]   $comment = ";"
    [string]   $header  = "^\s*(?!$($comment))\s*\[\s*(.*[^\s*])\s*]\s*$"
    [string]   $item    = "^\s*(?!$($comment))\s*([^=]*)\s*=\s*(.*)\s*$"
    [hashtable]$ini     = @{}
    Switch -Regex -File $inputfile {
        "$($header)" { $section = ($matches[1] -replace ' ','_'); $ini[$section.Trim()] = @{} }
        "$($item)"   { $name, $value = $matches[1..2]; If (($name -ne $null) -and ($section -ne $null)) { $ini[$section][$name.Trim()] = $value.Trim() } }
    }
    Return $ini
}

###################################################################################################

If ($Silent -eq $false) { Clear-Host }
Write-Header -Message 'QA Script Engine Check Compiler' -Width $ws

# Load settings file
Try
{
    [hashtable]$iniSettings = (Load-IniFile -InputFile ("$path\settings\$Settings" ))
    [hashtable]$lngStrings  = (Load-IniFile -InputFile ("$path\i18n\{0}_text.ini" -f ($iniSettings['settings']['language'])))
}
Catch
{
    Write-Host2 '  ERROR: There were problems loading the required INI files.' -ForegroundColor Red
    Write-Host2 '         Please check the settings file is correct.'          -ForegroundColor Red
    Write-Host2 ''
    Break
}

[string]$shared       = "Function newResult { Return ( New-Object -TypeName PSObject -Property @{'server'=''; 'name'=''; 'check'=''; 'datetime'=(Get-Date -Format 'yyyy-MM-dd HH:mm'); 'result'='Unknown'; 'message'=''; 'data'='';} ) }"
[string]$scriptHeader = @"
#Requires -Version 2
<#
    QA MASTER SCRIPT
    DO NOT EDIT THIS FILE - ALL CHANGES WILL BE LOST
    THIS FILE IS AUTO-COMPILED FROM SEVERAL SOURCE FILES
    VERSION : $version
    COMPILED: $date
#>
"@
$scriptHeader += @' 
[CmdletBinding(DefaultParameterSetName = 'HLP')]
Param (
    [Parameter(ParameterSetName='QAC', Mandatory=$true, Position=1)][string[]]$ComputerName,
    [Parameter(ParameterSetName='QAC', Mandatory=$false           )][switch]  $SkipHTMLHelp,
    [Parameter(ParameterSetName='QAC', Mandatory=$false           )][switch]  $GenerateCSV,
    [Parameter(ParameterSetName='QAC', Mandatory=$false           )][switch]  $GenerateXML,
    [Parameter(ParameterSetName='QAC', Mandatory=$false           )][switch]  $DoNotPing,
    [Parameter(ParameterSetName='HLP', Mandatory=$false           )][switch]  $Help
)
Set-StrictMode -Version 2
 
'@

# Get full list of checks...
[object]$qaChecks = Get-ChildItem -Path ($path + '\checks') -Recurse | Where-Object { (-not $_.PSIsContainer) -and ($_.Name).StartsWith('c-') -and ($_.Name).EndsWith('.ps1') | Sort-Object $_.Name }
If ([string]::IsNullOrEmpty($qaChecks) -eq $true)
{
    Write-Host2 '  ERROR: No checks found'                                         -ForegroundColor Red
    Write-Host2 '  Please make sure you are running this from the correct folder.' -ForegroundColor Red
    Write-Host2 ''
    Break
}

###################################################################################################

[string]$shortcode = ($iniSettings['settings']['shortcode'] + '_').ToString().Replace(' ', '-')
If ($shortcode -eq '_') { $shortcode = '' }

Write-Host2 '  Removing Previous Check Versions...... ' -NoNewline -ForegroundColor White
[string]$outPath = "$path\QA_$shortcode$version.ps1"
If (Test-Path -Path $outPath) { Try { Remove-Item $outPath -Force } Catch { } }
Write-Host2 'Done' -ForegroundColor Green

###################################################################################################
# CHECKS building                                                                                 #
###################################################################################################

Write-Colr '  Generating New QA Check Script........ ', $qaChecks.Count, ' checks ' -Colour White, Green, White
Write-Colr '  Using Settings File................... ', $Settings.ToUpper()         -Colour White, Green
Write-Host2 '   ' -NoNewline; For ($j = 0; $j -lt ($qaChecks.Count + 5); $j++) { Write-Host2 $B -NoNewline -ForegroundColor DarkGray }; Write-Host2 ''
Write-Host2 '   ' -NoNewline

# Start building the QA file
Out-File -FilePath $outPath -InputObject $scriptHeader                                                                 -Encoding utf8
Out-File -FilePath $outPath -InputObject ('[string]   $version               = "' + $version   + '"')                  -Encoding utf8 -Append
Out-File -FilePath $outPath -InputObject ('[string]   $settingsFile          = "' + $Settings  + '"')                  -Encoding utf8 -Append
Out-File -FilePath $outPath -InputObject ('[hashtable]$script:lang           = @{}'                 )                  -Encoding utf8 -Append
Out-File -FilePath $outPath -InputObject ('[hashtable]$script:qahelp         = @{}'                 )                  -Encoding utf8 -Append
Out-File -FilePath $outPath -InputObject ('')                                                                          -Encoding utf8 -Append

# Add the shared variables code
Out-File -FilePath $outPath -InputObject ($shared)                                                                     -Encoding utf8 -Append
Out-File -FilePath $outPath -InputObject ('')                                                                          -Encoding utf8 -Append; Write-Host2 $T -NoNewline -ForegroundColor Cyan

# Get a list of all the checks, adding them into an array
[string]$cList = '[array]$script:qaChecks = ('
[string]$cLine = ''
ForEach ($qa In $qaChecks)
{
    [string]$checkName = ($qa.BaseName).Substring(1, 8).Replace('-','')
    If (-not $iniSettings["$checkName-skip"])
    {
        $cCheck = 'c-' + $qa.BaseName.Substring(2); $cLine += "'$cCheck',"
        If ($cList.EndsWith('(')) { $space = '' } Else { $space = "`n".PadRight(28) }
        If ($cLine.Length -ge 130) { $cList += "$space$cLine"; $cLine='' }
    }
}

If ($cLine.Length -gt 10)
{
    If ($cList.Substring($cList.Length - 10, 10) -ne $cLine.Substring($cLine.Length - 10, 10))
    {
        $cList += "$space$cLine"
        $cLine=''
    }
}

$cList = $cList.Trim(',') + ')'
Out-File -FilePath $outPath -InputObject $cList                                                                        -Encoding utf8 -Append; Write-Host2 $T -NoNewline -ForegroundColor Cyan
Out-File -FilePath $outPath -InputObject ('')                                                                          -Encoding utf8 -Append
Out-File -FilePath $outPath -InputObject (''.PadLeft(190, '#'))                                                        -Encoding utf8 -Append
Out-File -FilePath $outPath -InputObject ('# QA Check Script Blocks')                                                  -Encoding utf8 -Append

[System.Text.StringBuilder]$qaHelp = ''

# Add each check into the script
ForEach ($qa In $qaChecks)
{
    Out-File -FilePath $outPath -InputObject "`$c$($qa.Name.Substring(2, 6).Replace('-','')) = {"                      -Encoding utf8 -Append

    Out-File -FilePath $outPath -InputObject ($shared)                                                                 -Encoding utf8 -Append
    
    Out-File -FilePath $outPath -InputObject '$script:lang        = @{}'                                               -Encoding utf8 -Append
    Out-File -FilePath $outPath -InputObject '$script:appSettings = @{}'                                               -Encoding utf8 -Append
    [string]$checkName = ($qa.Name).Substring(1, 8).Replace('-','')
    If ($iniSettings["$checkName-skip"]) { $checkName += '-skip' }

    # Add each checks settings
    Try
    {
        ForEach ($key In ($iniSettings[$checkName].Keys | Sort-Object))
        {
            [string]$value = $iniSettings[$checkName][$key]
            If ($value -eq '') { $value = "''" }
            [string]$appSetting = ('$script:appSettings[' + "'{0}'] = {1}" -f $key, $value)
            Out-File -FilePath $outPath -InputObject $appSetting                                                       -Encoding utf8 -Append
        }
    }
    Catch
    {
        # Missing INI Section for this check, read from the check script itself
        [string]$getContent = ((Get-Content -Path ($qa.FullName) -TotalCount 50) -join "`n")
        $regExV = [RegEx]::Match($getContent, "DEFAULT-VALUES:((?:.|\s)+?)(?:(?:[A-Z\- ]+:\n)|(?:#>))")
        [string[]]$Values = ($regExV.Groups[1].Value.Trim()).Split("`n")
        If (([string]::IsNullOrEmpty($Values) -eq $false) -and ($Values -ne 'None'))
        {
            ForEach ($EachValue In $Values)
            {
                [string]$key   = ($EachValue -split ' = ')[0].Trim()
                [string]$value = ($EachValue -split ' = ')[1].Trim()
                If ($value -eq '') { $value = "''" }

                [string]$appSetting = ('$script:appSettings[' + "'{0}'] = {1}" -f $key, $value)
                Out-File -FilePath $outPath -InputObject $appSetting                                                   -Encoding utf8 -Append
            }
        }
    }

    # Add language specific strings to each check
    Try {
        ForEach ($key In ($lngStrings['common'].Keys | Sort-Object))
        {
            [string]$value = $lngStrings['common'][$key]
            If ($value -eq '') { $value = "''" }
            [string]$lang = ('$script:lang[' + "'{0}'] = {1}" -f $key, $value)
            Out-File -FilePath $outPath -InputObject $lang                                                             -Encoding utf8 -Append
        }

        $checkName = $checkName.TrimEnd('-skip')
        ForEach ($key In ($lngStrings[$checkName].Keys | Sort-Object))
        {
            [string]$value = $lngStrings[$checkName][$key]
            If ($value -eq '') { $value = "''" }
            [string]$lang = ('$script:lang[' + "'{0}'] = {1}" -f $key, $value)
            Out-File -FilePath $outPath -InputObject $lang                                                             -Encoding utf8 -Append
        }
    } Catch { }

    # Add the check itself
    Out-File -FilePath $outPath -InputObject (Get-Content -Path ($qa.FullName))                                        -Encoding utf8 -Append

    # Generate the help text for from each check (taken from the header information)
    # ALSO, add any required additional script functions
    [string]  $xmlHelp    = "<xml>"
    [string[]]$keyWords   = @('DESCRIPTION', 'REQUIRED-INPUTS', 'PASS', 'WARNING', 'FAIL', 'MANUAL', 'NA', 'APPLIES', 'REQUIRED-FUNCTIONS')
    [string]  $getContent = ((Get-Content -Path ($qa.FullName)) -join "`n")
    ForEach ($keyWord In $KeyWords)
    {
        # Code from Reddit user "sgtoj"
        $regEx = [RegEx]::Match($getContent, "$($keyWord):((?:.|\s)+?)(?:(?:[A-Z\- ]+:)|(?:#>))")
        [string[]]$sectionValue = ($regEx.Groups[1].Value.Trim()).Split("`n")

        If (([string]::IsNullOrEmpty($sectionValue) -eq $false) -and ($sectionValue -notlike '*None*'))
        {
            # Add any required additional script functions
            If ($keyWord -eq 'REQUIRED-FUNCTIONS') {
                ForEach ($function In $sectionValue) {
                    Out-File -FilePath $outPath -InputObject (Get-Content "$path\engine\$($function.Trim()).ps1")   -Encoding utf8 -Append
                }
            }
            Else
            {
                $keyWord  = $keyWord.ToLower()
                $xmlHelp += "<$($keyWord.Replace('-', ''))>"
                ForEach ($item in $sectionValue) { $xmlHelp += "$($item.Trim())"; If ($keyWord -ne 'DESCRIPTION') { $xmlHelp += "!n" } }
                $xmlHelp += "</$($keyWord.Replace('-', ''))>"
            }
        }
    }
    $xmlHelp  += "</xml>"
    $checkName = $checkName.TrimEnd('-skip')
    $qaHelp.AppendLine('$script:qahelp[' + "'$checkName']='$xmlHelp'") | Out-Null

    # Complete this check

    Out-File -FilePath $outPath -InputObject '}'                                                                       -Encoding utf8 -Append; Write-Host2 $T -NoNewline -ForegroundColor Green
}
Out-File -FilePath $outPath -InputObject (''.PadLeft(190, '#'))                                                        -Encoding utf8 -Append

# Write out the EN-GB help file
Out-File -FilePath "$path\i18n\en-gb_help.ps1" -InputObject ($qaHelp.ToString()) -Force                                -Encoding utf8;         Write-Host2 $T -NoNewline -ForegroundColor Cyan

[string]$language = ($iniSettings['settings']['language'])
If (($language -eq '') -or ((Test-Path -Path "$path\i18n\$language.ini") -eq $false)) { $language = 'en-gb' }
Out-File -FilePath $outPath -InputObject (Get-Content ("$path\i18n\$language" + "_help.ps1"))                          -Encoding utf8 -Append; Write-Host2 $T -NoNewline -ForegroundColor Cyan
Out-File -FilePath $outPath -InputObject (''.PadLeft(190, '#'))                                                        -Encoding utf8 -Append
Try
{
    ForEach ($key In ($lngStrings['engine'].Keys | Sort-Object))
    {
        [string]$value = $lngStrings['engine'][$key]
        If ($value -eq '') { $value = "''" }
        [string]$lang = ('$script:lang[' + "'{0}'] = {1}" -f $key, $value)
        Out-File -FilePath $outPath -InputObject $lang                                                                 -Encoding utf8 -Append
    }
}
Catch { }
Out-File -FilePath $outPath -InputObject (''.PadLeft(190, '#'))                                                        -Encoding utf8 -Append
[object]$engine = (Get-Content ($path + '\engine\Main-Engine.ps1'))
$engine = $engine.Replace('# COMPILER INSERT', '[string]   $reportCompanyName     = "' + ($iniSettings['settings']['reportCompanyName'])            + '"' + "`n# COMPILER INSERT")
$engine = $engine.Replace('# COMPILER INSERT', '[string]   $script:qaOutput       = "' + ($iniSettings['settings']['outputLocation']   )            + '"' + "`n# COMPILER INSERT")
$engine = $engine.Replace('# COMPILER INSERT', '[int]      $script:ccTasks        = '  + ($iniSettings['settings']['concurrent']       ).PadLeft(3) +       "`n# COMPILER INSERT")
$engine = $engine.Replace('# COMPILER INSERT', '[int]      $script:checkTimeout   = '  + ($iniSettings['settings']['timeout']          ).PadLeft(3) +       "`n")
Out-File -FilePath $outPath -InputObject $engine                                                                       -Encoding utf8 -Append; Write-Host2 $T -NoNewline -ForegroundColor Cyan

Write-Host2 ''

###################################################################################################
# FINISH                                                                                          #
###################################################################################################

Write-Host2 (DivLine -Width $ws) -ForegroundColor Yellow
Write-Colr '  Execute ',$(Split-Path -Leaf $outPath),' for command line help' -Colour White, Yellow, White
Remove-Variable version, date, path, outpath -ErrorAction SilentlyContinue
Write-Host2 ''
Write-Host2 ''
