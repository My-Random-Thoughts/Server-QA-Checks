#Requires         -Version 4
Set-StrictMode    -Version 2
Remove-Variable * -ErrorAction SilentlyContinue
Clear-Host

Write-Host ''
Write-Host '  Starting Server QA Settings Configurator...'

# Icon Image Index: 0: Optional, 1: Gear, 2: Disabled Gear

[Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Data')          | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Drawing')       | Out-Null
[System.Drawing.Font]$sysFont       = [System.Drawing.SystemFonts]::MessageBoxFont
[System.Drawing.Font]$sysFontBold   = New-Object 'System.Drawing.Font' ($sysFont.Name, $sysFont.SizeInPoints, [System.Drawing.FontStyle]::Bold)
[System.Drawing.Font]$sysFontItalic = New-Object 'System.Drawing.Font' ($sysFont.Name, $sysFont.SizeInPoints, [System.Drawing.FontStyle]::Italic)
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:qahelp = @{}

###################################################################################################
##                                                                                               ##
##   Various Required Scripts                                                                    ##
##                                                                                               ##
###################################################################################################
#region Various Required Scripts
Function Get-Folder ( [string]$Description, [string]$InitialDirectory, [boolean]$ShowNewFolderButton )
{
    [string]$return = ''
    If ([threading.thread]::CurrentThread.GetApartmentState() -eq 'STA')
    {
        $FolderBrowser = New-Object 'System.Windows.Forms.FolderBrowserDialog'
        $FolderBrowser.RootFolder          = 'MyComputer'
        $FolderBrowser.Description         = $Description
        $FolderBrowser.ShowNewFolderButton = $ShowNewFolderButton
        If ([string]::IsNullOrEmpty($InitialDirectory) -eq $False) { $FolderBrowser.SelectedPath = $InitialDirectory }
        If ($FolderBrowser.ShowDialog($MainForm) -eq [System.Windows.Forms.DialogResult]::OK) { $return = $($FolderBrowser.SelectedPath) }
        Try { $FolderBrowser.Dispose() } Catch {}
    }
    Else
    {
        # Workaround for MTA not showing the dialog box.
        # Initial Directory is not possible when using the COM Object
        $Description  += "`nUnable to automatically select correct folder."
        $comObject     = New-Object -ComObject 'Shell.Application'
        $FolderBrowser = $comObject.BrowseForFolder(0, $Description, 512, '')    # 512 = No 'New Folder' button, '' = Initial folder (Desktop)
        If ([string]::IsNullOrEmpty($FolderBrowser) -eq $False) { $return = $($FolderBrowser.Self.Path) } Else { $return = '' }
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($comObject) | Out-Null    # Dispose COM object
    }
    Return $return
}

Function Get-File ( [string]$InitialDirectory, [string]$Title )
{
    [string]$return = ''
    $OpenFile = New-Object 'System.Windows.Forms.OpenFileDialog'
    $OpenFile.InitialDirectory = $InitialDirectory
    $OpenFile.Multiselect      = $True
    $OpenFile.Title            = $Title
    $OpenFile.Filter           = 'Compiled QA Scripts|*.ps1'
    If ([threading.thread]::CurrentThread.GetApartmentState() -ne 'STA') { $OpenFile.ShowHelp = $True }    # Workaround for MTA issues not showing dialog box
    If ($OpenFile.ShowDialog($MainFORM) -eq [System.Windows.Forms.DialogResult]::OK) { $return = ($OpenFile.FileName) }
    Try { $OpenFile.Dispose() } Catch {}
    Return $return
}

Function Save-File ( [string]$InitialDirectory, [string]$Title, [string]$InitialFileName )
{
    [string]$return = ''
    $SaveFile = New-Object 'System.Windows.Forms.SaveFileDialog'
    $SaveFile.InitialDirectory = $InitialDirectory
    $SaveFile.Title            = $Title
    $SaveFile.FileName         = $InitialFileName
    $SaveFile.Filter           = 'QA Configuration Settings|*.ini'
    If ([threading.thread]::CurrentThread.GetApartmentState() -ne 'STA') { $SaveFile.ShowHelp = $True }    # Workaround for MTA issues not showing dialog box
    If ($SaveFile.ShowDialog($MainForm) -eq [System.Windows.Forms.DialogResult]::OK) { $return = ($SaveFile.FileName) }
    Try { $SaveFile.Dispose() } Catch {}
    Return $return
}

Function Load-ComboBox ( [System.Windows.Forms.ComboBox]$ComboBox, $Items, [string]$SelectedItem, [switch]$Clear )
{
    If ($Clear) { $ComboBox.Items.Clear() }
    If ($Items -is [Object[]]) { $ComboBox.Items.AddRange($Items) | Out-Null } Else { $ComboBox.Items.Add($Items) | Out-Null }
    If ([string]::IsNullOrEmpty($SelectedItem) -eq $False) { $ComboBox.SelectedItem = $SelectedItem }
}

Function Add-ListViewItem ( [System.Windows.Forms.ListView]$ListView, $Items, [int]$ImageIndex = -1, [string[]]$SubItems, [string]$Group, [switch]$Clear, [boolean]$Enabled )
{
    If ($Clear) { $ListView.Items.Clear(); }
    [System.Windows.Forms.ListViewGroup]$lvGroup = $null
    ForEach ($groupItem in $ListView.Groups) { If ($groupItem.Name -eq $Group) { $lvGroup = $groupItem; Break } }
    If ($lvGroup -eq $null) { $lvGroup = $ListView.Groups.Add($Group, "ERR: $Group") }

    [System.Windows.Forms.ListViewItem]$listitem = $ListView.Items.Add($Items.ToString(), $Items.ToString(), $ImageIndex)
    If ($SubItems -ne $null ) { $listitem.SubItems.AddRange($SubItems) }
    If ($lvGroup  -ne $null ) { $listitem.Group = $lvGroup }
    If (($Enabled -eq $false) -and ($listitem.Text -ne ' '))
    {
        $listitem.Font      =  $sysFontItalic
        $listitem.ForeColor = 'GrayText'
        $listitem.BackColor = 'Control'
        If ($listitem.ImageIndex -eq 1) { $listitem.ImageIndex = 2 } Else { $listitem.ImageIndex = -1 }
    }
}

Function Load-IniFile ( [string]$Inputfile )
{
    [string]   $comment = ";"
    [string]   $header  = "^\s*(?!$($comment))\s*\[\s*(.*[^\s*])\s*]\s*$"
    [string]   $item    = "^\s*(?!$($comment))\s*([^=]*)\s*=\s*(.*)\s*$"
    [hashtable]$ini     = @{}

    If ((Test-Path -Path $inputfile) -eq $False) { Return $null }
 
    Switch -Regex -File $inputfile {
        "$($header)" {
            $section = ($matches[1] -replace ' ','_')
            $ini[$section.Trim()] = @{}
        }
        "$($item)"   {
            $name, $value = $matches[1..2];
            If (($name -ne $null) -and ($section -ne $null)) { $ini[$section][$name.Trim()] = $value.Trim() }
        }
    }
    Return $ini
}

Function Get-DefaultINISettings
{
    [hashtable]$defaultINI = @{}
    [object[]] $folders    = (Get-ChildItem -Path "$script:scriptLocation\checks" | Where-Object { $_.PsIsContainer -eq $True } | Select-Object -ExpandProperty Name | Sort-Object Name )

    ForEach ($folder In ($folders | Sort-Object Name))
    {
        [object[]]$scripts = (Get-ChildItem -Path "$script:scriptLocation\checks\$folder" -Filter 'c-*.ps1' | Select-Object -ExpandProperty Name | Sort-Object Name )
        If ([string]::IsNullOrEmpty($scripts) -eq $False)
        {
            ForEach ($script In ($scripts | Sort-Object Name))
            {
                [string]$getContent = ((Get-Content -Path "$script:scriptLocation\checks\$folder\$script" -TotalCount 50) -join "`n")
                [string]$checkCode  = ($script.Substring(2, 6).Replace('-',''))    # Get check code: "c-acc-01-local-user.ps1"  -->  "acc01"

                # Get default state (ENABLED / SKIPPED)
                $regExE = [RegEx]::Match($getContent, "DEFAULT-STATE:((?:.|\s)+?)(?:(?:[A-Z\- ]+:\n)|(?:#>))")
                If ($regExE.Groups[1].Value.Trim() -ne 'Enabled') { $checkCode += '-skip' }

                # Add check
                $defaultINI[$checkCode] = @{}

                # Get default values
                $regExV = [RegEx]::Match($getContent, "DEFAULT-VALUES:((?:.|\s)+?)(?:(?:[A-Z\- ]+:\n)|(?:#>))")
                [string[]]$Values = ($regExV.Groups[1].Value.Trim()).Split("`n")
                If (([string]::IsNullOrEmpty($Values) -eq $false) -and ($Values -ne 'None'))
                {
                    ForEach ($EachValue In $Values) { $defaultINI[$checkCode][(($EachValue -split ' = ')[0]).Trim()] = (($EachValue -split ' = ')[1]).Trim() }
                }
            }
        }
    }
    Return $defaultINI
}
#endregion
###################################################################################################
##                                                                                               ##
##   Secondary Forms                                                                             ##
##                                                                                               ##
###################################################################################################
#region Secondary Forms
Function Show-InputForm
{
    Param
    (
        [parameter(Mandatory=$True )][string]  $Type,
        [parameter(Mandatory=$True )][string]  $Title,
        [parameter(Mandatory=$True )][string]  $Description,
        [parameter(Mandatory=$false)][string]  $Validation = 'None',
        [parameter(Mandatory=$false)][string[]]$InputList,
        [parameter(Mandatory=$false)][string[]]$CurrentValue,
        [parameter(Mandatory=$false)][string  ]$InputDescription = '',
        [parameter(Mandatory=$false)][int     ]$MaxNumberInputBoxes
    )

    # [ValidateSet('Simple', 'Check', 'Option', 'List', 'Large')]
    # [ValidateSet('None', 'AZ', 'Numeric', 'Integer', 'Decimal', 'Symbol', 'File', 'URL', 'Email', 'IPv4', 'IPv6')]

#region Form Scripts
    $ChkButton_Click = {
        If ($ChkButton.Text -eq 'Check All') { $ChkButton.Text = 'Check None'; [boolean]$checked = $True } Else { $ChkButton.Text = 'Check All'; [boolean]$checked = $False }
        ForEach ($Control In $frm_Input.Controls) { If ($control -is [System.Windows.Forms.CheckBox]) { $control.Checked = $checked } }
    }

    [int]$numberOfTextBoxes = 0
    $AddButton_Click = { AddButton_Click -Value '' -Override $false -Type 'TEXT' }
    Function AddButton_Click ( [string]$Value, [boolean]$Override, [string]$Type, [string]$ItemTip )
    {
        [int]$BoxNumber = 0
        ForEach ($Control In $frm_Input.Controls) { If (($Control -is [System.Windows.Forms.TextBox]) -or ($Control -is [System.Windows.Forms.CheckBox])) { $BoxNumber++ } }
        If ($BoxNumber -eq $MaxNumberInputBoxes) { $AddButton.Enabled = $false; Return }

        If ($Type -eq 'TEXT')
        {
            ForEach ($control In $frm_Input.Controls) {
                If ($control -is [System.Windows.Forms.TextBox]) {
                    [System.Windows.Forms.TextBox]$isEmtpy = $null
                    If ([string]::IsNullOrEmpty($control.Text) -eq $True) { $isEmtpy = $control; Break }
                }
            }

            If ($Override -eq $True) { $isEmtpy = $null } 
            If ($isEmtpy -ne $null)
            {
                $isEmtpy.Select()
                $isEmtpy.Text = $Value
                Return
            }
        }

        # Increase form size, move buttons down, add new field
        $numberOfTextBoxes++
        $frm_Input.ClientSize       = "394, $(147 + ($BoxNumber * 26))"
        $btn_Accept.Location        = "307, $(110 + ($BoxNumber * 26))"
        $btn_Cancel.Location        = "220, $(110 + ($BoxNumber * 26))"

        If ($Type -eq 'TEXT')
        {
            $AddButton.Location     = " 39, $(110 + ($BoxNumber * 26))"

            # Add new counter label
            $labelCounter           = New-Object 'System.Windows.Forms.Label'
            $labelCounter.Location  = " 12, $(75 + ($BoxNumber * 26))"
            $labelCounter.Size      = ' 21,   20'
            $labelCounter.Font      = $sysFont
            $labelCounter.Text      = "$($BoxNumber + 1):"
            $labelCounter.TextAlign = 'MiddleRight'
            $frm_Input.Controls.Add($labelCounter)

            # Add new text box and select it for focus
            $textBox                = New-Object 'System.Windows.Forms.TextBox'
            $textBox.Location       = " 39, $(75 + ($BoxNumber * 26))"
            $textBox.Size           = '343,   20'
            $textBox.Font           = $sysFont
            $textBox.Name           = "textBox$BoxNumber"
            $textBox.Text           = $Value.Trim()
            $frm_Input.Controls.Add($textBox)
            $frm_Input.Controls["textbox$BoxNumber"].Select()
        }
        ElseIf ($Type -eq 'CHECK')
        {
            # Add new check box
            $chkBox                 = New-Object 'System.Windows.Forms.CheckBox'
            $chkBox.Location        = " 12, $(75 + ($BoxNumber * 26))"
            $chkBox.Size            = '370,   20'
            $chkBox.Font            = $sysFont
            $chkBox.Name            = "chkBox$BoxNumber"
            $chkBox.Text            = $Value + $ItemTip
            $chkBox.TextAlign       = 'MiddleLeft'
            $frm_Input.Controls.Add($chkBox)
            $frm_Input.Controls["chkbox$BoxNumber"].Select()
        }
        Else { }
    }

    Function Change-Form ( [string]$ChangeTo )
    {
        If ($Type -eq 'Large')
        {
            # Hide Fields
            $pic_InvalidValue.Visible = $False

            # Show Fields
            $textBox.Visible          = $True
            $textBox.Select()

            # Resize form
            $frm_Input.ClientSize     = "394, $(147 + 104)"
            $btn_Accept.Location      = "307, $(110 + 104)"
            $btn_Cancel.Location      = "220, $(110 + 104)"
        }
        Else
        {
            # Hide Fields
            $pic_InvalidValue.Visible = $False

            # Show Fields
            $textBox.Visible          = $True
            $textBox.Select()

            # Resize form
            $frm_Input.ClientSize     = '394, 147'
            $btn_Accept.Location      = '307, 110'
            $btn_Cancel.Location      = '220, 110'
        }
    }

    # Start form validation and make sure everything entered is correct
    $btn_Accept_Click = {
        [string[]]$currentValues  = @('')
        [boolean] $ValidatedInput = $True

        ForEach ($Control In $frm_Input.Controls)
        {
            If (($Control -is [System.Windows.Forms.TextBox]) -and ($Control.Visible -eq $True))
            {
                $Control.BackColor = 'Window'
                If (($Type -eq 'LIST') -and ($Control.Text.Contains(';') -eq $True))
                {
                    [string[]]$ControlText = ($Control.Text).Split(';')
                    $Control.Text = ''    # Remove current data so that it can be used as a landing control for the split data
                    ForEach ($item In $ControlText) { AddButton_Click -Value $item -Override $false -Type 'TEXT' }
                }
            }
        }

        # Reset Control Loop for any new fields that may have been added
        ForEach ($Control In $frm_Input.Controls)
        {
            If (($Control -is [System.Windows.Forms.TextBox]) -and ($Control.Visible -eq $True))
            {
                $ValidatedInput = $(ValidateInputBox -Control $Control)
                $pic_InvalidValue.Image = $img_Input.Images[0]
                $pic_InvalidValue.Tag   = 'Validation failed for current value'
                $ToolTip.SetToolTip($pic_InvalidValue, $pic_InvalidValue.Tag)

                If ($ValidatedInput -eq $True)
                {
                    If (($Type -eq 'LIST') -and (([string]::IsNullOrEmpty($Control.Text) -eq $false) -and ($currentValues -contains ($Control.text))))
                    {
                        $ValidatedInput = $false
                        $pic_InvalidValue.Image = $img_Input.Images[1]
                        $pic_InvalidValue.Tag   = 'Duplicated value found'
                        $ToolTip.SetToolTip($pic_InvalidValue, $pic_InvalidValue.Tag)
                        $Control.BackColor = 'Info'
                    }
                    Else { $currentValues += $Control.Text }
                }

                If ($ValidatedInput -eq $false)
                {
                    $pic_InvalidValue.Location = "331, $([math]::Round(($Control.Height -16) / 2) + $Control.Top)"    # 331 = $($($Control.Left) + $($Control.Width) - (48 + 3))
                    $pic_InvalidValue.Visible  = $True
                    $Control.Focus()
                    $Control.SelectAll()
                    $ToolTip.Show($pic_InvalidValue.Tag, $pic_InvalidValue, 36, 12, 2500)
                    $Control.BackColor = 'Info'
                    Break
                }
            }
        }

        $currentValues = $null
        If ($ValidatedInput -eq $True) { $frm_Input.DialogResult = [System.Windows.Forms.DialogResult]::OK }
    }

    Function ValidateInputBox ([System.Windows.Forms.Control]$Control)
    {
        $Control.Text = ($Control.Text.Trim())
        [boolean]$ValidateResult = $false
        [string] $StringToCheck  = $($Control.Text)

        # Ignore for LARGE fields
        If ($Type -eq 'LARGE') { Return $True }

        # Ignore control if empty
        If ([string]::IsNullOrEmpty($StringToCheck) -eq $True) { Return $True }

        # Validate
        Switch ($Validation)
        {
            'AZ'      { $ValidateResult = ($StringToCheck -match "^[A-Za-z]+$");            Break }              # Letters only (A-Za-z)
            'Numeric' { $ValidateResult = ($StringToCheck -match '^(-)?([\d]+)?\.?[\d]+$'); Break }              # Both integer and decimal numbers
            'Integer' { $ValidateResult = ($StringToCheck -match '^(-)?[\d]+$');            Break }              # Integer numbers only
            'Decimal' { $ValidateResult = ($StringToCheck -match '^(-)?[\d]+\.[\d]+$');     Break }              # Decimal numbers only
            'Symbol'  { $ValidateResult = ($StringToCheck -match '^[^A-Za-z0-9]+$');        Break }              # Any symbol (not numbers or letters)
            'File'    {                                                                                          # Valid file or folder name
                $StringToCheck  = $StringToCheck.TrimEnd('\')
                $ValidateResult = ($StringToCheck -match "^(?:[a-zA-Z]\:|\\\\[\w\.]+\\[\w.$]+)\\(?:[\w]+\\)*\w([\w.])+$")
                Break
            }
            'URL'     {                                                                                          # URL
                [url]    $url       = ''
                [boolean]$ValidURL1 = ($StringToCheck -match '^(ht|(s)?f|)tp(s)?:\/\/(.*)\/([a-z]+\.[a-z]+)')    # http(s):// or (s)ftp(s)://
                [boolean]$ValidURL2 = ([System.Uri]::TryCreate($StringToCheck, [System.UriKind]::Absolute, [ref]$url))
                $ValidateResult     = ($ValidURL1 -and $ValidURL2)
                Break
            }
            'Email'   {                                                                                          # email@address.validation
                Try   { $ValidateResult = (($StringToCheck -as [System.Net.Mail.MailAddress]).Address -eq $StringToCheck) }
                Catch { $ValidateResult =   $false }
                Break
            }
            'IPv4'    {                                                                                          # IPv4 address (1.2.3.4)
                [boolean]$Octets  = (($StringToCheck.Split('.') | Measure-Object).Count -eq 4)
                [boolean]$ValidIP =  ($StringToCheck -as [ipaddress]) -as [boolean]
                $ValidateResult   =  ($ValidIP -and $Octets)
                Break
            }
            'IPv6'    {                                                                                          # IPv6 address (REGEX from 'https://www.powershellgallery.com/packages/IPv6Regex/1.1.1')
                [string]$IPv6 = @"
                    ^((([0-9a-f]{1,4}:){7}([0-9a-f]{1,4}|:))|(([0-9a-f]{1,4}:){6}(:[0-9a-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9])|:))|(([0-9a-f]
                    {1,4}:){5}(((:[0-9a-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9])|:))|(([0-9a-f]{1,4}:){4}(((:[0-9a-f]{1,4}){1,3})|((:[0-9a-f]
                    {1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9]))|:))|(([0-9a-f]{1,4}:){3}(((:[0-9a-f]{1,4}){1,4})|((:[0-9a-f]{1,4}){0,2}:((25[0-5]|
                    2[0-4]\d|1\d\d|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9]))|:))|(([0-9a-f]{1,4}:){2}(((:[0-9a-f]{1,4}){1,5})|((:[0-9a-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]
                    ?[0-9])\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9]))|:))|(([0-9a-f]{1,4}:){1}(((:[0-9a-f]{1,4}){1,6})|((:[0-9a-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9])\.){3}(25[0-5]|
                    2[0-4]\d|1\d\d|[1-9]?[0-9]))|:))|(:(((:[0-9a-f]{1,4}){1,7})|((:[0-9a-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9]))|:)))$
"@
                $ValidateResult = ($StringToCheck -match $IPv6)
                Break
            }
            Default   {                                                                                          # No Validation
                $ValidateResult = $True
            }
        }
        Return $ValidateResult
    }

    $frm_Input_Cleanup_FormClosed = {
        Try {
            $btn_Accept.Remove_Click($btn_Accept_Click)
            $AddButton.Remove_Click($AddButton_Click)
        } Catch {}
        $frm_Input.Remove_FormClosed($frm_Input_Cleanup_FormClosed)
    }
#endregion
#region Input Form Controls
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $frm_Input = New-Object 'System.Windows.Forms.Form'
    $frm_Input.FormBorderStyle      = 'FixedDialog'
    $frm_Input.MaximizeBox          = $False
    $frm_Input.MinimizeBox          = $False
    $frm_Input.ControlBox           = $False
    $frm_Input.Text                 = " $Title"
    $frm_Input.ShowInTaskbar        = $False
    $frm_Input.AutoScaleDimensions  = '6, 13'
    $frm_Input.AutoScaleMode        = 'None'
    $frm_Input.ClientSize           = '394, 147'    # 400 x 175
    $frm_Input.StartPosition        = 'CenterParent'

    $ToolTip                       = New-Object 'System.Windows.Forms.ToolTip'

    # 48x16 Image List for INVALID and DUPLICATE error message icons
    $img_Input                     = New-Object 'System.Windows.Forms.ImageList'
	$img_Input.TransparentColor    = 'Transparent'
	$img_Input_binaryFomatter      = New-Object 'System.Runtime.Serialization.Formatters.Binary.BinaryFormatter'
	$img_Input_MemoryStream        = New-Object 'System.IO.MemoryStream' (,[byte[]][System.Convert]::FromBase64String('
        AAEAAAD/////AQAAAAAAAAAMAgAAAFdTeXN0ZW0uV2luZG93cy5Gb3JtcywgVmVyc2lvbj00LjAuMC4wLCBDdWx0dXJlPW5ldXRyYWwsIFB1YmxpY0tleVRva2VuPWI3N2E1YzU2MTkzNGUwODkFAQAAACZTeXN0ZW0uV2luZG93cy5Gb3Jtcy5JbWFnZUxpc3RTdHJlYW1lcgEAAAAERGF0YQcCAgAAAAkD
        AAAADwMAAADkCgAAAk1TRnQBSQFMAgEBAgEAAQgBAAEIAQABMAEAARABAAT/ASEBAAj/AUIBTQE2BwABNgMAASgDAAHAAwABEAMAAQEBAAEgBgABMP8A/wD/AP8AGgADNAFxAzQBiP8A/wD6AAMyAZkDKwG2/wD/APoAAzIBmQMrAbb/AP8ANgADNAGPAzUBeQQAAy0BUAMvAaoEAAM1AXkDNQGBCAADEQEX
        AywBswwAAyMBNgMqAboDMwFqAygBvwMcASgDDgESAygBvwMcASgDDgESAygBvwMcASgEAAMxAV0DKgG6AzMBZwMoAb8YAAMtAbEDKAG/AysBuAMxAVsMAAM1AX4DKAG/AzEBowMRARYEAAMyAZkDKQG8AzIBmQMwAaYDCAEKBAADMQGiAy8BVwQAAzEBogMvAVcEAAMaASUDLQGvAy0BsgMNBBEBFgMvAaoD
        NAGIAzEBogMvAVcEAAMxAV4DMwGaCAADHwEuAysBtQMvAaoDFwEg/wDFAAMoAb8DMQGjBAADNAFsAxQB4wQAAzEBowMuAa0IAAMxAVsDAAH/AxwBKQgAAyAB0AMrAbUDNQGDAwAB/wMjATUDEgEYAwAB/wMjATUDEgEYAwAB/wMjATUDCwEOAwQB+gM0AY8DLwGsAwAB/xgAAw8B7AM0AZEDNAF1AwIB/AMy
        AWIEAAMrAUkDBAH6AywBTAMdAdYDNAGNBAADMgGZAwsB8AMtAVADBgH4AzMBaQQAAxsB2AM0AXUEAAMbAdgDNAF1BAADKQG7Ax8B0QMqAUcDDQERAzQBkAMUAeUDLwFVAwIB/AM0AXUEAAM1AX4DIQHNCAADGAHeAzQBkgMzAZcDLAG0/wDFAAMoAb8DMQGjBAADNAFsAxQB4wQAAzEBowMuAa0IAAMyAZ4D
        EAHrAzMBawgAAwQB+gMzAWkDGAEiAwAB/wMjATUDEgEYAwAB/wMjATUDEgEYAwAB/wMjATUDIQExAwAB/wMiATMDMQFfAwAB/xgAAw8B7AM0AWwEAAMtAbIDJgHCBAADNAFsAxQB4wQAAzEBowMuAa0EAAMyAZkDJAHGBAADIwHJAzMBmAQAAxsB2AM0AXUEAAMbAdgDNAF1BAADCAH1AzQBcAgAAyoBugMv
        AaoEAAMUAeMDNAF1BAADNQF+AyEBzQQAAxUBHQMAAf8DIwE1AyMBNgMvAaz/AMUAAygBvwMxAaMEAAM0AWwDFAHjBAADMQGjAy4BrQgAAxQB5AM0AY0DLQGwBAADBwEJAwAB/wMwAVoDEgEYAwAB/wMjATUDEgEYAwAB/wMjATUDEgEYAwAB/wMjATUDIwE1AwAB/wMbAScDLAFNAwAB/xgAAw8B7AM0AWwE
        AAM1AXcDDAHvBAADNAFsAxQB4wQAAzEBowMuAa0EAAMyAZkDKwG4BAADKwG2AzEBowQAAxsB2AM0AXUEAAMbAdgDNAF1AwcBCQMAAf8DMgFiCAADIwHKAzIBmwQAAxsB2AM0AXUEAAM1AX4DIQHNBAADHwEuAwAB/wMzAZYDNQF+AzUBfv8AxQADKAG/AzEBowQAAzQBbAMUAeMEAAMxAaMDLgGtBAADGwEm
        AwgB9QMfAS0DDQHuCAIDAAH/AzEBXQMSARgDAAH/AyMBNQMSARgDAAH/AyMBNQMSARgDAAH/AyMBNQMiATMDAAH/Ax4BLAMtAVADAAH/GAADDwHsAzQBbAQAAzMBZwMAAf8EAgM0AWwDFAHjBAADMQGjAy4BrQQAAzIBmQMrAbgEAAMpAb0DMgGgBAADGwHYAzQBdQQAAxsB2AM0AXUDBQEGAwIB/AMyAWUI
        AAMmAcIDMgGeBAADGwHYAzQBdQQAAzUBfgMhAc0EAAMbAScDAAH/AzMBlgMwAaYDBAH6/wDFAAMoAb8DMQGjBAADNAFsAw8B7AQAAy8BqAMuAa0EAAMzAWsDJgHEBAIDCwHxAyEBMgQAAxIB5wM1AXsDIgE0AwAB/wMjATUDEgEYAwAB/wMjATUDEgEYAwAB/wMjATUDFwEgAwAB/wMrAUkDMwFpAwAB/xgA
        Aw8B7AM0AWwEAAMyAWIDAAH/AwcBCQM0AWwDFAHjBAADMQGjAy4BrQQAAzIBmQMeAdQEAAMXAd8DNAGHBAADGwHYAzQBdQQAAxsB2AM0AXUEAAMYAd4DMgGZCAADMAGnAykBvAQCAwsB8QM0AXUEAAM1AX4DIQHNBAADBAEFAwgB9QMnAT0DMQFdAxgB3f8AxQADKAG/AzEBowQAAzQBbAMLAfEDJwHAAwQB
        +gM1AYAEAAMtAbIDNAGQBAADKAG+AzQBdgQAAzQBlAMKAfIDKQG9AwAB/wMjATUDEgEYAwAB/wMjATUDEgEYAwAB/wMjATUEAAMiAcsDFAHlAyUBxQMAAf8YAAMPAewDNAFsBAADNAFsAwQB+gQAAzQBbAMUAeMEAAMxAaMDLgGtBAADMgGZAxcB3wMjAcoDAgH8AyMBNgQAAxsB2AM0AXUEAAMbAdgDNAF1
        BAADMgFhAwIB/AMkAcgDGQEjAy4BVAMAAf8DJgHEAxAB6wM0AXUDKAFBAxcB3wMKAfIDNQF5BAADNQGBAykBuwMjAcoDNAF0/wDFAAMoAb8DMQGjBAADEwEaAyQBNwMTARoDJQE6CAADIwE1AxMBGgQAAxsBJwMbAScIAAMnAT4DDwETAycBPgMJAQwDEgEYAwAB/wMjATUDBAEFAycBPgMJAQwEAAMIAQoD
        JgE8AywBTQMAAf8YAAMPAewDNAFsBAADNQGJAxgB3QQAAxMBGgMkATcEAAMbAScDHQEqBAADGgElAx0BKgMYASIDGwEnCAADGwHYAzQBdQQAAyMBNQMVARwIAAMbAScDHwEuCAADHwEuAxUBHAMjATUDFQEcAxABFQMxAZ8DGwHaAxsBJwgAAx8BLgMdASr/AMkAAygBvwMxAaNIAAMSARgDAAH/AyMBNQQA
        AyEBMhAAAywBTQMAAf8YAAMPAewDNAFsAwgBCgMaAdkDMgGZNAADGwHYAzQBdQQAAxoBJQMJAQwsAAM1AX4DIQHN/wDdAAMoAb8DMQGjSAADEgEYAwAB/wMjATUDEgEYAwAB/wMjATUMAAMsAU0DAAH/GAADDwHsAxsB2gMUAeUDHQHVAxIBGDQAAxsB2AM0AXUEAAMbAdgDNAF1/wD/ABIAAx8BLgMbASdI
        AAMOARIDKAG/AxwBKAQAAyEBMhAAAyUBOQMoAb8YAAMlAToDJwE+AyUBOjwAAzEBogMvAVcEAAMaASUDCQEM/wD/AP8A/wDUAAFCAU0BPgcAAT4DAAEoAwABwAMAARADAAEBAQABAQUAAYABARYAA/8BAAz/DAAI/wGfA/8MAAj/AZ8D/wwACP8BnwP/DAAC/wEkAc4BAAEhAfgBcAGCAUgBAgFhDAAC/wEk
        AcYBAAEBAfgBIAGCAUgBAgFhDAAC/wEkAcYBAAEBAfkBJAGSAUkBkgFBDAAC/wEkAcQBAAEBAfkBJAGSAUEBkgFBDAAC/wEkAYABAAEBAfkBBAGSAUEBkgFBDAAC/wEkAYIBAAEBAfkBBAGSAUkBggFBDAAC/wEgAZIBAAEhAfkBJAGCAUgBAAEhDAAC/wEhAZMBAAEhAfkBJAGGAUwBwAEzDAAC/wE/Af8B
        8QF5AfgBPwH+AU8B/gF/DAAC/wE/Af8B8AE5AfgBPwH+AU8C/wwAAv8BPwH/AfEBeQH4Af8B/gFPAv8MAAz/DAAL'))
	$img_Input.ImageStream         = $img_Input_binaryFomatter.Deserialize($img_Input_MemoryStream)
	$img_Input_binaryFomatter      = $null
	$img_Input_MemoryStream        = $null

    $pic_InvalidValue              = New-Object 'System.Windows.Forms.PictureBox'
    $pic_InvalidValue.BackColor    = 'Info'
    $pic_InvalidValue.Location     = '  0,   0'
    $pic_InvalidValue.Size         = ' 48,  16'
    $pic_InvalidValue.Visible      = $false
    $pic_InvalidValue.TabStop      = $False
    $pic_InvalidValue.BringToFront()
    $frm_Input.Controls.Add($pic_InvalidValue)

    $lbl_Description               = New-Object 'System.Windows.Forms.Label'
    $lbl_Description.Location      = ' 12,  12'
    $lbl_Description.Size          = '370,  48'
    $lbl_Description.Font          = $sysFont
    $lbl_Description.Text          = $($Description.Trim())
    $frm_Input.Controls.Add($lbl_Description)

    If ($Validation -ne 'None')
    {
        $lbl_Validation            = New-Object 'System.Windows.Forms.Label'
        $lbl_Validation.Location   = '212,  60'
        $lbl_Validation.Size       = '170,  15'
        $lbl_Validation.Font       = $sysFont
        $lbl_Validation.Text       = "Validation: $($Validation.ToUpper())"
        $lbl_Validation.TextAlign  = 'BottomRight'
        $frm_Input.Controls.Add($lbl_Validation)
    }

    $btn_Accept                    = New-Object 'System.Windows.Forms.Button'
    $btn_Accept.Location           = '307, 110'
    $btn_Accept.Size               = ' 75,  25'
    $btn_Accept.Font               = $sysFont
    $btn_Accept.Text               = 'OK'
    $btn_Accept.TabIndex           = '97'
    $btn_Accept.Add_Click($btn_Accept_Click)
    If ($Type -ne 'LARGE') { $frm_Input.AcceptButton = $btn_Accept }
    $frm_Input.Controls.Add($btn_Accept)

    $btn_Cancel                    = New-Object 'System.Windows.Forms.Button'
    $btn_Cancel.Location           = '220, 110'
    $btn_Cancel.Size               = ' 75,  25'
    $btn_Cancel.Font               = $sysFont
    $btn_Cancel.Text               = 'Cancel'
    $btn_Cancel.TabIndex           = '98'
    $btn_Cancel.DialogResult       = [System.Windows.Forms.DialogResult]::Cancel
    $frm_Input.CancelButton         = $btn_Cancel
    $frm_Input.Controls.Add($btn_Cancel)
    $frm_Input.Add_FormClosed($frm_Input_Cleanup_FormClosed)
#endregion
#region Input Form Controls Part 2
    [string]$ItemTip = ''
    Switch ($Type)
    {
        'LIST' {
            # List of text boxes
            [int]$itemCount = ($CurrentValue.Count)
            If ($itemCount -ge 5) { [int]$numberOfTextBoxes = $itemCount + 1 } Else { [int]$numberOfTextBoxes = 5 }
            $numberOfTextBoxes--    # Count from zero

            # Add 'Add' button
            $AddButton              = New-Object 'System.Windows.Forms.Button'
            $AddButton.Location     = " 39, $(110 + ($numberOfTextBoxes * 26))"
            $AddButton.Size         = ' 75,   25'
            $AddButton.Font         = $sysFont
            $AddButton.Text         = 'Add'
            $AddButton.Add_Click($AddButton_Click)
            $frm_Input.Controls.Add($AddButton)

            # Add initial textboxes
            For ($i = 0; $i -le $numberOfTextBoxes; $i++) { AddButton_Click -Value ($CurrentValue[$i]) -Override $True -Type 'TEXT' }
            $frm_Input.Controls['textbox0'].Select()
            Break
        }

        'CHECK' {
            # Add 'Check All' button
            $ChkButton              = New-Object 'System.Windows.Forms.Button'
            $ChkButton.Location     = " 12, $(110 + (($InputList.Count -1) * 26))"
            $ChkButton.Size         = '125,   25'
            $ChkButton.Font         = $sysFont
            $ChkButton.Text         = 'Check All'
            $ChkButton.Add_Click($ChkButton_Click)
            $frm_Input.Controls.Add($ChkButton)

            # Add initial textboxes
            [int]$i = 0
            If ($InputDescription -ne '') { For ($x=0;$x-lt$InputList.Count;$x++) { ForEach ($iDec In $InputDescription.Split('|')) { If ($iDec.StartsWith($InputList[$x] + ': ') -eq $true) { $InputList[$x] = $iDec } } } }
            ForEach ($item In $InputList)
            {
                AddButton_Click -Value ($item.Trim()) -Override $True -Type 'CHECK'
                If ([string]::IsNullOrEmpty($CurrentValue) -eq $false) { If ($CurrentValue.Contains($item.Split(':')[0].Trim())) { $frm_Input.Controls["chkBox$i"].Checked = $True } }
                $i++
            }
            Break
        }

        'OPTION' {
            # Drop down selection list
            If ($InputDescription -ne '') { For ($x=0;$x-lt$InputList.Count;$x++) { ForEach ($iDec In $InputDescription.Split('|')) { If ($iDec.StartsWith($InputList[$x] + ': ') -eq $true) { $InputList[$x] = $iDec } } } }

            $comboBox               = New-Object 'System.Windows.Forms.ComboBox'
            $comboBox.Location      = ' 12,  75'
            $comboBox.Size          = '370,  21'
            $comboBox.Font          = $sysFont
            $comboBox.DropDownStyle = 'DropDownList'
            $frm_Input.Controls.Add($comboBox)
            $comboBox.Items.AddRange(($InputList.Trim())) | Out-Null
            $frm_Input.Add_Shown({$comboBox.Select()})
            $comboBox.SelectedIndex = -1
            ForEach ($item In $InputList) { If ([string]::IsNullOrEmpty($CurrentValue) -eq $false) { if ($CurrentValue[0].Contains($item.Split(':')[0].Trim())) { $comboBox.SelectedItem = $item } } }
            Break
        }

        'LARGE' {
            # Multi-line text entry
            $textBox                = New-Object 'System.Windows.Forms.TextBox'
            $textBox.Location       = ' 12,  75'
            $textBox.Size           = '370, 124'
            $textBox.Font           = $sysFont
            $textBox.Multiline      = $True
            $textBox.ScrollBars     = 'Vertical'
            $frm_Input.Controls.Add($textBox)
            $frm_Input.Add_Shown({$textBox.Select()})
            $textBox.Select()

            # Resize form
            $frm_Input.Height      += 104                    # 
            $btn_Accept.Location    = "307, $(110 + 104)"    # 104 comes from 4 x 26
            $btn_Cancel.Location    = "220, $(110 + 104)"    #
            Break
        }

        'SIMPLE' {
            # Add default text box
            $textBox                = New-Object 'System.Windows.Forms.TextBox'
            $textBox.Location       = ' 12,  75'
            $textBox.Size           = '370,  20'
            $textBox.Font           = $sysFont
            $frm_Input.Controls.Add($textBox)
            $textBox.Select()
            Break
        }
        Default { Write-Warning "Invalid Input Form Type: $Type" }
    }

    If (('SIMPLE', 'LARGE') -contains $Type)
    {
        If ([string]::IsNullOrEmpty($CurrentValue) -eq $false) { $textBox.Text = (($CurrentValue.Trim()) -join "`r`n") }
        Change-Form -ChangeTo 'Simple' | Out-Null
    }
#endregion
#region Show Form And Return Value
    ForEach ($control In $frm_Input.Controls) { $control.Font = $sysFont; Try { $control.FlatStyle = 'Standard' } Catch {} }
    $result = $frm_Input.ShowDialog($MainForm)

    If ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        Switch ($Type)
        {
            'LIST'   {
                [string[]]$return = @()
                ForEach ($control In $frm_Input.Controls) { If ($control -is [System.Windows.Forms.TextBox]) {
                    If ([string]::IsNullOrEmpty($control.Text) -eq $false) { $return += ($($control.Text.Trim())) } }
                } Return $return
            }
            'CHECK'  {
                [string[]]$return = @()
                ForEach ($Control In $frm_Input.Controls) { If ($control -is [System.Windows.Forms.CheckBox]) {
                    If ($control.Checked -eq $True) { $return += ($($control.Text.Split(':')[0].Trim())) } }
                } Return $return
            }
            'LARGE'  {
                Do { [string]$return = $($textBox.Text.Trim()).Replace("`r`n", ' ') }
                While ( $return.IndexOf("`r`n") -gt -1 ); Return ($return.Trim("`r`n"))
            }
            'SIMPLE' {
                Do { [string]$return = $($textBox.Text.Trim()).Replace("`r`n", ' ') }
                While ( $return.IndexOf("`r`n") -gt -1 ); Return ($return.Trim("`r`n"))
            }
            'OPTION' { Return $($comboBox.SelectedItem.Split(':')[0].Trim()) }
            Default  { Return "Invalid return type: $Type" }
        }
    }
    ElseIf ($result -eq [System.Windows.Forms.DialogResult]::Cancel) { Return '!!-CANCELLED-!!' }
#endregion
}

Function Show-ExtraSettingsForm
{
    Param
    (
        [parameter(Mandatory=$false)][string]$Timeout,
        [parameter(Mandatory=$false)][string]$Concurrent,
        [parameter(Mandatory=$false)][string]$OutputLocation
    )

#region MAIN FORM
    $frm_Extra = New-Object 'System.Windows.Forms.Form'
    $frm_Extra.FormBorderStyle      = 'FixedDialog'
    $frm_Extra.MaximizeBox          = $False
    $frm_Extra.MinimizeBox          = $False
    $frm_Extra.ControlBox           = $False
    $frm_Extra.Text                 = ' Additional Settings'
    $frm_Extra.ShowInTaskbar        = $False
    $frm_Extra.AutoScaleDimensions  = '6, 13'
    $frm_Extra.AutoScaleMode        = 'None'
    $frm_Extra.ClientSize           = '444, 222'    # 450 x 250
    $frm_Extra.StartPosition        = 'CenterParent'

    $lbl_Description               = New-Object 'System.Windows.Forms.Label'
    $lbl_Description.Location      = ' 12,  12'
    $lbl_Description.Size          = '420,  33'
    $lbl_Description.Text          = 'This form allows you to set any additional settings that help control the QA scripts and its output.'
    $frm_Extra.Controls.Add($lbl_Description)

    $btn_Reset                     = New-Object 'System.Windows.Forms.Button'
    $btn_Reset.Location           = ' 12, 185'
    $btn_Reset.Size               = ' 75,  25'
    $btn_Reset.Font               = $sysFont
    $btn_Reset.Text               = 'Reset'
    $btn_Reset.TabIndex           = '99'
    $btn_Reset.Add_Click({ $cmo_Timeout.SelectedItem = '60'; $cmo_Concurrent.SelectedItem = '5'; $txt_Location.Text = '$env:SystemDrive\QA\Results\' })
    $frm_Extra.Controls.Add($btn_Reset)

    $btn_Accept                    = New-Object 'System.Windows.Forms.Button'
    $btn_Accept.Location           = '357, 185'
    $btn_Accept.Size               = ' 75,  25'
    $btn_Accept.Font               = $sysFont
    $btn_Accept.Text               = 'Save'
    $btn_Accept.TabIndex           = '97'
    $btn_Accept.DialogResult       = [System.Windows.Forms.DialogResult]::OK
    $frm_Extra.AcceptButton         = $btn_Accept
    $frm_Extra.Controls.Add($btn_Accept)

    $btn_Cancel                    = New-Object 'System.Windows.Forms.Button'
    $btn_Cancel.Location           = '267, 185'
    $btn_Cancel.Size               = ' 75,  25'
    $btn_Cancel.Font               = $sysFont
    $btn_Cancel.Text               = 'Cancel'
    $btn_Cancel.TabIndex           = '98'
    $btn_Cancel.DialogResult       = [System.Windows.Forms.DialogResult]::Cancel
    $frm_Extra.CancelButton         = $btn_Cancel
    $frm_Extra.Controls.Add($btn_Cancel)
#endregion
#region OPTIONS
    # Option 1
    $lbl_TimeOut1                  = New-Object 'System.Windows.Forms.Label'
    $lbl_TimeOut1.Location         = ' 12,  66'
    $lbl_TimeOut1.Size             = '150,  21'
    $lbl_TimeOut1.Text             = 'Check Timeout :'
    $lbl_TimeOut1.TextAlign        = 'MiddleRight'
    $frm_Extra.Controls.Add($lbl_Timeout1)

    [string[]]$TimeOutList         = @('30','45','60','75','90','120')
    $cmo_TimeOut                   = New-Object 'System.Windows.Forms.ComboBox'
    $cmo_TimeOut.Location          = '168,  66'
    $cmo_TimeOut.Size              = ' 50,  21'
    $cmo_TimeOut.DropDownStyle     = 'DropDownList'
    $frm_Extra.Controls.Add($cmo_TimeOut)
    $cmo_TimeOut.Items.AddRange($TimeOutList) | Out-Null
    $cmo_TimeOut.SelectedItem      = '60'
    If ($Timeout -ne '') { $cmo_TimeOut.SelectedItem = $Timeout }

    $lbl_TimeOut2                  = New-Object 'System.Windows.Forms.Label'
    $lbl_TimeOut2.Location         = '224,  66'
    $lbl_TimeOut2.Size             = '208,  21'
    $lbl_TimeOut2.Text             = 'Seconds'
    $lbl_TimeOut2.TextAlign        = 'MiddleLeft'
    $frm_Extra.Controls.Add($lbl_TimeOut2)

    # Option 2
    $lbl_Concurrent1               = New-Object 'System.Windows.Forms.Label'
    $lbl_Concurrent1.Location      = ' 12, 102'
    $lbl_Concurrent1.Size          = '150,  21'
    $lbl_Concurrent1.Text          = 'Check Concurrency :'
    $lbl_Concurrent1.TextAlign     = 'MiddleRight'
    $frm_Extra.Controls.Add($lbl_Concurrent1)

    [string[]]$ConCurrentList      = @('2', '3', '4', '5', '7', '10', '15')
    $cmo_Concurrent                = New-Object 'System.Windows.Forms.ComboBox'
    $cmo_Concurrent.Location       = '168, 102'
    $cmo_Concurrent.Size           = ' 50,  21'
    $cmo_Concurrent.DropDownStyle  = 'DropDownList'
    $frm_Extra.Controls.Add($cmo_Concurrent)
    $cmo_Concurrent.Items.AddRange($ConCurrentList) | Out-Null
    $cmo_Concurrent.SelectedItem   = '5'
    If ($Concurrent -ne '') { $cmo_Concurrent.SelectedItem = $Concurrent }

    $lbl_Concurrent2               = New-Object 'System.Windows.Forms.Label'
    $lbl_Concurrent2.Location      = '225, 102'
    $lbl_Concurrent2.Size          = '208,  21'
    $lbl_Concurrent2.Text          = 'At a time'
    $lbl_Concurrent2.TextAlign     = 'MiddleLeft'
    $frm_Extra.Controls.Add($lbl_Concurrent2)

    # Option 3
    $lbl_Location                  = New-Object 'System.Windows.Forms.Label'
    $lbl_Location.Location         = ' 12, 138'
    $lbl_Location.Size             = '150,  20'
    $lbl_Location.Text             = 'Report Location :'
    $lbl_Location.TextAlign        = 'MiddleRight'
    $frm_Extra.Controls.Add($lbl_Location)

    $txt_Location                  = New-Object 'System.Windows.Forms.Textbox'
    $txt_Location.Location         = '168, 138'
    $txt_Location.Size             = '264,  20'
    $txt_Location.TextAlign        = 'Left'
    If ($OutputLocation -ne '') { $txt_Location.Text = $OutputLocation } Else { $txt_Location.Text = '$env:SystemDrive\QA\Results\' }
    $frm_Extra.Controls.Add($txt_Location)
#endregion
#region FORM STARTUP / SHUTDOWN
    $frm_Extra_Cleanup_FormClosed = {
        Try {
            $btn_Accept.Remove_Click($btn_Accept_Click)
        } Catch {}
        $frm_Extra.Remove_FormClosed($frm_Extra_Cleanup_FormClosed)
        $frm_Extra.Dispose()
    }

    ForEach ($control In $frm_Extra.Controls) { $control.Font = $sysFont; Try { $control.FlatStyle = 'Standard' } Catch {} }
    [string]$result = $frm_Extra.ShowDialog()

    If ($result -eq 'OK')
    {
        [psobject]$return = New-Object -TypeName PSObject -Property @{
            'Timeout'        = $cmo_TimeOut.Text.Trim();
            'Concurrent'     = $cmo_Concurrent.Text.Trim();
            'OutputLocation' = $txt_Location.Text.Trim();
        }
        Return $return
    }
    Else { Return $null }
#endregion
}
#endregion
###################################################################################################
##                                                                                               ##
##   Main Form                                                                                   ##
##                                                                                               ##
###################################################################################################
Function Display-MainForm
{
#region FORM STARTUP / SHUTDOWN
    $InitialFormWindowState        = New-Object 'System.Windows.Forms.FormWindowState'
    $MainFORM_StateCorrection_Load = { $MainForm.WindowState = $InitialFormWindowState }

    $MainFORM_Load = {
        # Change font to a nicer one
        ForEach ($control In $MainForm.Controls)                                        { $control.Font = $sysFont }
        ForEach ($tab     In $tab_Pages.TabPages) { ForEach ($control In $tab.Controls) { $control.Font = $sysFont } }
        Update-NavButtons

        # Set some specific fonts
        $lbl_t1_Welcome.Font         = $sysFontBold
        $lbl_t1_MissingFile.Font     = $sysFontItalic    # Hidden by default ("'default-settings.ini' file not found")
        $lbl_t2_CheckSelection.Font  = $sysFontBold
        $lbl_t3_ScriptSelection.Font = $sysFontBold
        $lbl_t4_Complete.Font        = $sysFontBold

        # Set some default sizes (due to theme/font sizes)
        $lbl_t1_Language.Height     = $cmo_t1_Language.Height
        $lbl_t1_SettingsFile.Height = $cmo_t1_SettingsFile.Height
        $lbl_t1_MissingFile.Height  = $cmo_t1_SettingsFile.Height
        $lbl_t4_ShortCode.Height    = $txt_t4_ShortCode.Height
        $lbl_t4_QAReport.Height     = $txt_t4_ReportTitle.Height
        $lbl_t4_ReportTitle.Height  = $txt_t4_ReportTitle.Height

        # Setup default views/messages
        $lbl_t3_NoChecks.Visible        = $True
        $lst_t2_SelectChecks.CheckBoxes = $False
        $lst_t2_SelectChecks.Groups.Add('ErrorGroup','Please Note')
        Add-ListViewItem -ListView $lst_t2_SelectChecks -Items '' -SubItems ('','')                                   -ImageIndex -1 -Group 'ErrorGroup' -Enabled $True
        Add-ListViewItem -ListView $lst_t2_SelectChecks -Items '' -SubItems ('Select your scripts location first','') -ImageIndex -1 -Group 'ErrorGroup' -Enabled $True
    }

    $MainFORM_FormClosing = [System.Windows.Forms.FormClosingEventHandler] {
        $quit = [System.Windows.Forms.MessageBox]::Show($MainFORM, 'Are you sure you want to exit this tool.?', ' Server QA Settings Configurator', 'YesNo', 'Question')
        If ($quit -eq 'No') { $_.Cancel = $True }
    }

    $Form_Cleanup_FormClosed = {
        $tab_Pages.Remove_SelectedIndexChanged($tab_Pages_SelectedIndexChanged)
        $btn_RestoreINI.Remove_Click($btn_RestoreINI_Click)
        $btn_t1_Search.Remove_Click($btn_t1_Search_Click)
        $btn_t1_Import.Remove_Click($btn_t1_Import_Click)
        $btn_t2_SetValues.Remove_Click($btn_t2_SetValues_Click)
        $lst_t2_SelectChecks.Remove_Enter($lst_t2_SelectChecks_Enter)
        $lst_t2_SelectChecks.Remove_ItemChecked($lst_t2_SelectChecks_ItemChecked)
        $lst_t2_SelectChecks.Remove_SelectedIndexChanged($lst_t2_SelectChecks_SelectedIndexChanged)
        $btn_t3_PrevTab.Remove_Click($btn_t3_PrevTab_Click)
        $btn_t3_NextTab.Remove_Click($btn_t3_NextTab_Click)
        $btn_t3_Complete.Remove_Click($btn_t3_Complete_Click)
        $tab_t3_Pages.Remove_SelectedIndexChanged($tab_t3_Pages_SelectedIndexChanged)
        $btn_t4_Save.Remove_Click($btn_t4_Save_Click)
        $btn_t4_Options.Remove_Click($btn_t4_Options_Click)
        $btn_t4_Generate.Remove_Click($btn_t4_Generate_Click)

        $tab_Pages
        Try {
            $sysFont.Dispose()
            $sysFontBold.Dispose()
            $sysFontItalic.Dispose()
        } Catch {}

        $MainFORM.Remove_Load($MainFORM_Load)
        $MainFORM.Remove_Load($MainFORM_StateCorrection_Load)
        $MainFORM.Remove_FormClosing($MainFORM_FormClosing)
    }
#endregion
###################################################################################################
#region FORM Scripts
    # Timer to enable the "Complete" button on Tab 3.  This helps to stop double-clicks 
    $tim_CompleteTimer_Tick = {
        $TimerTick++
        If ($TimerTick -ge 1) { $btn_t3_Complete.Enabled = $True; $tim_CompleteTimer.Stop }
    }

    $tab_Pages_SelectedIndexChanged = {
        If ($tab_Pages.SelectedIndex -eq 0) {  $btn_RestoreINI.Visible = $True                   } Else {  $btn_RestoreINI.Visible = $False }    # Show/Hide 'INI Tools' button
        If ($tab_Pages.SelectedIndex -eq 1) { $lbl_ChangesMade.Visible = $script:ShowChangesMade } Else { $lbl_ChangesMade.Visible = $False }    # Show/Hide 'Selection Changes' Label
    }

    Function Update-SelectedCount {
        $lbl_t2_SelectedCount.Text = "$($lst_t2_SelectChecks.CheckedItems.Count) of $($lst_t2_SelectChecks.Items.Count) checks selected"
        If ($lst_t2_SelectChecks.CheckedItems.Count -eq 0) { $btn_t2_SetValues.Enabled = $False } Else { $btn_t2_SetValues.Enabled = $True }
    }

    Function ListView_DoubleClick ( [System.Windows.Forms.ListView]$SourceControl )
    {
        If ([string]::IsNullOrEmpty(($SourceControl.SelectedItems[0].Text).Trim()) -eq $True) { Return }    # No items listed
        If (($SourceControl.SelectedItems[0].ImageIndex) -eq -1)                              { Return }    # No icon
        If (($SourceControl.SelectedItems[0].ImageIndex) -eq  2)                              { Return }    # Disabled Gear icon

        # Start EDIT for selected item
        $MainFORM.Cursor = 'WaitCursor'
        Try { [System.Windows.Forms.ListViewItem]$selectedItem = $($SourceControl.SelectedItems[0]) } Catch { }
        Switch -Wildcard ($($selectedItem.SubItems[2].Text))
        {
            'COMBO*' {
                [string[]]$currentVal  =   $($selectedItem.SubItems[1].Text.Trim("'"))
                [string[]]$selections  = (($($selectedItem.SubItems[2].Text).Split('-')[1]).Split('|'))
                [string[]]$returnValue = (Show-InputForm -Type 'Option' -Title $($selectedItem.Group.Header) -Description "$($selectedItem.SubItems[0].Text)`n$($selectedItem.SubItems[3].Text)" -CurrentValue $currentVal -InputList $selections -InputDescription $($selectedItem.SubItems[5].Text))
                If ($returnValue -ne '!!-CANCELLED-!!') { $SourceControl.SelectedItems[0].SubItems[1].Text = "'$returnValue'" }
                Break
            }

            'CHECK*' {
                [string[]]$currentVal  =   $($selectedItem.SubItems[1].Text).Split(';')
                          $currentVal  = ($currentVal.Trim().Replace("'",'').Replace('(','').Replace(')',''))
                [string[]]$selections  = (($($selectedItem.SubItems[2].Text).Split('-')[1]).Split(','))
                [string[]]$returnValue = (Show-InputForm -Type 'Check'  -Title $($selectedItem.Group.Header) -Description "$($selectedItem.SubItems[0].Text)`n$($selectedItem.SubItems[3].Text)" -CurrentValue $currentVal -InputList $selections -InputDescription $($selectedItem.SubItems[5].Text) -MaxNumberInputBoxes 30)
                If ($returnValue -ne '!!-CANCELLED-!!') { $SourceControl.SelectedItems[0].SubItems[1].Text = ("('{0}')" -f $($returnValue -join ';').Replace(';', "'; '")) }
                Break
            }

            'LIST' {
                # Very specific hack to limit the number of input boxes for the NET-09 Static Routes check.
                If ($($selectedItem.Group.Header).EndsWith('(NET09)')) { $MaxNumberInputBoxes = 3 } Else { $MaxNumberInputBoxes = 30 }

                [string[]]$currentVal  = $($selectedItem.SubItems[1].Text).Split(';')
                          $currentVal  = ($currentVal.Trim().Replace("'",'').Replace('(','').Replace(')',''))
                [string[]]$returnValue = (Show-InputForm -Type 'List'   -Title $($selectedItem.Group.Header) -Description "$($selectedItem.SubItems[0].Text)`n$($selectedItem.SubItems[3].Text)" -CurrentValue $currentVal -Validation $($selectedItem.SubItems[4].Text) -MaxNumberInputBoxes $MaxNumberInputBoxes)
                If ($returnValue -ne '!!-CANCELLED-!!') { $SourceControl.SelectedItems[0].SubItems[1].Text = ("('{0}')" -f $($returnValue -join ';').Replace(';', "'; '")) }
                Break
            }

            'LARGE' {
                [string[]]$currentVal  = $($selectedItem.SubItems[1].Text.Trim("'"))
                [string]  $returnValue = (Show-InputForm -Type 'Large'  -Title $($selectedItem.Group.Header) -Description "$($selectedItem.SubItems[0].Text)`n$($selectedItem.SubItems[3].Text)" -CurrentValue $currentVal)
                If ($returnValue -ne '!!-CANCELLED-!!') { $SourceControl.SelectedItems[0].SubItems[1].Text = "'$returnValue'" }
                Break
            }

            'SIMPLE' {
                [string[]]$currentVal  = $($selectedItem.SubItems[1].Text.Trim("'"))
                [string]  $returnValue = (Show-InputForm -Type 'Simple' -Title $($selectedItem.Group.Header) -Description "$($selectedItem.SubItems[0].Text)`n$($selectedItem.SubItems[3].Text)" -CurrentValue $currentVal -Validation $($selectedItem.SubItems[4].Text))
                If ($returnValue -ne '!!-CANCELLED-!!') { $SourceControl.SelectedItems[0].SubItems[1].Text = "'$returnValue'" }
            }

            Default {
                Write-Host "Invalid Type: $($selectedItem.SubItems[2].Text)"
            }
        }
        $MainFORM.Cursor = 'Default'
    }

    # ###########################################

    Function cmo_t1_SelectedIndexChanged
    {
        If (($cmo_t1_Language.Text -ne '') -and ($cmo_t1_SettingsFile.Text -ne '')) { $btn_t1_Import.Enabled = $True }
    }

    $btn_t1_Search_Click = {
        # Search location and read in scripts
        $MainFORM.Cursor             = 'WaitCursor'
        $btn_t1_Search.Enabled       = $False
        $btn_t1_Import.Enabled       = $False
        $cmo_t1_Language.Enabled     = $False
        $cmo_t1_SettingsFile.Enabled = $False
        $lbl_t1_MissingFile.Visible  = $False

        $script:scriptLocation = (Get-Folder -Description 'Select the QA checks root folder:' -InitialDirectory $script:ExecutionFolder -ShowNewFolderButton $False)
        If ([string]::IsNullOrEmpty($script:scriptLocation) -eq $True) { $btn_t1_Search.Enabled = $True; $MainFORM.Cursor = 'Default'; Return }
        If ($script:scriptLocation.EndsWith('\checks')) { $script:scriptLocation = $script:scriptLocation.TrimEnd('\checks') }

        # Check there is a CHECKS folder with actual checks
        [string[]]$checklist = ((Get-ChildItem -Path "$script:scriptLocation\checks" -Recurse | Where-Object { (-not $_.PSIsContainer) -and ($_.Name).StartsWith('c-') -and ($_.Name).EndsWith('.ps1') } ))
        If (((Test-Path -Path "$script:scriptLocation\checks") -eq $False) -or ([string]::IsNullOrEmpty($checklist) -eq $True))
        {
            [System.Windows.Forms.MessageBox]::Show($MainFORM, "The CHECKS folder does not exist.  Please select the correct location.  Try downloading the source files again.", ' Server QA Settings Configurator', 'OK', 'Error')
            $btn_t1_Search.Enabled = $True
            $MainFORM.Cursor       = 'Default'
            Return
        }

        # Check SETTINGS file is loaded OK
        Try {
            [string[]]$settingList = (Get-ChildItem -Path "$script:scriptLocation\settings" -Filter '*.ini' -ErrorAction Stop | Select-Object -ExpandProperty Name | Sort-Object Name | ForEach { $_.Replace(     '.ini','') } )
            Load-ComboBox -ComboBox $cmo_t1_SettingsFile -Items ($settingList | Sort-Object Name) -SelectedItem 'default-settings' -Clear
            If ($cmo_t1_SettingsFile.Text -ne 'default-settings') { Throw 'Run code below to insert default item' }
        }
        Catch
        {
            # We are fine if it does not exist, just carry on
            $cmo_t1_SettingsFile.Items.Insert(0, '* Use Default Settings')
            $cmo_t1_SettingsFile.SelectedIndex = 0
            $lbl_t1_MissingFile.Visible = $True
        }

        # Check LANGUAGE file is loaded OK
        [boolean]$iniLoadOK = $True
        Try {
            [string[]]$langList = (Get-ChildItem -Path "$script:scriptLocation\i18n" -Filter '*_text.ini' -ErrorAction Stop | Select-Object -ExpandProperty Name | Sort-Object Name | ForEach { $_.Replace('_text.ini','') } )
            Load-ComboBox -ComboBox $cmo_t1_Language -Items ($langList | Sort-Object Name) -SelectedItem 'en-gb' -Clear
        } Catch {
            # No language file, stop import!
            Load-ComboBox -ComboBox $cmo_t1_Language -Items ('Unknown') -SelectedItem 'Unknown' -Clear
            $iniLoadOK = $False
        }
        
        $btn_t1_Search.Enabled       = $True
        $btn_t1_Import.Enabled       = $iniLoadOK
        $cmo_t1_Language.Enabled     = $iniLoadOK
        $cmo_t1_SettingsFile.Enabled = $iniLoadOK
        $btn_t1_Import.Focus()
        $MainFORM.Cursor = 'Default'
    }

    $btn_t1_Import_Click = {
        $MainFORM.Cursor                = 'WaitCursor'
        $btn_t1_Search.Enabled          = $False
        $btn_t1_Import.Enabled          = $False
        $cmo_t1_Language.Enabled        = $False
        $cmo_t1_SettingsFile.Enabled    = $False
        $lbl_t1_ScanningScripts.Text    = 'Scanning check folders...'
        $lbl_t1_ScanningScripts.Visible = $True
        $lbl_t1_ScanningScripts.Refresh(); [System.Windows.Forms.Application]::DoEvents()

        # Load Language, Settings and Help details
        [hashtable]$settingsINI = (Load-IniFile -Inputfile "$script:scriptLocation\settings\$($cmo_t1_SettingsFile.Text).ini")
        [hashtable]$languageINI = (Load-IniFile -Inputfile "$script:scriptLocation\i18n\$($cmo_t1_Language.Text)_text.ini")
        [string[]] $loadhelpINI = (Get-Content  -Path      "$script:scriptLocation\i18n\$($cmo_t1_Language.Text)_help.ps1" -ErrorAction SilentlyContinue)
        ForEach ($help In $loadhelpINI) { If ([string]::IsNullOrEmpty($help) -eq $False) { Invoke-Expression -Command $help } }
        $loadhelpINI = $null

        # Load settings from INI file - if possible
        Try { $txt_t4_ShortCode.Text          = ($settingsINI.settings.shortcode)         } Catch { $txt_t4_ShortCode.Text   = 'ACME' }
        Try { $txt_t4_ReportTitle.Text        = ($settingsINI.settings.reportCompanyName) } Catch { $txt_t4_ReportTitle.Text = 'ACME' }
        Try { $script:settings.Timeout        = ($settingsINI.settings.timeout)           } Catch { }    # \
        Try { $script:settings.Concurrent     = ($settingsINI.settings.concurrent)        } Catch { }    #  | Use default settings
        Try { $script:settings.OutputLocation = ($settingsINI.settings.outputLocation)    } Catch { }    # /

        # Clear any existing entries and start from scratch
        $tab_t3_Pages.TabPages.Clear()
        $lst_t2_SelectChecks.Items.Clear()
        $lst_t2_SelectChecks.Groups.Clear()
        $lst_t2_SelectChecks.CheckBoxes = $True

        [object[]]$folders = (Get-ChildItem -Path "$script:scriptLocation\checks" | Where-Object { $_.PsIsContainer -eq $True } | Select-Object -ExpandProperty Name | Sort-Object Name )
        [System.Globalization.TextInfo]$TextInfo = (Get-Culture).TextInfo    # Used for 'ToTitleCase' below
        ForEach ($folder In ($folders | Sort-Object Name))
        {
            $folder = $folder.ToLower()
            $lbl_t1_ScanningScripts.Text = "Scanning check folders: $($folder.ToUpper())"
            $lbl_t1_ScanningScripts.Refresh(); [System.Windows.Forms.Application]::DoEvents()

            [object[]]$scripts = (Get-ChildItem -Path "$script:scriptLocation\checks\$folder" -Filter 'c-*.ps1' | Select-Object -ExpandProperty Name | Sort-Object Name )

            # Only run if the folder contains checks
            If ([string]::IsNullOrEmpty($scripts) -eq $False)
            {
                # FOR TAB-2 LIST OF CHECKS
                # Generate GUID for group IDs
                [string]$guid = ([guid]::NewGuid() -as [string]).Split('-')[0]
                $lst_t2_SelectChecks.Groups.Add("$guid", " $($folder.ToUpper())")

                ForEach ($script In ($scripts | Sort-Object Name))
                {
                    [string]$Name      =  $script.TrimEnd('.ps1')                                                       # Remove PS1.extension
                    [string]$checkCode = ($Name.Substring(2, 6).Replace('-',''))                                        # Get check code: c-acc-01-local-user  -->  acc01
                    Try { [string]$checkName = ($languageINI.$($checkCode).Name) } Catch { [string]$checkName = '' }    # Get check name from INI file

                    # Checks to see if the "checkName" value has been retreved or not
                    If ([string]::IsNullOrEmpty($checkName) -eq $True) { $checkName = '*' + $TextInfo.ToTitleCase($(($Name.Substring(9)).Replace('-', ' '))) }
                    Else                                               { $checkName = $checkName.Trim("'") }

                    # Load check description
                    [string]$checkDesc = ''
                    If ([string]::IsNullOrEmpty($script:qahelp[$checkCode]) -eq $False)
                    {
                        # Load XML version of help
                        Try
                        {
                            [xml]$xmlHelp = New-Object 'System.Xml.XmlDataDocument'
                            $xmlHelp.LoadXml($script:qahelp[$checkCode])
                            If ($xmlHelp.xml.Applies)     { $checkDesc  = "Applies To: $($xmlHelp.xml.Applies)"     }
                            If ($xmlHelp.xml.Description) { $checkDesc +=             "$($xmlHelp.xml.Description)" }
                        }
                        Catch { }
                    }

                    [string]$getContent = ''
                    # Default back to the scripts description of help if required
                    If ($checkDesc -eq '')
                    {
                        $getContent = ((Get-Content -Path ("$script:scriptLocation\checks\$folder\$script") -TotalCount 50) -join "`n")
                        $regExA = [RegEx]::Match($getContent,     "APPLIES:((?:.|\s)+?)(?:(?:[A-Z\- ]+:\n)|(?:#>))")
                        $regExD = [RegEx]::Match($getContent, "DESCRIPTION:((?:.|\s)+?)(?:(?:[A-Z\- ]+:\n)|(?:#>))")

                        [string]$checkDesc = "Applies To: $($regExA.Groups[1].Value.Trim())!n"
                        ($regExD.Groups[1].Value.Trim().Split("`n")) | ForEach { $checkDesc += $_.Trim() + '  ' }
                    }

                    # Add check details to selection list, and check if required
                    Add-ListViewItem -ListView $lst_t2_SelectChecks -Items $checkCode -SubItems ($checkName, $checkDesc.Replace('!n', "`n`n"), "$folder\$script") -Group $guid -ImageIndex 1 -Enabled $True

                    [int]$notFound = 2
                    If ([string]::IsNullOrEmpty($settingsINI) -eq $False)
                    {
                        If ($settingsINI.ContainsKey("$checkCode")      -eq $True) { $lst_t2_SelectChecks.Items["$checkCode"].Checked = $True ; $notFound-- }    # Enabled checks
                        If ($settingsINI.ContainsKey("$checkCode-skip") -eq $True) { $lst_t2_SelectChecks.Items["$checkCode"].Checked = $False; $notFound-- }    # Skipped checks
                    }

                    If ($notFound -eq 2)                                                                                                                         # Unknown State
                    {
                        # Load default "ENABLED/SKIPPED" value from the check itself
                        If ($getContent -eq '') { $getContent = ((Get-Content -Path ("$script:scriptLocation\checks\$folder\$script") -TotalCount 50) -join "`n") }
                        $regExE = [RegEx]::Match($getContent, "DEFAULT-STATE:((?:.|\s)+?)(?:(?:[A-Z\- ]+:\n)|(?:#>))")
                        If ($regExE.Groups[1].Value.Trim() -eq 'Enabled') { $lst_t2_SelectChecks.Items["$checkCode"].Checked = $True }
                    }
                }

                # #####################################################################################
                # FOR TAB-3 OF MAIN TABPAGE CONTROL
                # Add TabPage for folder
                $newTab = New-Object 'System.Windows.Forms.TabPage'
                $newTab.Font           = $sysFont
                $newTab.Text           = $($TextInfo.ToTitleCase($folder))    # TitleCase section tabs
                $newTab.Name           = "tab_$folder"
                $newTab.Tag            = "tab_$folder"
                $newTab.Margin         = '0, 0, 0, 0'
                $newTab.Padding        = '0, 0, 0, 0'
                $tab_t3_Pages.TabPages.Add($newTab)

                # Create a new ListView object
                $newLVW = New-Object 'System.Windows.Forms.ListView'
                $newLVW.Font           = $sysFont
                $newLVW.Name           = "lvw_$folder"
                $newLVW.HeaderStyle    = 'Nonclickable'
                $newLVW.FullRowSelect  = $True
                $newLVW.GridLines      = $False
                $newLVW.LabelWrap      = $False
                $newLVW.MultiSelect    = $False
                $newLVW.Dock           = 'Fill'
                $newLVW.BorderStyle    = 'None'
                $newLVW.View           = 'Details'
                $newLVW.SmallImageList = $img_ListImages

                # Add columns
                [int]$width = (($newTab.Width - 225) - [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth)
                $newLVW_CH_Name = New-Object 'System.Windows.Forms.ColumnHeader'; $newLVW_CH_Name.Text = 'Check'; $newLVW_CH_Name.Width =  225      # 
                $newLVW_CH_Valu = New-Object 'System.Windows.Forms.ColumnHeader'; $newLVW_CH_Valu.Text = 'Value'; $newLVW_CH_Valu.Width = $width    #
                $newLVW_CH_Type = New-Object 'System.Windows.Forms.ColumnHeader'; $newLVW_CH_Type.Text = ''     ; $newLVW_CH_Type.Width =   0       # Input type: List/Combo/Simple, etc
                $newLVW_CH_Desc = New-Object 'System.Windows.Forms.ColumnHeader'; $newLVW_CH_Desc.Text = ''     ; $newLVW_CH_Desc.Width =   0       # Description from check file
                $newLVW_CH_Vali = New-Object 'System.Windows.Forms.ColumnHeader'; $newLVW_CH_Vali.Text = ''     ; $newLVW_CH_Vali.Width =   0       # Validation type
                $newLVW_CH_Vdsc = New-Object 'System.Windows.Forms.ColumnHeader'; $newLVW_CH_Vdsc.Text = ''     ; $newLVW_CH_Vdsc.Width =   0       # Value Description
                $newLVW.Columns.Add($newLVW_CH_Name) | Out-Null
                $newLVW.Columns.Add($newLVW_CH_Valu) | Out-Null
                $newLVW.Columns.Add($newLVW_CH_Type) | Out-Null
                $newLVW.Columns.Add($newLVW_CH_Desc) | Out-Null
                $newLVW.Columns.Add($newLVW_CH_Vali) | Out-Null
                $newLVW.Columns.Add($newLVW_CH_Vdsc) | Out-Null

                # Add Events for each Listview
                $newLVW.Add_KeyPress( { If ($_.KeyChar -eq 13) { ListView_DoubleClick -SourceControl $this } } )
                $newLVW.Add_DoubleClick(                       { ListView_DoubleClick -SourceControl $this }   )

                # Add new Listview to new folder
                $newTab.Controls.Add($newLVW)
            }
        }

        $tab_Pages.SelectedIndex               = 1
        $btn_t1_Search.Enabled                 = $True
        $btn_t1_Import.Enabled                 = $True
        $cmo_t1_Language.Enabled               = $True
        $cmo_t1_SettingsFile.Enabled           = $True
        $btn_t2_SetValues.Enabled              = $True
        $btn_t2_SelectAll.Enabled              = $True
        $btn_t2_SelectInv.Enabled              = $True
        $btn_t2_SelectNone.Enabled             = $True
        $btn_t2_SelectReset.Enabled            = $True
        $lst_t2_SelectChecks.Items[0].Selected = $True
        $lbl_t1_ScanningScripts.Visible        = $False
        Update-SelectedCount
        Update-NavButtons
        $script:ShowChangesMade                = $False
        $script:UpdateSelectedCount            = $True
        $MainFORM.Cursor                       = 'Default'
    }

    # ###########################################

    Function btn_t2_SelectButtons([string]$SourceButton)
    {
        $MainFORM.Cursor = 'AppStarting'
        $script:UpdateSelectedCount = $False

        If ($SourceButton -eq 'SelectReset')
        {
            $btn_t1_Import_Click.Invoke()    # Reset the checkbox selection back to the INI settings
        }
        Else
        {
            ForEach ($item In $lst_t2_SelectChecks.Items)
            {
                Switch ($SourceButton)
                {
                    'SelectAll'     { $item.Checked =       $True         ; Break }
                    'SelectInv'     { $item.Checked = (-not $item.Checked); Break }
                    'SelectNone'    { $item.Checked =       $False        ; Break }
                }
            }
            Update-SelectedCount
        }
        $script:UpdateSelectedCount = $True
        $MainFORM.Cursor = 'Default'
    }

    $lst_t2_SelectChecks_ItemChecked = {
        If ($_.Item.Checked -eq $True) { $_.Item.ForeColor = 'WindowText'; $_.Item.BackColor = 'Window';  $_.Item.Font = $sysFont;       $_.Item.ImageIndex = 1 }    # Enabled
        Else                           { $_.Item.ForeColor = 'GrayText';   $_.Item.BackColor = 'Control'; $_.Item.Font = $sysFontItalic; $_.Item.ImageIndex = 2 }    # Disabled
        If ($script:UpdateSelectedCount -eq $True) { Update-SelectedCount } 
    }

    $lst_t2_SelectChecks_SelectedIndexChanged = { If ($lst_t2_SelectChecks.SelectedItems.Count -eq 1) { $lbl_t2_Description.Text = ($lst_t2_SelectChecks.SelectedItems[0].SubItems[2].Text) } }

    # Set focus to the exit button if there are no checks listed
    $lst_t2_SelectChecks_Enter = { If ($lst_t2_SelectChecks.Checkboxes -eq $False) { $btn_Exit.Focus() } }

    $btn_t2_SetValues_Click = {
        If ($lst_t2_SelectChecks.Items.Count        -eq 0) { Return }
        If ($lst_t2_SelectChecks.CheckedItems.Count -eq 0) { Return }

        $cmo_t1_SettingsFile.Enabled = $False
        $cmo_t1_Language.Enabled     = $False

        If ($script:ShowChangesMade -eq $True)
        {
            $msgbox = ([System.Windows.Forms.MessageBox]::Show($MainFORM, "Any unsaved changes will be lost.`nAre you sure you want to continue.?`n`nTo save your current changes: Click 'No',`nChange to the 'Generate QA' tab, click 'Save Settings'.", ' Selection Change', 'YesNo', 'Warning', 'Button2'))
            If ($msgbox -eq 'No') { Return }
        }

        $MainFORM.Cursor = 'WaitCursor'
        $btn_t3_Complete.Enabled = $False
        [hashtable]$defaultINI       = (Get-DefaultINISettings)
        [hashtable]$settingsINI      = (Load-IniFile -Inputfile "$script:scriptLocation\settings\$($cmo_t1_SettingsFile.Text).ini")
        Try { [string]$SkippedChecks = ($SettingsINI.Keys | Where-Object { $_.EndsWith('-skip') }) } Catch { }

        # Add each of the checks' settings to the correct tab page
        ForEach ($folder In $lst_t2_SelectChecks.Groups)
        {
            # Get correct ListView object
            [System.Windows.Forms.TabPage] $tabObject = $tab_t3_Pages.TabPages["tab_$($folder.Header.Trim())"]
            [System.Windows.Forms.ListView]$lvwObject =    $tabObject.Controls["lvw_$($folder.Header.Trim())"]

            # Clear any existing entries
            $lvwObject.Items.Clear()
            $lvwObject.Groups.Clear()

            ForEach ($listItem In $folder.Items)
            {
                # Read in the entire file - it's needed upto three times
                [string]$getContent = ((Get-Content -Path "$script:scriptLocation\checks\$($listItem.SubItems[3].Text)" -TotalCount 50) -join "`n")

                # Create group for the checks
                [string]$guid = $($listItem.Text)
                $lvwObject.Groups.Add($guid, " $($listItem.SubItems[1].Text) ($($listItem.Text.ToUpper()))")

                # Create each item
                $iniKeys = New-Object 'System.Collections.Hashtable'

                # Load up the default settings first
                If ($defaultINI.Contains($("$($listItem.Text)-skip"))) { $iniKeys = ($defaultINI.$("$($listItem.Text)-skip")) }
                Else                                                   { $iniKeys = ($defaultINI.$(   $listItem.Text)       ) }

                Try
                {
                    # Overwrite with the custom settings
                    $tmpKeys = New-Object 'System.Collections.Hashtable'
                    If ($SkippedChecks.Contains($("$($listItem.Text)-skip"))) { $tmpKeys = ($settingsINI.$("$($listItem.Text)-skip")) }
                    Else                                                      { $tmpKeys = ($settingsINI.$(   $listItem.Text)       ) }
                    ForEach ($val In $tmpKeys.Keys) { If ($iniKeys.ContainsKey($val)) { $iniKeys[$val] = $tmpKeys[$val] } }
                }
                Catch {}

                ForEach ($item In (($iniKeys.Keys) | Sort-Object))
                {
                    [string]$desc  = ''
                    [string]$value = [regex]::Replace(($iniKeys.$item), "'\s{0,},\s{0,}'", "'; '")    # Replace:    ', '  -->  '; '
                    #                                                    ^      ^      ^ == ^^ ^
                    # Get the help text for each check setting
                    If ([string]::IsNullOrEmpty($script:qahelp[$($listItem.Text)]) -eq $False)
                    {
                        Try {
                            [xml]$xmlDesc = New-Object 'System.Xml.XmlDataDocument'
                            $xmlDesc.LoadXml($script:qahelp[$($listItem.Text)])
                            If ($xmlDesc.xml.RequiredInputs) { [string[]]$DescList = $(($xmlDesc.xml.RequiredInputs) -split '!n') }
                            ForEach ($DL In $DescList) { If (($DL.Trim()).StartsWith($item.Trim())) { $desc = ($DL.Trim()); Break } }
                        } Catch { }
                    }
                    Else
                    {
                        # No details in help file yet
                        # Using '$getContent' from above
                        $regExI = [RegEx]::Match($getContent, "REQUIRED-INPUTS:((?:.|\s)+?)(?:(?:[A-Z\- ]+:\n)|(?:#>))")
                        [string[]]$Inputs = ($regExI.Groups[1].Value.Trim()).Split("`n")
                        If (([string]::IsNullOrEmpty($Inputs) -eq $false) -and ($Inputs -ne 'None'))
                        {
                            ForEach ($EachInput In $Inputs) { If (($EachInput.Trim()).StartsWith($item.Trim())) { $desc = ($EachInput.Trim()); Break } }
                        }
                    }

                    # Get any input descriptions (if any exist)
                    [string]$idsc = ""
                    $regExD = [RegEx]::Match($getContent, "INPUT-DESCRIPTION:((?:.|\s)+?)(?:(?:[A-Z\- ]+:\n)|(?:#>))")
                    [string[]]$Inputs = ($regExD.Groups[1].Value.Trim()).Split("`n")
                    ForEach ($EachInput In $Inputs) { If ($EachInput -ne '') { $idsc += $EachInput.Trim() + '|' } }

                    # Remove all double spaces
                    Do { $desc = $desc.Replace('  ', ' ') } While ($desc.Contains('  '))

                    $desc = $desc.Replace("$($item.Trim()) - ", '')
                    [string]$type = 'Unknown'

                    Switch -Regex ($desc.Trim())
                    {
                        '\".*\|{1,}.*\"'    # Look for one or more PIPE splitters "..|..|.." in quotes
                        { 
                            $type = 'COMBO-' + ($desc.Split('-')[0]).Trim().Trim('"')
                            $desc =            ($desc.Split('-')[1]).Trim()
                            Break
                        }
                        '\".*,{1,}.*\"'     # Look for one or more COMMA splitters "..,..,.." in quotes
                        {
                            $type = 'CHECK-' + ($desc.Split('-')[0]).Trim().Trim('"')
                            $desc =            ($desc.Split('-')[1]).Trim()
                            Break
                        }
                        '\"LARGE\"'         # Look for the word LARGE in quotes
                        {
                            $type = 'LARGE'
                            $desc = ($desc.Split('-')[1]).Trim()
                            Break
                        }
                        'List of'           # List
                        {
                            $type = 'LIST'
                        }
                        Default
                        {
                            $type = 'SIMPLE'
                        }
                    }

                    If ($desc.Contains('|') -eq $True)
                    {
                        [string]$vali = ($desc.Split('|')[1])
                        [string]$desc = ($desc.Split('|')[0])
                    }
                    Else
                    {
                        [string]$vali = 'None'
                    }

                    Add-ListViewItem -ListView $lvwObject -Items $item -SubItems ($value, $type, $desc, $vali, $idsc) -Group $guid -ImageIndex 1 -Enabled $($listItem.Checked)
                }

                # Add 'spacing' gap between groups
                If ($lvwObject.Groups[$guid].Items.Count -gt 0) { Add-ListViewItem -ListView $lvwObject -Items ' ' -SubItems ('','','','') -Group $guid -ImageIndex -1 -Enabled $false }
            }
        }

        $tim_CompleteTimer.Start()
        $tab_Pages.SelectedIndex   = 2
        $btn_t4_Save.Enabled       = $True
        $lbl_t3_NoChecks.Visible   = $False
        $script:ShowChangesMade    = $True
        Update-NavButtons
        $MainFORM.Cursor           = 'Default'
    }

    # ###########################################

    Function Update-NavButtons
    {
        $btn_t3_NextTab.Enabled = $tab_t3_Pages.SelectedIndex -lt $tab_t3_Pages.TabCount - 1
        $btn_t3_PrevTab.Enabled = $tab_t3_Pages.SelectedIndex -gt 0
    }

    $tab_t3_Pages_SelectedIndexChanged = {                    Update-NavButtons }
    $btn_t3_PrevTab_Click  = { $tab_t3_Pages.SelectedIndex--; Update-NavButtons }
    $btn_t3_NextTab_Click  = { $tab_t3_Pages.SelectedIndex++; Update-NavButtons }
    $btn_t3_Complete_Click = { $tab_Pages.SelectedIndex = 3 }

    # ###########################################

    $btn_t4_Options_Click = {
        $MainFORM.Cursor  = 'WaitCursor'
        [object]$settings = Show-ExtraSettingsForm -Timeout ($script:settings.Timeout) -Concurrent ($script:settings.concurrent) -OutputLocation ($script:settings.outputLocation)
        If ([string]::IsNullOrEmpty($settings) -eq $false) { [psobject]$script:settings = $settings }
        $MainFORM.Cursor  = 'Default'
    }

    $btn_t4_Save_Click = {
        If (([string]::IsNullOrEmpty($txt_t4_ShortCode.Text) -eq $True) -or ([string]::IsNullOrEmpty($txt_t4_ReportTitle.Text) -eq $True))
        {
            [System.Windows.Forms.MessageBox]::Show($MainFORM, 'Please fill in the short code and report title values.', ' Missing Data', 'OK', 'Warning')
            Return
        }

        $MainFORM.Cursor = 'WaitCursor'
        $script:saveFile = (Save-File -InitialDirectory "$script:ExecutionFolder\settings" -Title 'Save Settings File')
        $MainFORM.Cursor = 'Default'

        If ([string]::IsNullOrEmpty($script:saveFile) -eq $True) { Return }
        If ($script:saveFile.EndsWith('default-settings.ini'))
        {
            [System.Windows.Forms.MessageBox]::Show($MainFORM, "You should not save over the default settings file.`n" +
                                                               "It will be overwritten whenever the source code is updated.`n`n" +
                                                               "Please select a different file name.", ' default-settings.ini', 'OK', 'Error')
            Return
        }

        $MainFORM.Cursor = 'WaitCursor'
        [System.Text.StringBuilder]$outputFile = ''
        # Write out header information
        $outputFile.AppendLine('[settings]')
        $outputFile.AppendLine("shortcode         = $($txt_t4_ShortCode.Text)")
        $outputFile.AppendLine("reportCompanyName = $($txt_t4_ReportTitle.Text)")
        $outputFile.AppendLine('')
        $outputFile.AppendLine("language          = $($cmo_t1_Language.Text)")
        $outputFile.AppendLine("outputLocation    = $($script:settings.OutputLocation)")
        $outputFile.AppendLine("timeout           = $($script:settings.TimeOut)")
        $outputFile.AppendLine("concurrent        = $($script:settings.Concurrent)")
        $outputFile.AppendLine('')

        # Loop through all checks saving as required, hiding others
        ForEach ($folder In $lst_t2_SelectChecks.Groups)
        {
            $outputFile.AppendLine('')
            $outputFile.AppendLine('; _________________________________________________________________________________________________')
            $outputFile.AppendLine("; $(($folder.Header).ToUpper().Trim())")

            ForEach ($check In $folder.Items)
            {
                [System.Windows.Forms.TabPage] $tabObject = $tab_t3_Pages.TabPages["tab_$($folder.Header.Trim())"]
                [System.Windows.Forms.ListView]$lvwObject = $null
                Try { $lvwObject = $tabObject.Controls["lvw_$($folder.Header.Trim())"] } Catch { $lvwObject = $null }

                If ($check.Checked -eq $False) { $outputFile.AppendLine("[$($check.Text)-skip]") }
                Else                           { $outputFile.AppendLine("[$($check.Text)]"     ) }

                ForEach ($group In $lvwObject.Groups)
                {
                    If ($group.Name -eq $check.Text)
                    {
                        ForEach ($item In $group.Items)
                        {
                            Switch -Wildcard ($item.SubItems[2].Text)
                            {
                                'COMBO*' { [string]$out =  "$($item.SubItems[1].Text)"                    }
                                'CHECK*' { [string]$out = "$(($item.SubItems[1].Text).Replace(';', ','))" }
                                'LARGE'  { [string]$out =  "$($item.SubItems[1].Text)"                    }
                                'LIST'   { [string]$out = "$(($item.SubItems[1].Text).Replace(';', ','))" }
                                'SIMPLE' { [string]$out =  "$($item.SubItems[1].Text)"                    }
                                Default  {                                                                }
                            }
                            If ([string]::IsNullOrEmpty($($item.Text).Trim(' ')) -eq $False) { $outputFile.AppendLine("$(($item.Text).Trim().PadRight(34)) = $out") }
                        }
                        If (($group.Items.Count) -eq 0) { $outputFile.AppendLine('; No Settings') }
                        $outputFile.AppendLine('')
                    }
                }
            }
        }

        $outputFile.ToString() | Out-File -FilePath $script:saveFile -Encoding ascii -Force
        [System.Windows.Forms.MessageBox]::Show($MainFORM, "Settings file '$(Split-Path -Path $script:saveFile -Leaf)' saved successfully.", ' Save Settings', 'OK', 'Information') 
        $btn_t4_Generate.Enabled = $True
        $MainFORM.Cursor = 'Default'
    }

    $btn_t4_Generate_Click = {
        $MainFORM.Cursor = 'WaitCursor'
        $btn_Exit.Enabled           = $False
        $btn_RestoreINI.Enabled     = $False
        $btn_t4_Save.Enabled        = $False
        $btn_t4_Options.Enabled     = $False
        $btn_t4_Generate.Enabled    = $False
        $txt_t4_ShortCode.Enabled   = $False
        $txt_t4_ReportTitle.Enabled = $False

        # Build Standard QA Script
        $lbl_t4_Generate.Text = 'Generating Standard QA Script'
        Invoke-Expression -Command "PowerShell -NoProfile -NonInteractive -Command {& '$script:ExecutionFolder\Compiler.ps1'   -Settings '$(Split-Path -Path $script:saveFile -Leaf)' -Silent }"

        # Build Runspace QA Script
        $lbl_t4_Generate.Text = 'Generating Runspace QA Script (New Report Format)'
        Invoke-Expression -Command "PowerShell -NoProfile -NonInteractive -Command {& '$script:ExecutionFolder\CompilerR2.ps1' -Settings '$(Split-Path -Path $script:saveFile -Leaf)' -Silent }"

        $lbl_t4_Generate.Text = ''
        [System.Windows.Forms.MessageBox]::Show($MainFORM, "Custom QA Script generated.", ' Server QA Settings Configurator', 'OK', 'Information')

        $btn_Exit.Enabled           = $True
        $btn_RestoreINI.Enabled     = $True
        $btn_t4_Save.Enabled        = $True
        $btn_t4_Options.Enabled     = $True
        $btn_t4_Generate.Enabled    = $True
        $txt_t4_ShortCode.Enabled   = $True
        $txt_t4_ReportTitle.Enabled = $True
        $MainFORM.Cursor = 'Default'
    }

    # ###########################################

    $btn_RestoreINI_Click = {
        [string]$msgbox = [System.Windows.Forms.MessageBox]::Show($MainFORM, "If you have lost your settings file, you can use this option to restore it.  Click 'OK' to select the compiled QA script you want to restore your settings from.", ' Restore Settings File', 'OKCancel', 'Information')
        If ($msgbox -eq 'Cancel') { Return }

        [string]$originalQA = (Get-File -InitialDirectory $script:ExecutionFolder -Title 'Select the compiled QA script to restore the settings from:')
        If ([string]::IsNullOrEmpty($originalQA)) { Return }
        $MainFORM.Cursor = 'WaitCursor'

        # Start retrevial process
        [string[]]$content   = (Get-Content -Path $originalQA)
        [string]  $enabledF  = ([regex]::Match($content, '(\[array\]\$script\:qaChecks \= \()((?:.|\s)+?)(?:(?:[A-Z\- ]+:)|(?:#>))'))    # Get list of enabled functions
                  $enabledF  = $enabledF.Replace(' ', '').Trim()
        [string[]]$functions = ($content | Select-String -Pattern '(Function c-)([a-z]{3}[-][0-9]{2})' -AllMatches)                      # Get list of all functions

        # Get list of skipped functions
        [array]   $skippedChecks = ''
        ForEach ($func In $functions) { If ($enabledF.Contains($func.Substring(9)) -eq $false) { $skippedChecks += ($func.Substring(11, 6).Replace('-', '')) } }

        [System.Text.StringBuilder]$outputFile = ''
        $outputFile.AppendLine('[settings]')                   | Out-Null
        $outputFile.AppendLine('shortcode         = RESTORED') | Out-Null
        $outputFile.AppendLine('language          = en-gb')    | Out-Null

        ForEach ($line In $content)
        {
            If ($line.StartsWith('[string]$reportCompanyName'  )) { $outputFile.AppendLine("reportCompanyName =$($line.Split('=')[1])".Replace('"', '').Trim()) | Out-Null }
            If ($line.StartsWith('[string]$script:qaOutput'    )) { $outputFile.AppendLine("outputLocation    =$($line.Split('=')[1])".Replace('"', '').Trim()) | Out-Null }
            If ($line.StartsWith('[int]   $script:ccTasks'     )) { $outputFile.AppendLine("concurrent        =$($line.Split('=')[1])".Replace('"', '').Trim()) | Out-Null }
            If ($line.StartsWith('[int]   $script:checkTimeout')) { $outputFile.AppendLine("timeout           =$($line.Split('=')[1])".Replace('"', '').Trim()) | Out-Null }
        }

        [string]$FuncOLD = ''
        [string]$FuncNEW = ''
        # Start process
        ForEach ($line In $content)
        {
            If ($line.StartsWith('Function newResult { Return ')) { [string]$funcName = ''; [string[]]$appSettings = $null }    # Clear settings
            If ($line.StartsWith('$script:appSettings['        )) {
                # Need to have spaces around the equals sign due to check settings having equal signs in them (ie:SYS-18)
                [string[]]$newLine = ($line.Substring(21).Replace("']", '')) -Split ' = '
                $appSettings += (($newLine[0].Trim()).PadRight(35) + '= ' + ($newLine[1]).Trim())
            }

            If ($line.StartsWith('Function c-'))
            {
                $funcName = ($line.Substring(11, 6).Replace('-', ''))
                $FuncNEW  = $funcName.Substring(0,3)

                If ($FuncNEW -ne $FuncOLD)
                {
                    $FuncOLD = $FuncNEW
                    $outputFile.AppendLine('')                                                                                                    | Out-Null
                    $outputFile.AppendLine('; _________________________________________________________________________________________________') | Out-Null
                    $outputFile.AppendLine("; $(($FuncNEW).ToUpper().Trim())")                                                                    | Out-Null
                }

                If ($skippedChecks.Contains($funcName))    { $outputFile.AppendLine("[$funcName-skip]") | Out-Null }      # Skipped check
                Else                                       { $outputFile.AppendLine("[$funcName]"     ) | Out-Null }      # Enabled check

                If ([string]::IsNullOrEmpty($appSettings)) { $outputFile.AppendLine("; No Settings")    | Out-Null }      # No settings for this check
                Else { ForEach ($setting In $appSettings)  { $outputFile.AppendLine($setting)           | Out-Null } }    # Write out all settings and values

                $outputFile.AppendLine('')                                                              | Out-Null
             }
        }

        $outputFile.ToString() | Out-File -FilePath "$(Split-Path -Path $originalQA -Parent)\RESTORED.ini" -Encoding ascii -Force

        $MainFORM.Cursor = 'Default'
        [System.Windows.Forms.MessageBox]::Show($MainFORM, "Restore Complete.`nThe file is called 'RESTORED.ini'.`n`nIt is located in the same folder as the QA script you selected.  Remember to move it to the settings folder for reuse.", ' Server QA Settings Configurator', 'OK', 'Information')
    }
#endregion
###################################################################################################
#region FORM ITEMS
#region MAIN FORM
    #
    $MainFORM                           = New-Object 'System.Windows.Forms.Form'
    $MainFORM.AutoScaleDimensions       = '6, 13'
    $MainFORM.AutoScaleMode             = 'None'
    $MainFORM.ClientSize                = '794, 672'    # 800 x 700
    $MainFORM.FormBorderStyle           = 'FixedSingle'
    $MainFORM.MaximizeBox               = $False
    $MainFORM.StartPosition             = 'CenterScreen'
    $MainFORM.Text                      = ' Server QA Settings Configurator '
    $MainFORM.Icon                      = [System.Convert]::FromBase64String('
        AAABAAIAICAAAAEAIACoEAAAJgAAABAQAAABACAAaAQAAM4QAAAoAAAAIAAAAEAAAAABACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAANIAAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA8AAAADcAAAAAAAAAAACZAD8A
        mQA9AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADXAAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAPAAAAA3AAAAAAAAAAAAmQBpAJkA/gCZAPwAmQA9AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AAAD/
        QEBA/39/f/9/f3//f39//39/f/9/f3//f39//39/f/9/f3//f39//39/f/9/f3//f39//39/f/9/f3//y8vL////////////ltWW/wGZAf8AmQD/AJkA/wCZAN0AmQAMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/wAAAP9/f3//////////////////////////////////////////////////////
        /////////////////////////////////5bVlv8BmQH/AJkA/wCZAP8AmQD/AJkA/wCZAJcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/AAAA/39/f/////////////////////////////////////////////////////////////////////////////////+W1Zb/AZkB/wCZAP8AmQD/AJkA/ACZ
        AP8AmQD/AJkA/gCZAEYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AAAD/f39/////////////////////////////////////////////////////////////////////////////mNaY/wGZAf8AmQD/AJkA/xykHP8AmQAyAJkA3gCZAP8AmQD/AJkA5ACZABAAAAAAAAAAAAAAAAAAAAAAAAAA/wAAAP9/
        f3////////////////////////////////////////////////////////////////////////////9PuE//AJkA/wCZAP8VoRX/1+/X/wAAAAAAmQBBAJkA/gCZAP8AmQD/AJkAogAAAAAAAAAAAAAAAAAAAAAAAAD/AAAA/39/f///////////////////////////////////////////////////////
        //////////////////////D58P83rzf/FKEU/9Lt0v//////AAAAAAAAAAAAmQCPAJkA/wCZAP8AmQD/AJkAUAAAAAAAAAAAAAAAAAAAAP8AAAD/f39///////////////////////////////////////////////////////////////////////////////////T79P/q9+r///////////8AAAAnAAAA
        AACZAAoAmQDZAJkA/wCZAP8AmQDqAJkAFQAAAAAAAAAAAAAA/wAAAP9/f3///////////////////////////////////////////////////////////////////////////////////////////////////////wAAAM8AAAAbAAAAAACZADgAmQD8AJkA/wCZAP8AmQCtAAAAAAAAAAAAAAD/AAAA/39/
        f///////////////////////////////////////////////////////////////////////////////////////////////////////AAAA3wAAALQAAAAAAAAAAACZAIYAmQD/AJkA/wCZAP8AmQBbAAAAAAAAAP8AAAD/f39/////////////////////////////////////////////////////////
        //////////////////////////////////////////////8gICD/AAAA/wAAAF8AAAAAAJkABwCZANIAmQD/AJkA/wCZAO8AmQAbAAAA/wAAAP9/f3/////////////39/f/ZGRk/2lpaf+oqKj/rKys/3h4eP/BwcH/bW1t/5+fn/+EhIT/d3d3/5ubm/+qqqr/hISE/////////////////yAgIP8AAAD/
        AAAAnwAAAAAAAAAAAJkAMACZAPoAmQD/AJkA/wCZALgAAAD/AAAA/39/f////////////7i4uP96enr//////7S0tP+Dg4P/QkJC/3Nzc/96enr/cnJy/z8/P//u7u7/ioqK/yMjI//AwMD/////////////////ICAg/wAAAP8AAACfAAAAAAAAAAAAAAAAAJkAfACZAP8AmQD/AJkA1gAAAP8AAAD/f39/
        ////////////39/f/0BAQP+Wlpb/kpKS/1tbW/+jo6P/6enp/4qKiv/Nzc3/w8PD/4eHh/+IiIj/qamp/7W1tf////////////////8gICD/AAAA/wAAAJ8AAAAAAAAAAAAAAAAAmQAEAJkApwCZAIsAmQALAAAA/wAAAP9/f3//////////////////6enp/9DQ0P/q6ur/4ODg////////////////////
        /////////////+Dg4P/r6+v//////////////////////yAgIP8AAAD/AAAAnwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/AAAA/39/f///////////////////////////////////////////////////////////////////////////////////////////////////////ICAg/wAAAP8A
        AACfAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AAAD/f39////////////////////////h4eH/qamp/62trf/4+Pj///////////////////////////////////////////////////////////8gICD/AAAA/wAAAJ8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/wAAAP9/f3//
        /////////////////////4SEhP8AAAD/X19f////////////+vr6/+/v7//4+Pj////////////8/Pz/7+/v//T09P///////////yAgIP8AAAD/AAAAnwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/AAAA/39/f/////////////X19f9eXl7/AwMD/wAAAP8EBAT/YWFh//b29v+np6f/AAAA
        /zw8PP///////////3t7e/8AAAD/TU1N////////////ICAg/wAAAP8AAACfAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AAAD/f39/////////////Xl5e/wAAAP8SEhL/Q0ND/w8PD/8AAAD/Y2Nj//T09P8MDAz/AAAA/wYGBv8ICAj/AgIC/wAAAP+pqan///////////8gICD/AAAA/wAA
        AJ8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/wAAAP9/f3///////+rq6v8CAgL/DAwM/+Pj4///////29vb/wgICP8EBAT/7+/v/11dXf8AAAD/Gxsb/ycnJ/8AAAD/EhIS//f39////////////yAgIP8AAAD/AAAAnwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/AAAA/39/f///
        ////yMjI/wAAAP88PDz/////////////////MzMz/wAAAP/Q0ND/u7u7/wAAAP9WVlb/lpaW/wAAAP9sbGz/////////////////ICAg/wAAAP8AAACfAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AAAD/f39////////e3t7/AAAA/xgYGP/39/f///////Pz8/8SEhL/AAAA/+bm5v/9/f3/
        HBwc/wsLC/86Ojr/AAAA/8/Pz/////////////////8gICD/AAAA/wAAAJ8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/wAAAP9/f3////////////87Ozv/AAAA/zo6Ov+Dg4P/NDQ0/wAAAP9ERET///////////94eHj/AAAA/wAAAP80NDT//////////////////////yAgIP8AAAD/AAAA
        nwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/AAAA/39/f////////////97e3v8kJCT/AAAA/wAAAP8AAAD/KSkp/+Pj4////////////9XV1f8AAAD/AAAA/5mZmf//////////////////////ICAg/wAAAP8AAACfAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AAAD/f39/////
        //////////////b29v+pqan/ioqK/6ysrP/4+Pj//////////////////////6ioqP+jo6P/9fX1//////////////////////8gICD/AAAA/wAAAJ8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/wAAAP9/f3//////////////////////////////////////////////////////////////
        /////////////////////////////////////////yAgIP8AAAD/AAAAnwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/AAAA/39/f///////////////////////////////////////////////////////////////////////////////////////////////////////ICAg/wAAAP8AAACf
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AAAD/QEBA/39/f/9/f3//f39//39/f/9/f3//f39//39/f/9/f3//f39//39/f/9/f3//f39//39/f/9/f3//f39//39/f/9/f3//f39//39/f/8QEBD/AAAA/wAAAJ8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA1wAAAP8AAAD/AAAA
        /wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAAeAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwAAAA0gAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAA
        AP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/BQUF/wAAAKAAAAAHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADP8AABh/AAAAPwAAAD8AAAAfAAAADwAAAg8AAAMHAAABAwAAAIMAAADBAAAAQAAAAGAAAABwAAAAcAAAAH8AAAB/AAAAfwAAAH8AAAB/AAAAfwAAAH8AAAB/AAAAfwAAAH8A
        AAB/AAAAfwAAAH8AAAB/AAAAfwAAAH8AAAB/KAAAABAAAAAgAAAAAQAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALYAAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA+wAAAFcAmQAaAJkAnQCZAA8AAAAAAAAAAAAAAAAAAAD/j4+P/7+/v/+/v7//v7+//7+/v/+/v7//v7+//9LS0v/l9eX/
        Jqgm/wCZAP8AmQCgAAAAAAAAAAAAAAAAAAAA/7+/v//////////////////////////////////l9eX/Jqgm/wecB/8AmQDDAJkA/wCZAE4AAAAAAAAAAAAAAP+/v7//////////////////////////////////z+zP/xOhE/+v36//AJkAEACZAOMAmQDoAJkAFAAAAAAAAAD/v7+/////////////////
        ///////////////////////3/Pf//////wAAAEQAmQBHAJkA/gCZAKsAAAAAAAAA/7+/v//9/f3/s7Oz/9XV1f/Ozs7/w8PD/76+vv/R0dH/4ODg//////8AAADcAAAAGACZAJgAmQD/AJkAWQAAAP+/v7//5eXl/5SUlP+JiYn/kJCQ/5GRkf+enp7/eHh4/93d3f//////AAAA7wAAAFAAmQAMAJkA3QCZ
        AOMAAAD/v7+////////u7u7/8vLy//////////////////Ly8v///////////xAQEP8AAABQAAAAAACZACsAmQAmAAAA/7+/v///////2dnZ/21tbf/9/f3/+vr6//39/f/+/v7/+Pj4//////8QEBD/AAAAUAAAAAAAAAAAAAAAAAAAAP+/v7//1NTU/x0dHf8VFRX/b29v/2pqav9QUFD/YWFh/z09Pf//
        ////EBAQ/wAAAFAAAAAAAAAAAAAAAAAAAAD/v7+//21tbf+Li4v/9vb2/xAQEP+2trb/HBwc/y8vL/+dnZ3//////xAQEP8AAABQAAAAAAAAAAAAAAAAAAAA/7+/v/+Ghob/UlJS/6qqqv8WFhb/+Pj4/ygoKP8cHBz/8/Pz//////8QEBD/AAAAUAAAAAAAAAAAAAAAAAAAAP+/v7//9/f3/3Fxcf9NTU3/
        wcHB//////+fn5//jIyM////////////EBAQ/wAAAFAAAAAAAAAAAAAAAAAAAAD/v7+//////////////////////////////////////////////////xAQEP8AAABQAAAAAAAAAAAAAAAAAAAA/4+Pj/+/v7//v7+//7+/v/+/v7//v7+//7+/v/+/v7//v7+//7+/v/8MDAz/AAAAUAAAAAAAAAAAAAAA
        AAAAALYAAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/GRkZ/wAAACAAAAAAAAAAAAAAAAAABwAAAAcAAAADAAAAAQAAAAEAAAAAAAAAAAAAAAQAAAAHAAAABwAAAAcAAAAHAAAABwAAAAcAAAAHAAAABwAA')
    $MainFORM.Add_Load($MainFORM_Load)
    $MainFORM.Add_FormClosing($MainFORM_FormClosing)
    $MainFORM.SuspendLayout()

    $tab_Pages                          = New-Object 'System.Windows.Forms.TabControl'
    $tab_Pages.Location                 = ' 12,  12'
    $tab_Pages.Size                     = '770, 608'
    $tab_Pages.Padding                  = ' 12,   6'
    $tab_Pages.SelectedIndex            = 0
    $tab_Pages.TabIndex                 = 0
    $tab_Pages.Add_SelectedIndexChanged($tab_Pages_SelectedIndexChanged)
    $MainFORM.Controls.Add($tab_Pages)
    $tab_Pages.SuspendLayout()

    #
    $tab_Page1                          = New-Object 'System.Windows.Forms.TabPage'
    $tab_Page1.TabIndex                 = 0
    $tab_Page1.BackColor                = 'Control'
    $tab_Page1.Text                     = 'Introduction'
    $tab_Pages.Controls.Add($tab_Page1)
    $tab_Page1.SuspendLayout()

    #
    $tab_Page2                          = New-Object 'System.Windows.Forms.TabPage'
    $tab_Page2.TabIndex                 = 1
    $tab_Page2.BackColor                = 'Control'
    $tab_Page2.Text                     = 'Select Required Checks'
    $tab_Pages.Controls.Add($tab_Page2)
    $tab_Page2.SuspendLayout()

    #
    $tab_Page3                          = New-Object 'System.Windows.Forms.TabPage'
    $tab_Page3.TabIndex                 = 2
    $tab_Page3.BackColor                = 'Control'
    $tab_Page3.Text                     = 'QA Check Values'
    $tab_Pages.Controls.Add($tab_Page3)
    $tab_Page3.SuspendLayout()

    #
    $tab_Page4                          = New-Object 'System.Windows.Forms.TabPage'
    $tab_Page4.TabIndex                 = 3
    $tab_Page4.BackColor                = 'Control'
    $tab_Page4.Text                     = 'Generate QA'
    $tab_Pages.Controls.Add($tab_Page4)
    $tab_Page4.SuspendLayout()

    #
    $btn_RestoreINI                     = New-Object 'System.Windows.Forms.Button'
    $btn_RestoreINI.Location            = ' 12, 635'
    $btn_RestoreINI.Size                = '125,  25'
    $btn_RestoreINI.TabIndex            = 100
    $btn_RestoreINI.Text                = 'Restore Settings File'
    $btn_RestoreINI.Add_Click($btn_RestoreINI_Click)
    $MainFORM.Controls.Add($btn_RestoreINI)

    #
    $btn_Exit                           = New-Object 'System.Windows.Forms.Button'
    $btn_Exit.Location                  = '707, 635'
    $btn_Exit.Size                      = '75, 25'
    $btn_Exit.TabIndex                  = 97
    $btn_Exit.Text                      = 'Exit'
    $btn_Exit.DialogResult              = [System.Windows.Forms.DialogResult]::Cancel    # Use this instead of a 'Click' event
    $MainFORM.CancelButton              = $btn_Exit
    $MainFORM.Controls.Add($btn_Exit)

    #
    $lbl_ChangesMade                    = New-Object 'System.Windows.Forms.Label'
    $lbl_ChangesMade.Location           = ' 12, 625'
    $lbl_ChangesMade.Size               = '680,  45'
    $lbl_ChangesMade.Text               = "NOTE: If you make any selection changes and click 'Next', any unsaved changes will be lost."
    $lbl_ChangesMade.TextAlign          = 'MiddleLeft'
    $lbl_ChangesMade.Visible            = $False
    $MainFORM.Controls.Add($lbl_ChangesMade)

    #
    $tim_CompleteTimer               = New-Object 'System.Windows.Forms.Timer'
    $tim_CompleteTimer.Stop()
    $tim_CompleteTimer.Interval      = 1000    # 1 Second
    $tim_CompleteTimer.Add_Tick($tim_CompleteTimer_Tick)

    # All 16x16 Icons
    $img_ListImages                     = New-Object 'System.Windows.Forms.ImageList'
    $img_ListImages.TransparentColor    = 'Transparent'
    $img_ListImages_BinaryFomatter      = New-Object 'System.Runtime.Serialization.Formatters.Binary.BinaryFormatter'
    $img_ListImages_MemoryStream        = New-Object 'System.IO.MemoryStream' (,[byte[]][System.Convert]::FromBase64String('
        AAEAAAD/////AQAAAAAAAAAMAgAAAFdTeXN0ZW0uV2luZG93cy5Gb3JtcywgVmVyc2lvbj00LjAuMC4wLCBDdWx0dXJlPW5ldXRyYWwsIFB1YmxpY0tleVRva2VuPWI3N2E1YzU2MTkzNGUwODkFAQAAACZTeXN0ZW0uV2luZG93cy5Gb3Jtcy5JbWFnZUxpc3RTdHJlYW1lcgEAAAAERGF0YQcCAgAAAAkD
        AAAADwMAAACeCgAAAk1TRnQBSQFMAgEBAwEAAYgBAAGIAQABEAEAARABAAT/AQkBAAj/AUIBTQE2AQQGAAE2AQQCAAEoAwABQAMAARADAAEBAQABCAYAAQQYAAGAAgABgAMAAoABAAGAAwABgAEAAYABAAKAAgADwAEAAcAB3AHAAQAB8AHKAaYBAAEzBQABMwEAATMBAAEzAQACMwIAAxYBAAMcAQADIgEA
        AykBAANVAQADTQEAA0IBAAM5AQABgAF8Af8BAAJQAf8BAAGTAQAB1gEAAf8B7AHMAQABxgHWAe8BAAHWAucBAAGQAakBrQIAAf8BMwMAAWYDAAGZAwABzAIAATMDAAIzAgABMwFmAgABMwGZAgABMwHMAgABMwH/AgABZgMAAWYBMwIAAmYCAAFmAZkCAAFmAcwCAAFmAf8CAAGZAwABmQEzAgABmQFmAgAC
        mQIAAZkBzAIAAZkB/wIAAcwDAAHMATMCAAHMAWYCAAHMAZkCAALMAgABzAH/AgAB/wFmAgAB/wGZAgAB/wHMAQABMwH/AgAB/wEAATMBAAEzAQABZgEAATMBAAGZAQABMwEAAcwBAAEzAQAB/wEAAf8BMwIAAzMBAAIzAWYBAAIzAZkBAAIzAcwBAAIzAf8BAAEzAWYCAAEzAWYBMwEAATMCZgEAATMBZgGZ
        AQABMwFmAcwBAAEzAWYB/wEAATMBmQIAATMBmQEzAQABMwGZAWYBAAEzApkBAAEzAZkBzAEAATMBmQH/AQABMwHMAgABMwHMATMBAAEzAcwBZgEAATMBzAGZAQABMwLMAQABMwHMAf8BAAEzAf8BMwEAATMB/wFmAQABMwH/AZkBAAEzAf8BzAEAATMC/wEAAWYDAAFmAQABMwEAAWYBAAFmAQABZgEAAZkB
        AAFmAQABzAEAAWYBAAH/AQABZgEzAgABZgIzAQABZgEzAWYBAAFmATMBmQEAAWYBMwHMAQABZgEzAf8BAAJmAgACZgEzAQADZgEAAmYBmQEAAmYBzAEAAWYBmQIAAWYBmQEzAQABZgGZAWYBAAFmApkBAAFmAZkBzAEAAWYBmQH/AQABZgHMAgABZgHMATMBAAFmAcwBmQEAAWYCzAEAAWYBzAH/AQABZgH/
        AgABZgH/ATMBAAFmAf8BmQEAAWYB/wHMAQABzAEAAf8BAAH/AQABzAEAApkCAAGZATMBmQEAAZkBAAGZAQABmQEAAcwBAAGZAwABmQIzAQABmQEAAWYBAAGZATMBzAEAAZkBAAH/AQABmQFmAgABmQFmATMBAAGZATMBZgEAAZkBZgGZAQABmQFmAcwBAAGZATMB/wEAApkBMwEAApkBZgEAA5kBAAKZAcwB
        AAKZAf8BAAGZAcwCAAGZAcwBMwEAAWYBzAFmAQABmQHMAZkBAAGZAswBAAGZAcwB/wEAAZkB/wIAAZkB/wEzAQABmQHMAWYBAAGZAf8BmQEAAZkB/wHMAQABmQL/AQABzAMAAZkBAAEzAQABzAEAAWYBAAHMAQABmQEAAcwBAAHMAQABmQEzAgABzAIzAQABzAEzAWYBAAHMATMBmQEAAcwBMwHMAQABzAEz
        Af8BAAHMAWYCAAHMAWYBMwEAAZkCZgEAAcwBZgGZAQABzAFmAcwBAAGZAWYB/wEAAcwBmQIAAcwBmQEzAQABzAGZAWYBAAHMApkBAAHMAZkBzAEAAcwBmQH/AQACzAIAAswBMwEAAswBZgEAAswBmQEAA8wBAALMAf8BAAHMAf8CAAHMAf8BMwEAAZkB/wFmAQABzAH/AZkBAAHMAf8BzAEAAcwC/wEAAcwB
        AAEzAQAB/wEAAWYBAAH/AQABmQEAAcwBMwIAAf8CMwEAAf8BMwFmAQAB/wEzAZkBAAH/ATMBzAEAAf8BMwH/AQAB/wFmAgAB/wFmATMBAAHMAmYBAAH/AWYBmQEAAf8BZgHMAQABzAFmAf8BAAH/AZkCAAH/AZkBMwEAAf8BmQFmAQAB/wKZAQAB/wGZAcwBAAH/AZkB/wEAAf8BzAIAAf8BzAEzAQAB/wHM
        AWYBAAH/AcwBmQEAAf8CzAEAAf8BzAH/AQAC/wEzAQABzAH/AWYBAAL/AZkBAAL/AcwBAAJmAf8BAAFmAf8BZgEAAWYC/wEAAf8CZgEAAf8BZgH/AQAC/wFmAQABIQEAAaUBAANfAQADdwEAA4YBAAOWAQADywEAA7IBAAPXAQAD3QEAA+MBAAPqAQAD8QEAA/gBAAHwAfsB/wEAAaQCoAEAA4ADAAH/AgAB
        /wMAAv8BAAH/AwAB/wEAAf8BAAL/AgAD/xUAAfMB/wEAAe8BkQEAAf8B8QH/BwAC/wEAAfQB8wEAAf8B9ScAAfEBtQHxAfMCkQHxAQcBrgHxBgAB9AHzAfQB/wLzAfUB9AHzAfUZAAP0CgAB8wK1A7sCtQGRAfIGAAH/A/MB9ATzAfUXAAL0AbUBjAG1AvQGAALzAe4BuwHwArwBCQG7ArUB7wHzAfICAAL/
        B/QC8wH0Av8UAAH0Ae4BjAGvAYwBrwGMAe4B9AQAAf8CuwEJAd0BCQO7ArUBuwG1ApEC/wH0AfMG9AbzAf8SAAH0Aa8BjAG8AfQBjAH0AbwBjAGvAfQEAAH0AQkBGQEJAbsB9AIAAfMCtQG7AZEB8wIAAf8E9AH/AgAB/wLzAfQB8wH/EwAB9AGMA/QBjAP0AYwB9AQAAfQBuwHwAbsB8gQAAfIBtQG7Ae0B
        9AIAAf8C9AHzAf8EAAH1AfMB9AHzAf8TAAH0AYwC9AHwAYwB8AL0AYwB9AMAArsBCQHwAfcFAAH/AbUBuwG1ApEE9AHzBQAB/wHzAfQD8xIAAfQBjAHzAbUBrwHxAa8BtQHzAYwB9AMAAfADCQGRBQAB9QG1AbsCtQEHBPQB8wUAAf8B8wH0AvMB9BIAAfQBjAGNAbwD9AG8AY0BjAH0BAAB/wG7ARkBtQHw
        BAAB8QK7AbUB/wIAAf8C9AHzAfQEAAH0AfMB9AHzFAAB9AGvAYwBvAP0AbwBjAGvAfQDAAH/AfABCQHxAQkB9wEHAv8B7gG7AQcBuwG1AQcBAAH/BPQB8wH0Av8E9AHzAfQUAAH0Ae4BjAGvAfEBrwGMAe4B9AQAAf8CuwEJARkBvAG7ArUEuwG1AZEBAAH/BfQD8wP0A/MVAAL0AbUBjAG1AvQGAAP0AQkD
        8QHwAQkCuwHyAvQCAAP/CPQB9QL/FwAD9AoAAfQBuwQJAbsCtQHzBgAB/wX0A/MB/yYAAfQBBwH0Af8CuwH0AfIBuwH0BgAB/wH0Av8C9AH/AfUB9AH/KgAB7gG7DgAC9BcAAUIBTQE+BwABPgMAASgDAAFAAwABEAMAAQEBAAEBBQABgBcAA/8BAAL/AfIBRwHyAU8CAAL/AeABBwHgAQcCAAH8AX8B4AEH
        AeABBwIAAfABHwGAAQEBgAEBAgAB4AEPBgABwAEHBIECAAHAAQcBgwHBAYMBwQIAAcACBwHAAQcBwAIAAcACBwHAAQcBwAIAAcABBwGDAcEBgwHDAgABwAEHAQABAQEAAQECAAHgAQ8BAAEBAQABAQIAAfABHwGAAQEBgAEBAgAB/AF/AeABBwHgAQcCAAL/AeABBwHgAQcCAAL/Af4BfwH+AX8CAAs='))
    $img_ListImages.ImageStream         = $img_ListImages_BinaryFomatter.Deserialize($img_ListImages_MemoryStream)
    $img_ListImages_BinaryFomatter      = $null
    $img_ListImages_MemoryStream        = $null
#endregion
#region TAB 1 - Introduction / Select Location / Import
    #
    $lbl_t1_Welcome                     = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_Welcome.Location            = '  9,   9'
    $lbl_t1_Welcome.Size                = '744,  20'
    $lbl_t1_Welcome.Text                = 'Welcome.!'
    $lbl_t1_Welcome.TextAlign           = 'BottomLeft'
    $tab_Page1.Controls.Add($lbl_t1_Welcome)

    #
    $lbl_t1_Introduction                = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_Introduction.Location       = '9, 35'
    $lbl_t1_Introduction.Size           = '744, 235'
    $lbl_t1_Introduction.TextAlign      = 'TopLeft'
    $lbl_t1_Introduction.Text           = @"
This script will help you create a custom settings file for the QA checks, one that is tailored for your environment.


It will allow you to select which checks you want to use and which to skip.  You will also be able to set specific values for each of the check settings.  For a more detailed description on using this script, please read the documentation.





To start, click the 'Set Check Location' button below...
"@
    $tab_Page1.Controls.Add($lbl_t1_Introduction)

    #
    $btn_t1_Search                      = New-Object 'System.Windows.Forms.Button'
    $btn_t1_Search.Location             = '306, 325'
    $btn_t1_Search.Size                 = '150, 35'
    $btn_t1_Search.Text                 = 'Set Check Location'
    $btn_t1_Search.TabIndex             = 0
    $btn_t1_Search.Add_Click($btn_t1_Search_Click)
    $tab_Page1.Controls.Add($btn_t1_Search)

    #
    $lbl_t1_Language                    = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_Language.Location           = '  9, 387'
    $lbl_t1_Language.Size               = '291,  21'
    $lbl_t1_Language.Text               = 'Language :'
    $lbl_t1_Language.TextAlign          = 'MiddleRight'
    $tab_Page1.Controls.Add($lbl_t1_Language)

    #
    $cmo_t1_Language                    = New-Object 'System.Windows.Forms.ComboBox'
    $cmo_t1_Language.Location           = '306, 387'
    $cmo_t1_Language.Size               = '150,  21'
    $cmo_t1_Language.DropDownStyle      = 'DropDownList'
    $cmo_t1_Language.Enabled            = $False
    $cmo_t1_Language.TabIndex           = 1
    $cmo_t1_Language.Add_SelectedIndexChanged({ cmo_t1_SelectedIndexChanged })
    $tab_Page1.Controls.Add($cmo_t1_Language)
    
    # lbl_t1_SettingsFile
    $lbl_t1_SettingsFile                = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_SettingsFile.Location       = '  9, 423'
    $lbl_t1_SettingsFile.Size           = "291,  21"
    $lbl_t1_SettingsFile.Text           = 'Base Settings File :'
    $lbl_t1_SettingsFile.TextAlign      = 'MiddleRight'
    $tab_Page1.Controls.Add($lbl_t1_SettingsFile)

    #
    $cmo_t1_SettingsFile                = New-Object 'System.Windows.Forms.ComboBox'
    $cmo_t1_SettingsFile.Location       = '306, 423'
    $cmo_t1_SettingsFile.Size           = "150,  21"
    $cmo_t1_SettingsFile.DropDownStyle  = 'DropDownList'
    $cmo_t1_SettingsFile.Enabled        = $False
    $cmo_t1_SettingsFile.TabIndex       = 2
    $cmo_t1_SettingsFile.Add_SelectedIndexChanged({ cmo_t1_SelectedIndexChanged })
    $tab_Page1.Controls.Add($cmo_t1_SettingsFile)

    #
    $lbl_t1_MissingFile                 = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_MissingFile.Location        = '462, 423'
    $lbl_t1_MissingFile.Size            = "291,  21"
    $lbl_t1_MissingFile.Text            = "'default-settings.ini' file not found"
    $lbl_t1_MissingFile.TextAlign       = 'MiddleLeft'
    $lbl_t1_MissingFile.Visible         = $False
    $tab_Page1.Controls.Add($lbl_t1_MissingFile)

    #
    $btn_t1_Import                      = New-Object 'System.Windows.Forms.Button'
    $btn_t1_Import.Location             = '306, 471'
    $btn_t1_Import.Size                 = '150,  35'
    $btn_t1_Import.Text                 = 'Import Settings'
    $btn_t1_Import.Enabled              = $False
    $btn_t1_Import.TabIndex             = 3
    $btn_t1_Import.Add_Click($btn_t1_Import_Click)
    $tab_Page1.Controls.Add($btn_t1_Import)

    #
    $lbl_t1_ScanningScripts             = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_ScanningScripts.Location    = '  9, 547'
    $lbl_t1_ScanningScripts.Size        = '744,  20'
    $lbl_t1_ScanningScripts.Text        = ''
    $lbl_t1_ScanningScripts.TextAlign   = 'BottomLeft'
    $lbl_t1_ScanningScripts.Visible     = $False
    $tab_Page1.Controls.Add($lbl_t1_ScanningScripts)
#endregion
#region TAB 2 - Select QA Checkes To Include
    #
    $lbl_t2_CheckSelection              = New-Object 'System.Windows.Forms.Label'
    $lbl_t2_CheckSelection.Location     = '  9,   9'
    $lbl_t2_CheckSelection.Size         = '744,  20'
    $lbl_t2_CheckSelection.Text         = 'Select the QA checks you want to enable for this settings file:'
    $lbl_t2_CheckSelection.TextAlign    = 'BottomLeft'
    $tab_Page2.Controls.Add($lbl_t2_CheckSelection)

    # lst_t2_SelectChecks
    $lst_t2_SelectChecks                = New-Object 'System.Windows.Forms.ListView'
    $lst_t2_SelectChecks_CH_Code        = New-Object 'System.Windows.Forms.ColumnHeader'
    $lst_t2_SelectChecks_CH_Name        = New-Object 'System.Windows.Forms.ColumnHeader'
    $lst_t2_SelectChecks_CH_Desc        = New-Object 'System.Windows.Forms.ColumnHeader'
    $lst_t2_SelectChecks.CheckBoxes     = $True
    $lst_t2_SelectChecks.HeaderStyle    = 'Nonclickable'
    $lst_t2_SelectChecks.FullRowSelect  = $True
    $lst_t2_SelectChecks.GridLines      = $False
    $lst_t2_SelectChecks.LabelWrap      = $False
    $lst_t2_SelectChecks.MultiSelect    = $False
    $lst_t2_SelectChecks.Location       = '  9,  35'
    $lst_t2_SelectChecks.Size           = '466, 492'
    $lst_t2_SelectChecks.View           = 'Details'
    $lst_t2_SelectChecks.SmallImageList = $img_ListImages
    $lst_t2_SelectChecks.Sorting        = 'Ascending'
    $lst_t2_SelectChecks_CH_Code.Text   = 'Check'
    $lst_t2_SelectChecks_CH_Name.Text   = 'Name'
    $lst_t2_SelectChecks_CH_Desc.Text   = ''         # Description
    $lst_t2_SelectChecks_CH_Code.Width  = 100
    $lst_t2_SelectChecks_CH_Name.Width  = 366 - ([System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth + 4)
    $lst_t2_SelectChecks_CH_Desc.Width  =   0
    $lst_t2_SelectChecks.Columns.Add($lst_t2_SelectChecks_CH_Code) | Out-Null
    $lst_t2_SelectChecks.Columns.Add($lst_t2_SelectChecks_CH_Name) | Out-Null
    $lst_t2_SelectChecks.Columns.Add($lst_t2_SelectChecks_CH_Desc) | Out-Null
    $lst_t2_SelectChecks.Add_Enter($lst_t2_SelectChecks_Enter)
    $lst_t2_SelectChecks.Add_ItemChecked($lst_t2_SelectChecks_ItemChecked)
    $lst_t2_SelectChecks.Add_SelectedIndexChanged($lst_t2_SelectChecks_SelectedIndexChanged)
    $tab_Page2.Controls.Add($lst_t2_SelectChecks)

    #
    $lbl_t2_Description                 = New-Object 'System.Windows.Forms.Label'
    $lbl_t2_Description.BackColor       = 'Window'
    $lbl_t2_Description.Location        = '475,  36'
    $lbl_t2_Description.Size            = '277, 449'
    $lbl_t2_Description.Padding         = '3, 3, 3, 3'    # Internal padding
    $lbl_t2_Description.Text            = ''              # Description of the selected check - set via code
    $lbl_t2_Description.TextAlign       = 'TopLeft'
    $tab_Page2.Controls.Add($lbl_t2_Description)

    #
    $lbl_t2_SelectedCount               = New-Object 'System.Windows.Forms.Label'
    $lbl_t2_SelectedCount.Location      = '  9, 542'
    $lbl_t2_SelectedCount.Size          = '189,  25'
    $lbl_t2_SelectedCount.Text          = '0 of 0 checks selected'
    $lbl_t2_SelectedCount.TextAlign     = 'MiddleLeft'
    $tab_Page2.Controls.Add($lbl_t2_SelectedCount)

    #
    $lbl_t2_Select                      = New-Object 'System.Windows.Forms.Label'
    $lbl_t2_Select.Location             = '204, 542'
    $lbl_t2_Select.Size                 = ' 90,  25'
    $lbl_t2_Select.Text                 = 'Select :'
    $lbl_t2_Select.TextAlign            = 'MiddleRight'
    $tab_Page2.Controls.Add($lbl_t2_Select)

    #
    $btn_t2_SelectAll                   = New-Object 'System.Windows.Forms.Button'
    $btn_t2_SelectAll.Location          = '300, 542'
    $btn_t2_SelectAll.Size              = ' 50,  25'
    $btn_t2_SelectAll.Text              = 'All'
    $btn_t2_SelectAll.Enabled           = $False
    $btn_t2_SelectAll.Add_Click({ btn_t2_SelectButtons -SourceButton 'SelectAll' })
    $tab_Page2.Controls.Add($btn_t2_SelectAll)

    #
    $btn_t2_SelectInv                   = New-Object 'System.Windows.Forms.Button'
    $btn_t2_SelectInv.Location          = '356, 542'
    $btn_t2_SelectInv.Size              = ' 50,  25'
    $btn_t2_SelectInv.Text              = 'Inv'
    $btn_t2_SelectInv.Enabled           = $False
    $btn_t2_SelectInv.Add_Click({ btn_t2_SelectButtons -SourceButton 'SelectInv' })
    $tab_Page2.Controls.Add($btn_t2_SelectInv)

    #
    $btn_t2_SelectNone                  = New-Object 'System.Windows.Forms.Button'
    $btn_t2_SelectNone.Location         = '412, 542'
    $btn_t2_SelectNone.Size             = ' 50,  25'
    $btn_t2_SelectNone.Text             = 'None'
    $btn_t2_SelectNone.Enabled          = $False
    $btn_t2_SelectNone.Add_Click({ btn_t2_SelectButtons -SourceButton 'SelectNone' })
    $tab_Page2.Controls.Add($btn_t2_SelectNone)

    #
    $btn_t2_SelectReset                 = New-Object 'System.Windows.Forms.Button'
    $btn_t2_SelectReset.Location        = '468, 542'
    $btn_t2_SelectReset.Size            = ' 50,  25'
    $btn_t2_SelectReset.Text            = 'Reset'
    $btn_t2_SelectReset.Enabled         = $False
    $btn_t2_SelectReset.Add_Click({ btn_t2_SelectButtons -SourceButton 'SelectReset' })
    $tab_Page2.Controls.Add($btn_t2_SelectReset)

    #
    $btn_t2_SetValues                   = New-Object 'System.Windows.Forms.Button'
    $btn_t2_SetValues.Location          = '648, 542'
    $btn_t2_SetValues.Size              = '105,  25'
    $btn_t2_SetValues.Text              = 'Set Values  >'
    $btn_t2_SetValues.Enabled           = $False
    $btn_t2_SetValues.Add_Click($btn_t2_SetValues_Click)
    $tab_Page2.Controls.Add($btn_t2_SetValues)
    $btn_t2_SetValues.BringToFront()

    #
    $pic_t2_Background                  = New-Object 'System.Windows.Forms.PictureBox'
    $pic_t2_Background.Location         = '474,  35'
    $pic_t2_Background.Size             = '279, 492'
    $pic_t2_Background.BackColor        = 'Window'
    $pic_t2_Background.BorderStyle      = 'FixedSingle'
    $pic_t2_Background.SendToBack()
    $tab_Page2.Controls.Add($pic_t2_Background)
#endregion
#region TAB 3 - Enter Values For Checks
    #
    $lbl_t3_NoChecks                    = New-Object 'System.Windows.Forms.Label'
    $lbl_t3_NoChecks.Location           = '19, 218'
    $lbl_t3_NoChecks.Size               = '724, 50'
    $lbl_t3_NoChecks.Text               = "Enabled QA checks have not been comfirmed yet.`nPlease click 'Set Values >' on the previous tab."
    $lbl_t3_NoChecks.TextAlign          = 'MiddleCenter'
    $lbl_t3_NoChecks.BackColor          = 'Window'
    $lbl_t3_NoChecks.Visible            = $True
    $lbl_t3_NoChecks.BringToFront()
    $tab_Page3.Controls.Add($lbl_t3_NoChecks)

    #
    $lbl_t3_ScriptSelection             = New-Object 'System.Windows.Forms.Label'
    $lbl_t3_ScriptSelection.Location    = '  9,   9'
    $lbl_t3_ScriptSelection.Size        = '744,  20'
    $lbl_t3_ScriptSelection.Text        = 'Double-click an enabled entry to set its value'
    $lbl_t3_ScriptSelection.TextAlign   = 'BottomLeft'
    $tab_Page3.Controls.Add($lbl_t3_ScriptSelection)

    #
    $tab_t3_Pages                       = New-Object 'System.Windows.Forms.TabControl'    # TabPages are generated automatically
    $tab_t3_Pages.Location              = '  9,  35'
    $tab_t3_Pages.Size                  = '744, 492'
    $tab_t3_Pages.Padding               = '  8,   4'
    $tab_t3_Pages.SelectedIndex         = 0
    $tab_t3_Pages.Add_SelectedIndexChanged($tab_t3_Pages_SelectedIndexChanged)
    $tab_Page3.Controls.Add($tab_t3_Pages)

    #
    $lbl_t3_Select                      = New-Object 'System.Windows.Forms.Label'
    $lbl_t3_Select.Location             = '105, 542'
    $lbl_t3_Select.Size                 = '189,  25'
    $lbl_t3_Select.Text                 = 'Section Tabs :'
    $lbl_t3_Select.TextAlign            = 'MiddleRight'
    $tab_Page3.Controls.Add($lbl_t3_Select)

    #
    $btn_t3_PrevTab                     = New-Object 'System.Windows.Forms.Button'
    $btn_t3_PrevTab.Location            = '300, 542'
    $btn_t3_PrevTab.Size                = ' 75,  25'
    $btn_t3_PrevTab.Text                = '<  Prev'
    $btn_t3_PrevTab.Add_Click($btn_t3_PrevTab_Click)
    $tab_Page3.Controls.Add($btn_t3_PrevTab)

    #
    $btn_t3_NextTab                     = New-Object 'System.Windows.Forms.Button'
    $btn_t3_NextTab.Location            = '387, 542'
    $btn_t3_NextTab.Size                = ' 75,  25'
    $btn_t3_NextTab.Text                = 'Next  >'
    $btn_t3_NextTab.Add_Click($btn_t3_NextTab_Click)
    $tab_Page3.Controls.Add($btn_t3_NextTab)

    #
    $btn_t3_Complete                    = New-Object 'System.Windows.Forms.Button'
    $btn_t3_Complete.Location           = '648, 542'
    $btn_t3_Complete.Size               = '105,  25'
    $btn_t3_Complete.Text               = 'Complete  >'
    $btn_t3_Complete.Enabled            = $False
    $btn_t3_Complete.Add_Click($btn_t3_Complete_Click)
    $tab_Page3.Controls.Add($btn_t3_Complete)
#endregion
#region TAB 4 - Generate Settings And QA Script
    #
    $lbl_t4_Complete                    = New-Object 'System.Windows.Forms.Label'
    $lbl_t4_Complete.Location           = '  9,   9'
    $lbl_t4_Complete.Size               = '744,  20'
    $lbl_t4_Complete.Text               = 'Complete.!'
    $lbl_t4_Complete.TextAlign          = 'BottomLeft'
    $tab_Page4.Controls.Add($lbl_t4_Complete)

    #
    $lbl_t4_Complete_Info               = New-Object 'System.Windows.Forms.Label'
    $lbl_t4_Complete_Info.Location      = '  9,  35'
    $lbl_t4_Complete_Info.Size          = '744, 233'
    $lbl_t4_Complete_Info.TextAlign     = 'TopLeft'
    $lbl_t4_Complete_Info.Text          = @"
Enter a short code for this settings file, this will save the QA script file with it as part of the name.
For example: 'QA_ACME_v3.xx.xxxx.ps1'.

Also enter a name or other label for the HTML results file.  This is automatically appended with 'QA Report'.
For example: 'ACME QA Report'.

Click 'Additional Options' to configure futher configuration settings.


Click the 'Save Settings' button below to save your selections and values.
Once done, you can then click 'Generate QA Script' to create the compiled QA script.
"@
    $tab_Page4.Controls.Add($lbl_t4_Complete_Info)

    #
    $lbl_t4_ShortCode                   = New-Object 'System.Windows.Forms.Label'
    $lbl_t4_ShortCode.Location          = '  9, 295'
    $lbl_t4_ShortCode.Size              = '291,  22'
    $lbl_t4_ShortCode.TextAlign         = 'MiddleRight'
    $lbl_t4_ShortCode.Text              = 'Settings Short Code :'
    $tab_Page4.Controls.Add($lbl_t4_ShortCode)

    #
    $txt_t4_ShortCode                   = New-Object 'System.Windows.Forms.TextBox'
    $txt_t4_ShortCode.Location          = '306, 295'
    $txt_t4_ShortCode.Size              = '150,  22'
    $txt_t4_ShortCode.TextAlign         = 'Center'
    $tab_Page4.Controls.Add($txt_t4_ShortCode)

    #
    $lbl_t4_ReportTitle                 = New-Object 'System.Windows.Forms.Label'
    $lbl_t4_ReportTitle.Location        = '  9, 332'
    $lbl_t4_ReportTitle.Size            = '291,  22'
    $lbl_t4_ReportTitle.TextAlign       = 'MiddleRight'
    $lbl_t4_ReportTitle.Text            = 'HTML Report Company Name :'
    $tab_Page4.Controls.Add($lbl_t4_ReportTitle)

    #
    $lbl_t4_QAReport                    = New-Object 'System.Windows.Forms.Label'
    $lbl_t4_QAReport.Location           = '462, 332'
    $lbl_t4_QAReport.Size               = '291,  22'
    $lbl_t4_QAReport.TextAlign          = 'MiddleLeft'
    $lbl_t4_QAReport.Text               = 'QA Report'
    $tab_Page4.Controls.Add($lbl_t4_QAReport)

    #
    $txt_t4_ReportTitle                 = New-Object 'System.Windows.Forms.TextBox'
    $txt_t4_ReportTitle.Location        = '306, 332'
    $txt_t4_ReportTitle.Size            = '150,  22'
    $txt_t4_ReportTitle.TextAlign       = 'Center'
    $tab_Page4.Controls.Add($txt_t4_ReportTitle)

    #
    $btn_t4_Options                     = New-Object 'System.Windows.Forms.Button'
    $btn_t4_Options.Location            = '306, 369'
    $btn_t4_Options.Size                = '150,  25'
    $btn_t4_Options.TabIndex            = 97
    $btn_t4_Options.Text                = 'Additonal Options'
    $btn_t4_Options.Add_Click($btn_t4_Options_Click)
    $tab_Page4.Controls.Add($btn_t4_Options)

    #
    $btn_t4_Save                        = New-Object 'System.Windows.Forms.Button'
    $btn_t4_Save.Location               = '306, 421'
    $btn_t4_Save.Size                   = '150,  35'
    $btn_t4_Save.Text                   = 'Save Settings'
    $btn_t4_Save.Enabled                = $False
    $btn_t4_Save.Add_Click($btn_t4_Save_Click)
    $tab_Page4.Controls.Add($btn_t4_Save)

    #
    $btn_t4_Generate                    = New-Object 'System.Windows.Forms.Button'
    $btn_t4_Generate.Location           = '306, 471'
    $btn_t4_Generate.Size               = '150,  35'
    $btn_t4_Generate.Text               = 'Generate QA Script'
    $btn_t4_Generate.Enabled            = $False
    $btn_t4_Generate.Add_Click($btn_t4_Generate_Click)
    $tab_Page4.Controls.Add($btn_t4_Generate)

    #
    $lbl_t4_Generate                    = New-Object 'System.Windows.Forms.Label'
    $lbl_t4_Generate.Location           = '  9, 512'
    $lbl_t4_Generate.Size               = '744,  20'
    $lbl_t4_Generate.TextAlign          = 'MiddleCenter'
    $lbl_t4_Generate.Text               = ''
    $tab_Page4.Controls.Add($lbl_t4_Generate)
#endregion
#endregion
###################################################################################################
    $InitialFormWindowState = $MainFORM.WindowState
    $MainFORM.Add_Load($MainFORM_StateCorrection_Load)
    Return $MainFORM.ShowDialog()
}
###################################################################################################
#region Variables
        [boolean] $script:ShowChangesMade     = $False    # Show/Hide message at bottom of tab 2
        [boolean] $script:UpdateSelectedCount = $False    # Speeds up processing of All/Inv/None buttons
        [string]  $script:saveFile            = ''
        [int]     $TimerTick                  = 0
        [psobject]$script:settings            = New-Object -TypeName PSObject -Property @{
            'Timeout'        = '60';
            'Concurrent'     = '5';
            'OutputLocation' = '$env:SystemDrive\QA\Results\'
        }
Try   { [string]  $script:ExecutionFolder     = (Split-Path -Path ((Get-Variable MyInvocation -ValueOnly -ErrorAction SilentlyContinue).MyCommand.Path) -ErrorAction SilentlyContinue) }
Catch { [string]  $script:ExecutionFolder     = '' }
#endregion
###################################################################################################
Display-MainForm | Out-Null
Write-Host '  Goodbye.!'
Write-Host ''
