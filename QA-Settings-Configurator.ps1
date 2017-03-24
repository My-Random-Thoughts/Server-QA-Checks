#Requires -version 4
Remove-Variable * -ErrorAction SilentlyContinue
Set-StrictMode    -Version 2
Clear-Host

[Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Data')             | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Drawing')          | Out-Null
[System.Drawing.Font]$sysFont     =                                   [System.Drawing.SystemFonts]::MessageBoxFont
[System.Drawing.Font]$sysFontBold = New-Object 'System.Drawing.Font' ([System.Drawing.SystemFonts]::MessageBoxFont.Name, [System.Drawing.SystemFonts]::MessageBoxFont.SizeInPoints, [System.Drawing.FontStyle]::Bold)
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
        $foldername = New-Object 'System.Windows.Forms.FolderBrowserDialog'
        $foldername.RootFolder          = 'MyComputer'
        $foldername.Description         = $Description
        $foldername.ShowNewFolderButton = $ShowNewFolderButton
        If ([string]::IsNullOrEmpty($initialDirectory) -eq $False) { $foldername.SelectedPath = $initialDirectory }
        If ($foldername.ShowDialog($MainForm) -eq [System.Windows.Forms.DialogResult]::OK) { $return = $($foldername.SelectedPath) }
        Try { $foldername.Dispose() } Catch {}
    }
    Else
    {
        # Workaround for MTA not showing the dialog box.
        # Initial Directory is not possible when using the COM Object
        $comObject  = New-Object -ComObject 'Shell.Application'
        $foldername = $comObject.BrowseForFolder(0, $Description, 0, 0)
        If ([string]::IsNullOrEmpty($foldername) -eq $False) { $return = $($foldername.Self.Path) } Else { $return = '' }
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($comObject) | Out-Null    # Dispose COM object
    }
    Return $return
}

Function Get-File ( [string]$InitialDirectory, [string]$Title )
{
    [string]$return = ''
    $filename = New-Object 'System.Windows.Forms.OpenFileDialog'
    $filename.InitialDirectory = $InitialDirectory
    $filename.Multiselect      = $true
    $filename.Title            = $Title
    $filename.Filter           = 'Compiled QA Scripts (*.ps1)|*.ps1'
    If ([threading.thread]::CurrentThread.GetApartmentState() -ne 'STA') { $filename.ShowHelp = $true }    # Workaround for MTA issues not showing dialog box
    If ($filename.ShowDialog($MainFORM) -eq [System.Windows.Forms.DialogResult]::OK) { $return = ($filename.FileName) }
    Try { $filename.Dispose() } Catch {}
    Return $return
}

Function Save-File ( [string]$InitialDirectory, [string]$Title, [string]$InitialFileName )
{
    [string]$return = ''
    $filename = New-Object 'System.Windows.Forms.SaveFileDialog'
    $filename.InitialDirectory = $InitialDirectory
    $filename.Title            = $Title
    $filename.FileName         = $InitialFileName
    $filename.Filter           = 'QA Configuration Settings (*.ini)|*.ini|All Files|*.*'
    If ([threading.thread]::CurrentThread.GetApartmentState() -ne 'STA') { $filename.ShowHelp = $true }    # Workaround for MTA issues not showing dialog box
    If ($filename.ShowDialog($MainForm) -eq [System.Windows.Forms.DialogResult]::OK) { $return = ($filename.FileName) }
    Try { $filename.Dispose() } Catch {}
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
    If ($Enabled  -eq $false)
    {
        $listitem.ForeColor  = 'GrayText'    # Make the item look disabled
        $listitem.ImageIndex = -1            # Remove the icon
    }
}

Function Load-IniFile ( [string]$Inputfile )
{
    [string]   $comment = ";"
    [string]   $header  = "^\s*(?!$($comment))\s*\[\s*(.*[^\s*])\s*]\s*$"
    [string]   $item    = "^\s*(?!$($comment))\s*([^=]*)\s*=\s*(.*)\s*$"
    [hashtable]$ini     = @{}
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
        [parameter(Mandatory=$true )] [string]  $Type,
        [parameter(Mandatory=$true )] [string]  $Title,
        [parameter(Mandatory=$true )] [string]  $Description,
        [parameter(Mandatory=$false)] [string]  $Validation = 'None',
        [parameter(Mandatory=$false)] [string[]]$InputList,
        [parameter(Mandatory=$false)] [string[]]$CurrentValue
    )

    # [ValidateSet('Simple', 'Check', 'Option', 'List', 'Large')]
    # [ValidateSet('None', 'AZ', 'Numeric', 'Integer', 'Decimal', 'Symbol', 'File', 'URL', 'Email', 'IPv4', 'IPv6')]

    [Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
    [Reflection.Assembly]::LoadWithPartialName('System.Data')          | Out-Null
    [Reflection.Assembly]::LoadWithPartialName('System.Drawing')       | Out-Null
    [System.Drawing.Font]$sysFont = [System.Drawing.SystemFonts]::MessageBoxFont
    [System.Windows.Forms.Application]::EnableVisualStyles()

#region Form Scripts
    $ChkButton_Click = {
        If ($ChkButton.Text -eq 'Check All') { $ChkButton.Text = 'Check None'; [boolean]$checked = $true } Else { $ChkButton.Text = 'Check All'; [boolean]$checked = $False }
        ForEach ($Control In $frm_Main.Controls) { If ($control -is [System.Windows.Forms.CheckBox]) { $control.Checked = $checked } }
    }

    $AddButton_Click = { AddButton_Click -BoxNumber (($frm_Main.Controls.Count - 5) / 2) -Value '' -Override $false -Type 'TEXT' }
    Function AddButton_Click ( [int]$BoxNumber, [string]$Value, [boolean]$Override, [string]$Type )
    {
        If ($Type -eq 'TEXT')
        {
            ForEach ($control In $frm_Main.Controls) {
                If ($control -is [System.Windows.Forms.TextBox]) {
                    [System.Windows.Forms.TextBox]$isEmtpy = $null
                    If ([string]::IsNullOrEmpty($control.Text) -eq $True) { $isEmtpy = $control; Break }
                }
            }

            If ($Override -eq $true) { $isEmtpy = $null } 
            If ($isEmtpy -ne $null)
            {
                $isEmtpy.Select()
                $isEmtpy.Text = $Value
                Return
            }
        }

        # Increase form size, move buttons down, add new field
        $numberOfTextBoxes++
        $frm_Main.ClientSize        = "394, $(147 + ($BoxNumber * 26))"
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
            $frm_Main.Controls.Add($labelCounter)

            # Add new text box and select it for focus
            $textBox                = New-Object 'System.Windows.Forms.TextBox'
            $textBox.Location       = " 39, $(75 + ($BoxNumber * 26))"
            $textBox.Size           = '343,   20'
            $textBox.Font           = $sysFont
            $textBox.Name           = "textBox$BoxNumber"
            $textBox.Text           = $Value.Trim()
            $frm_Main.Controls.Add($textBox)
            $frm_Main.Controls["textbox$BoxNumber"].Select()
        }
        ElseIf ($Type -eq 'CHECK')
        {
            # Add new check box
            $chkBox                = New-Object 'System.Windows.Forms.CheckBox'
            $chkBox.Location       = " 12, $(75 + ($BoxNumber * 26))"
            $chkBox.Size           = '370,   20'
            $chkBox.Font           = $sysFont
            $chkBox.Name           = "chkBox$BoxNumber"
            $chkBox.Text           = $Value
            $chkBox.TextAlign      = 'MiddleLeft'
            $frm_Main.Controls.Add($chkBox)
            $frm_Main.Controls["chkbox$BoxNumber"].Select()
        }
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
            $frm_Main.ClientSize      = "394, $(147 + 104)"
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
            $frm_Main.ClientSize      = '394, 147'
            $btn_Accept.Location      = '307, 110'
            $btn_Cancel.Location      = '220, 110'
        }
    }

    # Start form validation and make sure everything entered is correct
    $btn_Accept_Click = {
        [string[]]$currentValues  = @('')
        [boolean] $ValidatedInput = $true

        ForEach ($Control In $frm_Main.Controls)
        {
             If (($Control -is [System.Windows.Forms.TextBox]) -and ($Control.Visible -eq $true))
            {
                $Control.BackColor = 'Window'
                If (($Type -eq 'LIST') -and ($Control.Text.Contains(';') -eq $true))
                {
                    [string[]]$ControlText = ($Control.Text).Split(';')
                    $Control.Text = ''    # Remove current data so that it can be used as a landing control for the split data
                    ForEach ($item In $ControlText) { AddButton_Click -BoxNumber (($frm_Main.Controls.Count - 5) / 2) -Value $item -Override $false -Type 'TEXT' }
                }
            }
        }

        # Reset Control Loop for any new fields that may have been added
        ForEach ($Control In $frm_Main.Controls)
        {
            If (($Control -is [System.Windows.Forms.TextBox]) -and ($Control.Visible -eq $true))
            {
                $ValidatedInput = $(ValidateInputBox -Control $Control)
                $pic_InvalidValue.Image = $img_Input.Images[0]
                $pic_InvalidValue.Tag   = 'Validation failed for current value'
                $ToolTip.SetToolTip($pic_InvalidValue, $pic_InvalidValue.Tag)

                If ($ValidatedInput -eq $true)
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
                    $pic_InvalidValue.Visible  = $true
                    $Control.Focus()
                    $Control.SelectAll()
                    $ToolTip.Show($pic_InvalidValue.Tag, $pic_InvalidValue, 36, 12, 2500)
                    $Control.BackColor = 'Info'
                    Break
                }
            }
        }

        $currentValues = $null
        If ($ValidatedInput -eq $true) { $frm_Main.DialogResult = [System.Windows.Forms.DialogResult]::OK }
    }

    Function ValidateInputBox ([System.Windows.Forms.Control]$Control)
    {
        $Control.Text = ($Control.Text.Trim())
        [boolean]$ValidateResult = $false
        [string] $StringToCheck  = $($Control.Text)

        # Ignore for LARGE fields
        If ($Type -eq 'LARGE') { Return $true }

        # Ignore control if empty
        If ([string]::IsNullOrEmpty($StringToCheck) -eq $true) { Return $true }

        # Validate
        Switch ($Validation)
        {
            'AZ'      { $ValidateResult = ($StringToCheck -match "^[A-Za-z]+$");            Break }              # Letters only (A-Za-z)
            'Numeric' { $ValidateResult = ($StringToCheck -match '^(-)?([\d]+)?\.?[\d]+$'); Break }              # Both integer and decimal numbers
            'Integer' { $ValidateResult = ($StringToCheck -match '^(-)?[\d]+$');            Break }              # Integer numbers only
            'Decimal' { $ValidateResult = ($StringToCheck -match '^(-)?[\d]+\.[\d]+$');     Break }              # Decimal numbers only
            'Symbol'  { $ValidateResult = ($StringToCheck -match '^[^A-Za-z0-9]+$');        Break }              # Any symbol (not numbers or letters)
            'File'    {                                                                                # Valid file or folder name
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
                $ValidateResult = $true
            }
        }
        Return $ValidateResult
    }

    $frm_Main_Cleanup_FormClosed = {
        Try {
            $btn_Accept.Remove_Click($btn_Accept_Click)
            $AddButton.Remove_Click($AddButton_Click)
        } Catch {}
        $frm_Main.Remove_FormClosed($frm_Main_Cleanup_FormClosed)
    }
#endregion
#region Input Form Controls
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $frm_Main = New-Object 'System.Windows.Forms.Form'
    $frm_Main.FormBorderStyle      = 'FixedDialog'
    $frm_Main.MaximizeBox          = $False
    $frm_Main.MinimizeBox          = $False
    $frm_Main.ControlBox           = $False
    $frm_Main.Text                 = " $Title"
    $frm_Main.ShowInTaskbar        = $False
    $frm_Main.AutoScaleDimensions  = '6, 13'
    $frm_Main.AutoScaleMode        = 'Font'
    $frm_Main.ClientSize           = '394, 147'    # 400 x 175
    $frm_Main.StartPosition        = 'CenterParent'

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
    $frm_Main.Controls.Add($pic_InvalidValue)

    $lbl_Description               = New-Object 'System.Windows.Forms.Label'
    $lbl_Description.Location      = ' 12,  12'
    $lbl_Description.Size          = '370,  48'
    $lbl_Description.Font          = $sysFont
    $lbl_Description.Text          = $($Description.Trim())
    $frm_Main.Controls.Add($lbl_Description)

    If ($Validation -ne 'None')
    {
        $lbl_Validation            = New-Object 'System.Windows.Forms.Label'
        $lbl_Validation.Location   = '212,  60'
        $lbl_Validation.Size       = '170,  15'
        $lbl_Validation.Font       = $sysFont
        $lbl_Validation.Text       = "Validation: $($Validation.ToUpper())"
        $lbl_Validation.TextAlign  = 'BottomRight'
        $frm_Main.Controls.Add($lbl_Validation)
    }

    $btn_Accept                    = New-Object 'System.Windows.Forms.Button'
    $btn_Accept.Location           = '307, 110'
    $btn_Accept.Size               = ' 75,  25'
    $btn_Accept.Font               = $sysFont
    $btn_Accept.Text               = 'OK'
    $btn_Accept.TabIndex           = '97'
    $btn_Accept.Add_Click($btn_Accept_Click)
    If ($Type -ne 'LARGE') { $frm_Main.AcceptButton = $btn_Accept }
    $frm_Main.Controls.Add($btn_Accept)

    $btn_Cancel                    = New-Object 'System.Windows.Forms.Button'
    $btn_Cancel.Location           = '220, 110'
    $btn_Cancel.Size               = ' 75,  25'
    $btn_Cancel.Font               = $sysFont
    $btn_Cancel.Text               = 'Cancel'
    $btn_Cancel.TabIndex           = '98'
    $btn_Cancel.DialogResult       = [System.Windows.Forms.DialogResult]::Cancel
    $frm_Main.CancelButton         = $btn_Cancel
    $frm_Main.Controls.Add($btn_Cancel)
    $frm_Main.Add_FormClosed($frm_Main_Cleanup_FormClosed)
#endregion
#region Input Form Controls Part 2
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
            $frm_Main.Controls.Add($AddButton)

            # Add initial textboxes
            For ($i = 0; $i -le $numberOfTextBoxes; $i++) { AddButton_Click -BoxNumber $i -Value ($CurrentValue[$i]) -Override $true -Type 'TEXT' }
            $frm_Main.Controls['textbox0'].Select()
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
            $frm_Main.Controls.Add($ChkButton)

            # Add initial textboxes
            [int]$i = 0
            ForEach ($item In $InputList)
            {
                AddButton_Click -BoxNumber $i -Value ($item.Trim()) -Override $true -Type 'CHECK'
                If ([string]::IsNullOrEmpty($CurrentValue) -eq $false) { If ($CurrentValue.Contains($item.Trim())) { $frm_Main.Controls["chkBox$i"].Checked = $true } }
                $i++
            }
            Break
        }

        'OPTION' {
            # Drop down selection list
            $comboBox               = New-Object 'System.Windows.Forms.ComboBox'
            $comboBox.Location      = ' 12,  75'
            $comboBox.Size          = '370,  21'
            $comboBox.Font          = $sysFont
            $comboBox.DropDownStyle = 'DropDownList'
            $frm_Main.Controls.Add($comboBox)
            $comboBox.Items.AddRange(($InputList.Trim())) | Out-Null
            $frm_Main.Add_Shown({$comboBox.Select()})
            If ([string]::IsNullOrEmpty($CurrentValue) -eq $false) { $comboBox.SelectedItem = $CurrentValue[0] } Else { $comboBox.SelectedIndex = -1 }
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
            $frm_Main.Controls.Add($textBox)
            $frm_Main.Add_Shown({$textBox.Select()})
            $textBox.Select()

            # Resize form
            $frm_Main.Height       += 104                    # 
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
            $frm_Main.Controls.Add($textBox)
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
    ForEach ($control In $frm_Main.Controls) { $control.Font = $sysFont; Try { $control.FlatStyle = 'Standard' } Catch {} }
    $result = $frm_Main.ShowDialog($MainForm)

    If ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        Switch ($Type)
        {
            'LIST'   {
                [string[]]$return = @()
                ForEach ($control In $frm_Main.Controls) { If ($control -is [System.Windows.Forms.TextBox]) {
                    If ([string]::IsNullOrEmpty($control.Text) -eq $false) { $return += ($($control.Text.Trim())) } }
                } Return $return
            }
            'CHECK'  {
                [string[]]$return = @()
                ForEach ($Control In $frm_Main.Controls) { If ($control -is [System.Windows.Forms.CheckBox]) {
                    If ($control.Checked -eq $true) { $return += ($($control.Text.Trim())) } }
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
            'OPTION' { Return $($comboBox.SelectedItem) }
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
        [parameter(Mandatory=$false)][string]$ccTasks,
        [parameter(Mandatory=$false)][string]$ResultsPath
    )

    [Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
    [Reflection.Assembly]::LoadWithPartialName('System.Data')          | Out-Null
    [Reflection.Assembly]::LoadWithPartialName('System.Drawing')       | Out-Null
    [System.Drawing.Font]$sysFont = [System.Drawing.SystemFonts]::MessageBoxFont
    [System.Windows.Forms.Application]::EnableVisualStyles()

# ##########
# ##########
# ##########

#    $ComboxCustomDraw = {
#        [System.Windows.Forms.DrawItemEventArgs]$e   = $_
#        [System.Windows.Forms.ComboBox]         $cbx = $sender
#
#        If ($e.Index -ge 0)
#        {
#            $sf = New-Object 'System.Drawing.StringFormat'
#            $sf.Alignment     = [System.Drawing.StringAlignment]::Center
#            $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
#
#            $br = New-Object System.Drawing.SolidBrush($cbx.ForeColor)
#            If ($e.State -eq 'Selected') { $br = [System.Drawing.SystemBrushes]::HighlightText }
#
#            $e.Graphics.DrawString($cbx.Items[$e.Index].ToString(), $cbx.Font, $br, $e.Bounds, $sf)
#        }
#    }

# ##########
# ##########
# ##########

#region MAIN FORM
    $frm_Main = New-Object 'System.Windows.Forms.Form'
    $frm_Main.FormBorderStyle      = 'FixedDialog'
    $frm_Main.MaximizeBox          = $False
    $frm_Main.MinimizeBox          = $False
    $frm_Main.ControlBox           = $False
    $frm_Main.Text                 = ' Additional Settings'
    $frm_Main.ShowInTaskbar        = $False
    $frm_Main.AutoScaleDimensions  = '6, 13'
    $frm_Main.AutoScaleMode        = 'Font'
    $frm_Main.ClientSize           = '444, 222'    # 450 x 300
    $frm_Main.StartPosition        = 'CenterParent'

    $lbl_Description               = New-Object 'System.Windows.Forms.Label'
    $lbl_Description.Location      = ' 12,  12'
    $lbl_Description.Size          = '420,  33'
    $lbl_Description.Text          = 'This form allows you to set any additional settings that help control the QA scripts and its output.  Do not change these settings if you are unsure.'
    $frm_Main.Controls.Add($lbl_Description)

    $btn_Reset                     = New-Object 'System.Windows.Forms.Button'
    $btn_Reset.Location           = ' 12, 185'
    $btn_Reset.Size               = ' 75,  25'
    $btn_Reset.Font               = $sysFont
    $btn_Reset.Text               = 'Reset'
    $btn_Reset.TabIndex           = '96'
    $btn_Reset.Add_Click({ $cmo_TimeOut.SelectedItem = '60'; $cmo_CCTasks.SelectedItem = '5'; $txt_Location.Text = '$env:SystemDrive\QA\Results\' })
    $frm_Main.Controls.Add($btn_Reset)

    $btn_Accept                    = New-Object 'System.Windows.Forms.Button'
    $btn_Accept.Location           = '357, 185'
    $btn_Accept.Size               = ' 75,  25'
    $btn_Accept.Font               = $sysFont
    $btn_Accept.Text               = 'Save'
    $btn_Accept.TabIndex           = '97'
    $btn_Accept.DialogResult       = [System.Windows.Forms.DialogResult]::OK
    $frm_Main.AcceptButton         = $btn_Accept
    $frm_Main.Controls.Add($btn_Accept)

    $btn_Cancel                    = New-Object 'System.Windows.Forms.Button'
    $btn_Cancel.Location           = '267, 185'
    $btn_Cancel.Size               = ' 75,  25'
    $btn_Cancel.Font               = $sysFont
    $btn_Cancel.Text               = 'Cancel'
    $btn_Cancel.TabIndex           = '98'
    $btn_Cancel.DialogResult       = [System.Windows.Forms.DialogResult]::Cancel
    $frm_Main.CancelButton         = $btn_Cancel
    $frm_Main.Controls.Add($btn_Cancel)
#endregion
#region OPTIONS
    # Option 1
    $lbl_CheckTimeOut1             = New-Object 'System.Windows.Forms.Label'
    $lbl_CheckTimeOut1.Location    = ' 12,  66'
    $lbl_CheckTimeOut1.Size        = '150,  21'
    $lbl_CheckTimeOut1.Text        = 'Check Timeout :'
    $lbl_CheckTimeOut1.TextAlign   = 'MiddleRight'
    $frm_Main.Controls.Add($lbl_CheckTimeOut1)

    $cmo_TimeOut                   = New-Object 'System.Windows.Forms.ComboBox'
    $cmo_TimeOut.Location          = '168,  66'
    $cmo_TimeOut.Size              = ' 50,  21'
    $cmo_TimeOut.DropDownStyle     = 'DropDownList'
#    $cmo_TimeOut.DrawMode          = 'OwnerDrawFixed'
#    $cmo_TimeOut.Add_DrawItem($ComboxCustomDraw)
    $frm_Main.Controls.Add($cmo_TimeOut)
    [string[]]$TimeOutList         = @('30','45','60','75','90','120')
    $cmo_TimeOut.Items.AddRange($TimeOutList) | Out-Null
    $cmo_TimeOut.SelectedItem      = '60'
    If ($Timeout -ne '') { $cmo_TimeOut.SelectedItem = $Timeout }

    $lbl_CheckTimeOut2             = New-Object 'System.Windows.Forms.Label'
    $lbl_CheckTimeOut2.Location    = '224,  66'
    $lbl_CheckTimeOut2.Size        = '208,  21'
    $lbl_CheckTimeOut2.Text        = 'Seconds'
    $lbl_CheckTimeOut2.TextAlign   = 'MiddleLeft'
    $frm_Main.Controls.Add($lbl_CheckTimeOut2)

    # Option 2
    $lbl_CCTasks1                  = New-Object 'System.Windows.Forms.Label'
    $lbl_CCTasks1.Location         = ' 12, 102'
    $lbl_CCTasks1.Size             = '150,  21'
    $lbl_CCTasks1.Text             = 'Concurrent Tasks :'
    $lbl_CCTasks1.TextAlign        = 'MiddleRight'
    $frm_Main.Controls.Add($lbl_CCTasks1)

    $cmo_CCTasks                   = New-Object 'System.Windows.Forms.ComboBox'
    $cmo_CCTasks.Location          = '168, 102'
    $cmo_CCTasks.Size              = ' 50,  21'
    $cmo_CCTasks.DropDownStyle     = 'DropDownList'
#    $cmo_CCTasks.DrawMode          = 'OwnerDrawFixed'
#    $cmo_CCTasks.Add_DrawItem($ComboxCustomDraw)
    $frm_Main.Controls.Add($cmo_CCTasks)
    [string[]]$TasksList           = @('2', '3', '4', '5', '7', '10', '15')
    $cmo_CCTasks.Items.AddRange($TasksList) | Out-Null
    $cmo_CCTasks.SelectedItem      = '5'
    If ($ccTasks -ne '') { $cmo_CCTasks.SelectedItem = $ccTasks }

    $lbl_CCTasks2                  = New-Object 'System.Windows.Forms.Label'
    $lbl_CCTasks2.Location         = '225, 102'
    $lbl_CCTasks2.Size             = '208,  21'
    $lbl_CCTasks2.Text             = 'Higher values = more resources'
    $lbl_CCTasks2.TextAlign        = 'MiddleLeft'
    $frm_Main.Controls.Add($lbl_CCTasks2)

    # Option 3
    $lbl_Location                  = New-Object 'System.Windows.Forms.Label'
    $lbl_Location.Location         = ' 12, 138'
    $lbl_Location.Size             = '150,  20'
    $lbl_Location.Text             = 'Report Location :'
    $lbl_Location.TextAlign        = 'MiddleRight'
    $frm_Main.Controls.Add($lbl_Location)

    $txt_Location                  = New-Object 'System.Windows.Forms.Textbox'
    $txt_Location.Location         = '168, 138'
    $txt_Location.Size             = '264,  20'
    $txt_Location.TextAlign        = 'Left'
    If ($ResultsPath -ne '') { $txt_Location.Text = $ResultsPath } Else { $txt_Location.Text = '$env:SystemDrive\QA\Results\' }
    $frm_Main.Controls.Add($txt_Location)
    
#endregion
#region FORM STARTUP / SHUTDOWN
    $InitialFormWindowState        = New-Object 'System.Windows.Forms.FormWindowState'
    $frm_Main_StateCorrection_Load = { $frm_Main.WindowState = $InitialFormWindowState }

    ForEach ($control In $frm_Main.Controls) { $control.Font = $sysFont; Try { $control.FlatStyle = 'Standard' } Catch {} }
    $result = $frm_Main.ShowDialog()

    If ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        [psobject]$return = New-Object -TypeName PSObject -Property @{
            'Timeout'     = $cmo_TimeOut.Text.Trim();
            'ccTasks'     = $cmo_CCTasks.Text.Trim();
            'ResultsPath' = $txt_Location.Text.Trim();
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
        ForEach ($control In $MainForm.Controls) { $control.Font = $sysFont }
        ForEach ($tab In $tab_Pages.TabPages) { ForEach ($control In $tab.Controls) { $control.Font = $sysFont } }

        # Set some fonts
        $lbl_t1_Welcome.Font         = $sysFontBold
        $lbl_t2_CheckSelection.Font  = $sysFontBold
        $lbl_t3_ScriptSelection.Font = $sysFontBold
        $lbl_t4_Complete.Font        = $sysFontBold

        # Setup default messages
        $lbl_t3_NoParameters.Visible    = $true
        $lst_t2_SelectChecks.CheckBoxes = $False
        $lst_t2_SelectChecks.Groups.Add('ErrorGroup','Please Note')
        Add-ListViewItem -ListView $lst_t2_SelectChecks -Items '' -SubItems ''                                   -Group 'ErrorGroup'
        Add-ListViewItem -ListView $lst_t2_SelectChecks -Items '' -SubItems 'Select your scripts location first' -Group 'ErrorGroup' 
    }

    $MainFORM_FormClosing = [System.Windows.Forms.FormClosingEventHandler] {
        $quit = [System.Windows.Forms.MessageBox]::Show($MainFORM, 'Are you sure you want to exit this form.?', ' Quit', 'YesNo', 'Question')
        If ($quit -eq 'No') { $_.Cancel = $True }
    }

    $Form_Cleanup_FormClosed   = {
        $tab_Pages.Remove_SelectedIndexChanged($tab_Pages_SelectedIndexChanged)
        $btn_t4_Save.Add_Click($btn_t4_Save_Click)
        $btn_t1_Search.Remove_Click($btn_t1_Search_Click)
        $btn_t1_Import.Remove_Click($btn_t1_Import_Click)
        $btn_t4_Generate.Remove_Click($btn_t4_Generate_Click)
        $btn_t2_NextPage.Remove_Click($btn_t2_NextPage_Click)
        $btn_t2_SelectAll.Remove_Click($btn_t2_SelectAll_Click)
        $btn_t2_SelectInv.Remove_Click($btn_t2_SelectInv_Click)
        $btn_t2_SelectNone.Remove_Click($btn_t2_SelectNone_Click)
        $lst_t2_SelectChecks.Remove_ItemChecked($lst_t2_SelectChecks_ItemChecked)
        $lst_t2_SelectChecks.Remove_SelectedIndexChanged($lst_t2_SelectChecks_SelectedIndexChanged)

        $tab_Pages
        Try {
            $sysFont.Dispose()
            $sysFontBold.Dispose()
        } Catch {}

        $MainFORM.Remove_FormClosing($MainFORM_FormClosing)
        $MainFORM.Remove_Load($MainFORM_Load)
        $MainFORM.Remove_Load($MainFORM_StateCorrection_Load)
    }
#endregion
###################################################################################################
#region FORM Scripts
    Function Update-SelectedCount { $lbl_t2_SelectedCount.Text = "$($lst_t2_SelectChecks.CheckedItems.Count) of $($lst_t2_SelectChecks.Items.Count) checks selected" }
    Function ListView_SelectedIndexChanged ( [System.Windows.Forms.ListView]$SourceControl )
    {
        If ( $SourceControl.SelectedItems                -eq $null) { Return }
        If ( $SourceControl.SelectedItems.Count          -eq  0   ) { Return }
        If (($SourceControl.SelectedItems[0].ImageIndex) -eq -1   ) { Return }
    }
    Function ListView_DoubleClick ( [System.Windows.Forms.ListView]$SourceControl )
    {
        If ([string]::IsNullOrEmpty(($SourceControl.SelectedItems[0].Text).Trim()) -eq $True) { Return }
        If (($SourceControl.SelectedItems[0].ImageIndex) -eq -1) { Return }
        $MainFORM.Cursor = 'WaitCursor'

        # Start EDIT for selected item
        Try { [System.Windows.Forms.ListViewItem]$selectedItem = $($SourceControl.SelectedItems[0]) } Catch { }
        Switch -Wildcard ($($selectedItem.SubItems[2].Text))
        {
            'COMBO*' {
                [string[]]$currentVal  =   $($selectedItem.SubItems[1].Text.Trim("'"))
                [string[]]$selections  = (($($selectedItem.SubItems[2].Text).Split('-')[1]).Split('|'))
                [string[]]$returnValue = (Show-InputForm -Type 'Option' -Title $($selectedItem.Group.Header) -Description "$($selectedItem.SubItems[0].Text)`n$($selectedItem.SubItems[3].Text)" -CurrentValue $currentVal -InputList $selections)
                If ($returnValue -ne '!!-CANCELLED-!!') { $SourceControl.SelectedItems[0].SubItems[1].Text = "'$returnValue'" }
                Break
            }

            'CHECK*' {
                [string[]]$currentVal  =   $($selectedItem.SubItems[1].Text).Split(';')
                          $currentVal  = ($currentVal.Trim().Replace("'",'').Replace('(','').Replace(')',''))
                [string[]]$selections  = (($($selectedItem.SubItems[2].Text).Split('-')[1]).Split(','))
                [string[]]$returnValue = (Show-InputForm -Type 'Check'  -Title $($selectedItem.Group.Header) -Description "$($selectedItem.SubItems[0].Text)`n$($selectedItem.SubItems[3].Text)" -CurrentValue $currentVal -InputList $selections)
                If ($returnValue -ne '!!-CANCELLED-!!') { $SourceControl.SelectedItems[0].SubItems[1].Text = ("('{0}')" -f $($returnValue -join ';').Replace(';', "'; '")) }
                Break
            }

            'LIST' {
                [string[]]$currentVal  = $($selectedItem.SubItems[1].Text).Split(';')
                          $currentVal  = ($currentVal.Trim().Replace("'",'').Replace('(','').Replace(')',''))
                [string[]]$returnValue = (Show-InputForm -Type 'List'   -Title $($selectedItem.Group.Header) -Description "$($selectedItem.SubItems[0].Text)`n$($selectedItem.SubItems[3].Text)" -CurrentValue $currentVal -Validation $($selectedItem.SubItems[4].Text))
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
                Write-Host "Invalid Type: $($selectedItem.SubItems[3].Text)"
            }
        }
        $MainFORM.Cursor = 'Default'
    }

    $tab_Pages_SelectedIndexChanged = {
        If ($tab_Pages.SelectedIndex -eq 1) { $lbl_ChangesMade.Visible = $True                } Else { $lbl_ChangesMade.Visible = $False }
        If ($tab_Pages.SelectedIndex -eq 3) { $btn_Settings.Visible    = $btn_t4_Save.Enabled } Else { $btn_Settings.Visible    = $False }
    }

    $btn_t1_Search_Click = {
        # Search location and read in scripts
        $btn_t1_Search.Enabled       = $False
        $btn_t1_Import.Enabled       = $False
        $lbl_t1_Language.Enabled     = $False
        $cmo_t1_Language.Enabled     = $False
        $lbl_t1_SettingsFile.Enabled = $False
        $cmo_t1_SettingsFile.Enabled = $False

        $MainFORM.Cursor = 'WaitCursor'
        [string]$InitialDirectory = "$script:ExecutionFolder"
        $script:scriptLocation = (Get-Folder -Description 'Select the QA checks root folder:' -InitialDirectory $InitialDirectory -ShowNewFolderButton $False)
        If ([string]::IsNullOrEmpty($script:scriptLocation) -eq $True) { $btn_t1_Search.Enabled = $True; $MainFORM.Cursor = 'Default'; Return }
        If ($script:scriptLocation.EndsWith('\scripts')) { $script:scriptLocation = $script:scriptLocation.TrimEnd('\scripts') }

        $btn_t1_Search.Enabled = $True
        [boolean]$iniLoadOK    = $False
        Try
        {
            [string[]]$langList    = (Get-ChildItem -Path "$script:scriptLocation\i18n"     -Filter '*_text.ini' -ErrorAction Stop | Select-Object -ExpandProperty Name | Sort-Object Name | ForEach { $_.Replace('_text.ini','') } )
            [string[]]$settingList = (Get-ChildItem -Path "$script:scriptLocation\settings" -Filter '*.ini'      -ErrorAction Stop | Select-Object -ExpandProperty Name | Sort-Object Name | ForEach { $_.Replace(     '.ini','') } )
            Load-ComboBox -ComboBox $cmo_t1_Language     -Items ($langList    | Sort-Object Name) -SelectedItem 'en-gb'            -Clear
            Load-ComboBox -ComboBox $cmo_t1_SettingsFile -Items ($settingList | Sort-Object Name) -SelectedItem 'default-settings' -Clear
            $iniLoadOK = $True
        }
        Catch
        {
            Load-ComboBox -ComboBox $cmo_t1_Language     -Items ('Unknown') -SelectedItem 'Unknown' -Clear
            Load-ComboBox -ComboBox $cmo_t1_SettingsFile -Items ('Unknown') -SelectedItem 'Unknown' -Clear
            $iniLoadOK = $False
        }

        $btn_t1_Import.Enabled       = $iniLoadOK
        $lbl_t1_Language.Enabled     = $iniLoadOK
        $cmo_t1_Language.Enabled     = $iniLoadOK
        $lbl_t1_SettingsFile.Enabled = $iniLoadOK
        $cmo_t1_SettingsFile.Enabled = $iniLoadOK
        $btn_t1_Import.Focus()

        $MainFORM.Cursor = 'Default'
    }

    $btn_t1_Import_Click = {
        $MainFORM.Cursor = 'WaitCursor'
        [System.Globalization.TextInfo]$TextInfo = (Get-Culture).TextInfo    # Used for 'ToTitleCase' below

        # Load Language, Settings and Help details
        [hashtable]$settingsINI = (Load-IniFile -Inputfile "$script:scriptLocation\settings\$($cmo_t1_SettingsFile.Text).ini")
        [hashtable]$languageINI = (Load-IniFile -Inputfile "$script:scriptLocation\i18n\$($cmo_t1_Language.Text)_text.ini")
        [string[]] $loadhelpINI = (Get-Content  -Path      "$script:scriptLocation\i18n\$($cmo_t1_Language.Text)_help.ps1" -ErrorAction SilentlyContinue)
        ForEach ($help In $loadhelpINI) { If ([string]::IsNullOrEmpty($help) -eq $False) { Invoke-Expression -Command $help } }

        $lbl_t1_ScanningScripts.Visible = $True
        $lbl_t1_ScanningScripts.Text    = 'Scanning Check Location: '
        $txt_t4_ShortCode.Text          = ($settingsINI.settings.shortcode)
        $txt_t4_ReportTitle.Text        = ($settingsINI.settings.reportCompanyName)
        $btn_t4_Save.Enabled            = $False
        $btn_t4_Generate.Enabled        = $false
        $tab_t3_Pages.TabPages.Clear()
        $lst_t2_SelectChecks.Items.Clear()
        $lst_t2_SelectChecks.Groups.Clear()
        $lst_t2_SelectChecks.CheckBoxes = $True

        [object[]]$folders = (Get-ChildItem -Path "$script:scriptLocation\checks" | Where-Object { $_.PsIsContainer -eq $True } | Select-Object -ExpandProperty Name | Sort-Object Name )
        ForEach ($folder In ($folders | Sort-Object Name))
        {
            $folder = $($TextInfo.ToTitleCase($folder))
            $lbl_t1_ScanningScripts.Text = "Scanning script folder: $($folder.ToUpper())"
            $lbl_t1_ScanningScripts.Refresh(); [System.Windows.Forms.Application]::DoEvents()

            # Add TabPage for folder and create a ListView item
            $newTab = New-Object 'System.Windows.Forms.TabPage'
            $newTab.Font = $sysFont
            $newTab.Text = $folder
            $newTab.Name = "tab_$folder"
            $newTab.Tag  = "tab_$folder"
            $tab_t3_Pages.TabPages.Add($newTab)

            # lst_t3_EnterDetails
            $newLVW = New-Object 'System.Windows.Forms.ListView'
            $newLVW.Font           = $sysFont
            $newLVW.Name           = "lvw_$folder"
            $newLVW.HeaderStyle    = 'Nonclickable'
            $newLVW.FullRowSelect  = $True
            $newLVW.GridLines      = $False
            $newLVW.LabelWrap      = $False
            $newLVW.MultiSelect    = $False
            $newLVW.Location       = '  3,  3'
            $newLVW.Size           = '730, 498'
            $newLVW.View           = 'Details'
            $newLVW.SmallImageList = $img_ListImages
            $newLVW_CH_Name  = New-Object 'System.Windows.Forms.ColumnHeader'; $newLVW_CH_Name.Text  = 'Check'; $newLVW_CH_Name.Width  = 225
            $newLVW_CH_Value = New-Object 'System.Windows.Forms.ColumnHeader'; $newLVW_CH_Value.Text = 'Value'; $newLVW_CH_Value.Width = 505 - ([System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth + 4)
            $newLVW_CH_Type  = New-Object 'System.Windows.Forms.ColumnHeader'; $newLVW_CH_Type.Text  = ''     ; $newLVW_CH_Type.Width  =   0    # 
            $newLVW_CH_Desc  = New-Object 'System.Windows.Forms.ColumnHeader'; $newLVW_CH_Desc.Text  = ''     ; $newLVW_CH_Desc.Width  =   0    # Description from check file
            $newLVW_CH_Vali  = New-Object 'System.Windows.Forms.ColumnHeader'; $newLVW_CH_Vali.Text  = ''     ; $newLVW_CH_Vali.Width  =   0    # Validation type
            $newLVW.Columns.Add($newLVW_CH_Name)  | Out-Null                                                                           # ---
            $newLVW.Columns.Add($newLVW_CH_Value) | Out-Null                                                                           # 730  = Control Width
            $newLVW.Columns.Add($newLVW_CH_Type)  | Out-Null
            $newLVW.Columns.Add($newLVW_CH_Desc)  | Out-Null
            $newLVW.Columns.Add($newLVW_CH_Vali)  | Out-Null

            $newLVW.Add_KeyPress( { If ($_.KeyChar -eq 13) { ListView_DoubleClick          -SourceControl $this } } )
            $newLVW.Add_DoubleClick(                       { ListView_DoubleClick          -SourceControl $this }   )
            $newLVW.Add_SelectedIndexChanged(              { ListView_SelectedIndexChanged -SourceControl $this }   )
            $newTab.Controls.Add($newLVW)

            [string]$guid = ([guid]::NewGuid() -as [string]).Split('-')[0]
            $lst_t2_SelectChecks.Groups.Add("$guid", " $folder")

            [object[]]$scripts = (Get-ChildItem -Path "$script:scriptLocation\checks\$folder" -Filter 'c-*.ps1' | Select-Object -ExpandProperty Name | Sort-Object Name )
            ForEach ($script In ($scripts | Sort-Object Name))
            {
                [string]$script    =  $script.Replace($script.Split('.')[-1], '').TrimEnd('.')
                [string]$checkCode = ($script.Substring(2, 6).Replace('-',''))
                [string]$checkName = ($languageINI.$($checkCode).Name)
                If ([string]::IsNullOrEmpty($checkName) -eq $True) { $checkName = '*' + $TextInfo.ToTitleCase($(($script.Substring(9)).Replace('-', ' '))) } Else { $checkName = $checkName.Trim("'") }

                # Load description
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

                # Default back to the scripts description of help if required
                If ($checkDesc -eq '')
                {
                    [string]$content   = ((Get-Content -Path ("$script:scriptLocation\checks\$folder\$script.ps1") -TotalCount 50) -join "`n")
                    $regExA = [RegEx]::Match($content,     "APPLIES:((?:.|\s)+?)(?:(?:[A-Z\- ]+:)|(?:#>))")
                    $regExD = [RegEx]::Match($content, "DESCRIPTION:((?:.|\s)+?)(?:(?:[A-Z\- ]+:)|(?:#>))")

                    [string]$checkDesc = "Applies To: $($regExA.Groups[1].Value.Trim())!n"
                    ($regExD.Groups[1].Value.Trim().Split("`n")) | ForEach { $checkDesc += $_.Trim() + '  ' }
                }

                Add-ListViewItem -ListView $lst_t2_SelectChecks -Items $checkCode -SubItems ($checkName, $checkDesc.Replace('!n', "`n`n")) -Group $guid -ImageIndex 1 -Enabled $True
                If ($settingsINI.ContainsKey($checkCode) -eq $true) { $lst_t2_SelectChecks.Items["$checkCode"].Checked = $True }
            }
        }
        Update-SelectedCount

        $tab_Pages.SelectedIndex        = 1
        $lbl_t1_ScanningScripts.Visible = $False
        $btn_t1_Search.Enabled          = $True
        $btn_t1_Import.Enabled          = $True
        $btn_t2_NextPage.Enabled        = $True
        $btn_t2_SelectAll.Enabled       = $True
        $btn_t2_SelectInv.Enabled       = $True
        $btn_t2_SelectNone.Enabled      = $True
        $lst_t2_SelectChecks.Items[0].Selected = $True
        $MainFORM.Cursor                = 'Default'
    }

    $btn_t2_SelectAll_Click  = { ForEach ($item In $lst_t2_SelectChecks.Items) { $item.Checked =       $true          }; Update-SelectedCount }
    $btn_t2_SelectInv_Click  = { ForEach ($item In $lst_t2_SelectChecks.Items) { $item.Checked = (-not $item.Checked) }; Update-SelectedCount }
    $btn_t2_SelectNone_Click = { ForEach ($item In $lst_t2_SelectChecks.Items) { $item.Checked =       $false         }; Update-SelectedCount }

    $lst_t2_SelectChecks_ItemChecked          = { If ($_.Item.Checked -eq $True) { $_.Item.BackColor = 'Window' } Else { $_.Item.BackColor = 'Control' }; Update-SelectedCount }
    $lst_t2_SelectChecks_SelectedIndexChanged = { If ($lst_t2_SelectChecks.SelectedItems.Count -eq 1) { $lbl_t2_Description.Text = ($lst_t2_SelectChecks.SelectedItems[0].SubItems[2].Text) } }

    $btn_t2_NextPage_Click = {
        If ($lst_t2_SelectChecks.Items.Count -eq 0) { Return }
        ForEach ($folder In $lst_t2_SelectChecks.Groups)
        {
            [System.Windows.Forms.TabPage] $tabObject = $tab_t3_Pages.TabPages["tab_$($folder.Header.Trim())"]
            [System.Windows.Forms.ListView]$lvwObject =    $tabObject.Controls["lvw_$($folder.Header.Trim())"]
            If ($lvwObject.Items.Count -gt 0)
            {
                $msgbox = ([System.Windows.Forms.MessageBox]::Show($MainFORM, "Any unsaved changes will be lost`nAre you sure you want to continue.?`n`nTo save your current changes: Click 'No',`nChange to the 'Generate QA' tab, click 'Save Settings'", 'Warning', 'YesNo', 'Warning', 'Button2'))
                If ($msgbox -eq 'No') { Return }
                Break
            }
        }

        $MainFORM.Cursor         = 'WaitCursor'
        [System.Collections.Hashtable]$settingsINI   = (Load-IniFile -Inputfile "$script:scriptLocation\settings\$($cmo_t1_SettingsFile.Text).ini")
        [string]                      $SkippedChecks = ($SettingsINI.Keys | Where-Object { $_.EndsWith('-skip') })

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
                # Create group for the checks
                [string]$guid = $($listItem.Text)
                $lvwObject.Groups.Add($guid, " $($listItem.SubItems[1].Text) ($($listItem.Text.ToUpper()))")

                # Create each item
                [System.Collections.Hashtable]$iniKeys = $null

                If ($SkippedChecks.Contains($("$($listItem.Text)-skip"))) { $iniKeys = ($settingsINI.$("$($listItem.Text)-skip")) } Else { $iniKeys = ($settingsINI.$($listItem.Text)) }
                ForEach ($item In (($iniKeys.Keys) | Sort-Object))
                {
                    [string]$value = ($iniKeys.$item)
                    $value = $value.Replace("', '", "'; '").Replace("','", "'; '")
                    [string]$desc = ''

                    If ([string]::IsNullOrEmpty($script:qahelp[$($listItem.Text)]) -eq $False) {
                        Try {
                            [xml]$xmlDesc = New-Object 'System.Xml.XmlDataDocument'
                            $xmlDesc.LoadXml($script:qahelp[$($listItem.Text)])
                            If ($xmlDesc.xml.RequiredInputs) { [string[]]$DescList = $($xmlDesc.xml.RequiredInputs).Replace('!n','#').Split('#') }
                            ForEach ($DL In $DescList) { If (($DL.Trim()).StartsWith($item.Trim())) { $desc = ($DL.Trim()) } }
                        } Catch { }
                    }

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

                    Add-ListViewItem -ListView $lvwObject -Items $item -SubItems ($value, $type, $desc, $vali) -Group $guid -ImageIndex 1 -Enabled $($listItem.Checked)
                }

                # Add 'spacing' gap between groups
                If ($lvwObject.Groups[$guid].Items.Count -gt 0) { Add-ListViewItem -ListView $lvwObject -Items ' ' -SubItems ('','','','') -Group $guid -ImageIndex -1 -Enabled $false }
            }
        }

        $tab_Pages.SelectedIndex     = 2
        $btn_t4_Save.Enabled         = $True
        $lbl_t3_NoParameters.Visible = $False
        $MainFORM.Cursor             = 'Default'
    }

    $btn_t4_Save_Click = {
        If (([string]::IsNullOrEmpty($txt_t4_ShortCode.Text) -eq $true) -or ([string]::IsNullOrEmpty($txt_t4_ReportTitle.Text) -eq $true))
        {
            [System.Windows.Forms.MessageBox]::Show($MainFORM, 'Please fill in a "ShortCode" and "ReportTitle" value.', 'Missing Data', 'OK', 'Warning')
            Return
        }

        $MainFORM.Cursor = 'WaitCursor'
        $script:saveFile = (Save-File -InitialDirectory "$script:ExecutionFolder\settings" -Title 'Save Settings File')
        If ([string]::IsNullOrEmpty($script:saveFile) -eq $True) { Return }

        If ($script:saveFile.EndsWith('default-settings.ini'))
        {
            $MainFORM.Cursor = 'Default'
            [System.Windows.Forms.MessageBox]::Show($MainFORM, "You should not save over the default-settings file.`n" +
                                                               "It will be overwritten when the source code is updated`n`n" +
                                                               "Please select a different file name", 'default-settings.ini', 'OK', 'Error')
            Return
        }

        [System.Text.StringBuilder]$outputFile = ''
        # Write out header information
        $outputFile.AppendLine('[settings]')
        $outputFile.AppendLine("shortcode         = $($txt_t4_ShortCode.Text)")
        $outputFile.AppendLine("reportCompanyName = $($txt_t4_ReportTitle.Text)")
        $outputFile.AppendLine('')
        $outputFile.AppendLine("language          = $($cmo_t1_Language.Text)")
        $outputFile.AppendLine("outputLocation    = $($script:settings.ResultsPath)")
        $outputFile.AppendLine("timeout           = $($script:settings.TimeOut)")
        $outputFile.AppendLine("concurrent        = $($script:settings.ccTasks)")
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
                                'COMBO*' { [string]$out =  "$($item.SubItems[1].Text)" }
                                'CHECK*' { [string]$out = "$(($item.SubItems[1].Text).Replace(';', ','))" }
                                'LARGE'  { [string]$out =  "$($item.SubItems[1].Text)" }
                                'LIST'   { [string]$out = "$(($item.SubItems[1].Text).Replace(';', ','))" }
                                'SIMPLE' { [string]$out =  "$($item.SubItems[1].Text)" }
                                Default  { }
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
        [System.Windows.Forms.MessageBox]::Show($MainFORM, "Settings file '$(Split-Path -Path $script:saveFile -Leaf)' saved successfully.", 'Save Settings', 'OK', 'Information') 
        $btn_t4_Generate.Enabled = $True
        $MainFORM.Cursor = 'Default'
    }

    $btn_t4_Generate_Click = {
        $MainFORM.Cursor = 'WaitCursor'
        $btn_t4_Save.Enabled     = $False
        $btn_t4_Generate.Enabled = $False

        [string]$Cmd = "PowerShell -Command {& '$script:ExecutionFolder\compiler.ps1' -Settings $(Split-Path -Path $script:saveFile -Leaf)}"
        Invoke-Expression -Command $Cmd

        [System.Windows.Forms.MessageBox]::Show($MainFORM, "Custom QA Script generated", 'Generate QA Script', 'OK', 'Information') 

        $btn_t4_Save.Enabled     = $True
        $btn_t4_Generate.Enabled = $True
        $MainFORM.Cursor = 'Default'
    }

    $btn_RestoreINI_Click = {
        [string]$msgbox = [System.Windows.Forms.MessageBox]::Show($MainFORM, "If you have lost your settings file, you can use this option to restore it.`nClick 'OK' to select the compiled QA script you want to restore the settings from.", 'Restore Settings File', 'OKCancel', 'Information')
        If ($msgbox -eq 'Cancel') { Return }

        [string]$originalQA = (Get-File -InitialDirectory $script:ExecutionFolder -Title 'Select the compiled QA script to restore the settings from:')
        If ([string]::IsNullOrEmpty($originalQA)) { Return }
        $MainFORM.Cursor = 'WaitCursor'

        # Start retrevial process
        [array]   $skippedChecks = ''
        [string[]]$content   = (Get-Content -Path $originalQA)
        [string]  $enabledF  = ([regex]::Match($content, '(\[array\]\$script\:qaChecks \= \()((?:.|\s)+?)(?:(?:[A-Z\- ]+:)|(?:#>))'))
                  $enabledF  = $enabledF.Replace(' ', '').Trim()
        [string[]]$functions = ($content | Select-String -Pattern '(Function c-)([a-z]{3}[-][0-9]{2})' -AllMatches)
        [string]  $FuncOLD = ''
        [string]  $FuncNEW = ''

        ForEach ($func In $functions) { If ($enabledF.Contains($func) -eq $false) { $skippedChecks += ($func.Substring(11, 6).Replace('-', '')) } }

        [System.Text.StringBuilder]$outputFile = ''
        $outputFile.AppendLine('[settings]')                   | Out-Null
        $outputFile.AppendLine('shortcode         = RESTORED') | Out-Null
        $outputFile.AppendLine('language          = en-gb')    | Out-Null

        ForEach ($line In $content)
        {
            If ($line.StartsWith('[string]$reportCompanyName')) { $outputFile.AppendLine("reportCompanyName =$($line.Split('=')[1])".Replace('"', '').Trim()) | Out-Null }
            If ($line.StartsWith('[string]$script:qaOutput'  )) { $outputFile.AppendLine("outputLocation    =$($line.Split('=')[1])".Replace('"', '').Trim()) | Out-Null
                $outputFile.AppendLine('') | Out-Null
                Break
            }
        }

        ForEach ($line In $content)
        {
            If ($line.StartsWith('Function newResult { Return ')) { [string]$funcName = ''; [string[]]$appSettings = $null }
            If ($line.StartsWith('$script:appSettings['        )) {
                [string[]]$newLine = ($line.Substring(21).Replace("']", '')).Split('=')
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

                If ($skippedChecks.Contains($funcName))    { $outputFile.AppendLine("[$funcName-skip]") | Out-Null }
                Else                                       { $outputFile.AppendLine("[$funcName]"     ) | Out-Null }
                If ([string]::IsNullOrEmpty($appSettings)) { $outputFile.AppendLine("; No Settings")    | Out-Null }
                Else { ForEach ($setting In $appSettings)  { $outputFile.AppendLine($setting)           | Out-Null } }
                $outputFile.AppendLine('')                                                              | Out-Null
             }
        }

        $outputFile.ToString() | Out-File -FilePath "$(Split-Path -Path $originalQA -Parent)\RESTORED.ini" -Encoding ascii -Force

        $MainFORM.Cursor = 'Default'
        [System.Windows.Forms.MessageBox]::Show($MainFORM, "Restore Complete`nThe file is called 'RESTORED.ini'`n`nIt is located in the same folder as the QA script you selected.`nRemember to move this to the Settings folder.", 'Restore Settings File', 'OK', 'Information')
    }

    $btn_Settings_Click = {
        $MainFORM.Cursor = 'WaitCursor'
        [object]$settings = Show-ExtraSettingsForm -Timeout ($script:settings.Timeout) -ccTasks ($script:settings.ccTasks) -ResultsPath ($script:settings.ResultsPath)
        If ([string]::IsNullOrEmpty($settings) -eq $false) { [psobject]$script:settings = $settings }
        $MainFORM.Cursor = 'Default'
    }
#endregion
###################################################################################################
#region FORM ITEMS
#region MAIN FORM
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $MainFORM                     = New-Object 'System.Windows.Forms.Form'
    $img_ListImages               = New-Object 'System.Windows.Forms.ImageList'
    $img_Input                    = New-Object 'System.Windows.Forms.ImageList'
    $tab_Pages                    = New-Object 'System.Windows.Forms.TabControl'
    $tab_Page1                    = New-Object 'System.Windows.Forms.TabPage'
    $tab_Page2                    = New-Object 'System.Windows.Forms.TabPage'
    $tab_Page3                    = New-Object 'System.Windows.Forms.TabPage'
    $tab_Page4                    = New-Object 'System.Windows.Forms.TabPage'
    $lbl_ChangesMade              = New-Object 'System.Windows.Forms.Label'
    $btn_RestoreINI               = New-Object 'System.Windows.Forms.Button'
    $btn_Exit                     = New-Object 'System.Windows.Forms.Button'
    $btn_Settings                 = New-Object 'System.Windows.Forms.Button'

    # TAB 1
    $lbl_t1_Welcome               = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_Introduction          = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_ScanningScripts       = New-Object 'System.Windows.Forms.Label'
    $btn_t1_Search                = New-Object 'System.Windows.Forms.Button'
    $lbl_t1_Language              = New-Object 'System.Windows.Forms.Label'
    $cmo_t1_Language              = New-Object 'System.Windows.Forms.ComboBox'
    $lbl_t1_SettingsFile          = New-Object 'System.Windows.Forms.Label'
    $cmo_t1_SettingsFile          = New-Object 'System.Windows.Forms.ComboBox'
    $btn_t1_Import                = New-Object 'System.Windows.Forms.Button'

    # TAB 2
    $lbl_t2_CheckSelection        = New-Object 'System.Windows.Forms.Label'
    $lst_t2_SelectChecks          = New-Object 'System.Windows.Forms.ListView'
    $lst_t2_SelectChecks_CH_Code  = New-Object 'System.Windows.Forms.ColumnHeader'
    $lst_t2_SelectChecks_CH_Name  = New-Object 'System.Windows.Forms.ColumnHeader'
    $lst_t2_SelectChecks_CH_Desc  = New-Object 'System.Windows.Forms.ColumnHeader'
    $lbl_t2_Description           = New-Object 'System.Windows.Forms.Label'
    $lbl_t2_SelectedCount         = New-Object 'System.Windows.Forms.Label'
    $lbl_t2_Select                = New-Object 'System.Windows.Forms.Label'
    $btn_t2_SelectAll             = New-Object 'System.Windows.Forms.Button'
    $btn_t2_SelectInv             = New-Object 'System.Windows.Forms.Button'
    $btn_t2_NextPage              = New-Object 'System.Windows.Forms.Button'
    $btn_t2_SelectNone            = New-Object 'System.Windows.Forms.Button'
    $pic_t2_Background            = New-Object 'System.Windows.Forms.PictureBox'

    # TAB 3 
    $lbl_t3_ScriptSelection       = New-Object 'System.Windows.Forms.Label'
    $tab_t3_Pages                 = New-Object 'System.Windows.Forms.TabControl'    # TabPages are generated automatically
    $lbl_t3_NoParameters          = New-Object 'System.Windows.Forms.Label'

    # TAB 4
    $lbl_t4_Complete              = New-Object 'System.Windows.Forms.Label'
    $lbl_t4_Complete_Info         = New-Object 'System.Windows.Forms.Label'
    $lbl_t4_ShortCode             = New-Object 'System.Windows.Forms.Label'
    $lbl_t4_ReportTitle           = New-Object 'System.Windows.Forms.Label'
    $lbl_t4_QAReport              = New-Object 'System.Windows.Forms.Label'
    $txt_t4_ShortCode             = New-Object 'System.Windows.Forms.TextBox'
    $txt_t4_ReportTitle           = New-Object 'System.Windows.Forms.TextBox'
    $btn_t4_Save                  = New-Object 'System.Windows.Forms.Button'
    $btn_t4_Generate              = New-Object 'System.Windows.Forms.Button'
#endregion
#region MAIN FORM 2
    $MainFORM.SuspendLayout()
    $tab_Pages.SuspendLayout()
    $tab_Page1.SuspendLayout()
    $tab_Page2.SuspendLayout()
    $tab_Page3.SuspendLayout()
    $tab_Page4.SuspendLayout()

    # MainForm
    $MainFORM.AutoScaleDimensions = '6, 13'
    $MainFORM.AutoScaleMode       = 'Font'
    $MainFORM.ClientSize          = '794, 672'    # 800 x 700
    $MainFORM.FormBorderStyle     = 'FixedSingle'
    $MainFORM.MaximizeBox         = $False
    $MainFORM.StartPosition       = 'CenterScreen'
    $MainFORM.Text                = ' QA Scripts Customiser'
    $MainFORM.Icon                = [System.Convert]::FromBase64String('
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
    $MainFORM.CancelButton        = $btn_Exit
    $MainFORM.Add_Load($MainFORM_Load)
    $MainFORM.Add_FormClosing($MainFORM_FormClosing)

    $tab_Pages.Location      = ' 12,  12'
    $tab_Pages.Size          = '770, 608'
    $tab_Pages.Padding       = ' 12,   6'
    $tab_Pages.SelectedIndex = 0
    $tab_Pages.TabIndex      = 0
    $tab_Pages.Controls.Add($tab_Page1)    # Introduction
    $tab_Pages.Controls.Add($tab_Page2)    # Select Required Checks
    $tab_Pages.Controls.Add($tab_Page3)    # Specific QA Values
    $tab_Pages.Controls.Add($tab_Page4)    # Generate QA
    $tab_Pages.Add_SelectedIndexChanged($tab_Pages_SelectedIndexChanged)
    $MainFORM.Controls.Add($tab_Pages)

    # tabpage1
    $tab_Page1.TabIndex  = 0
    $tab_Page1.BackColor = 'Control'
    $tab_Page1.Text      = 'Introduction'

    # tabpage2
    $tab_Page2.TabIndex  = 1
    $tab_Page2.BackColor = 'Control'
    $tab_Page2.Text      = 'Select Required Checks'

    # tabpage3
    $tab_Page3.TabIndex  = 2
    $tab_Page3.BackColor = 'Control'
    $tab_Page3.Text      = 'QA Check Values'

    # tabpage4
    $tab_Page4.TabIndex  = 3
    $tab_Page4.BackColor = 'Control'
    $tab_Page4.Text      = 'Generate QA'
#endregion
#region TAB 1 - Introduction / Select Location / Import
    # lbl_t1_Welcome
    $lbl_t1_Welcome.Location  = '  9,   9'
    $lbl_t1_Welcome.Size      = '744,  20'
    $lbl_t1_Welcome.Text      = 'Welcome.!'
    $lbl_t1_Welcome.TextAlign = 'BottomLeft'
    $tab_Page1.Controls.Add($lbl_t1_Welcome)

    # lbl_t1_Introduction
    $lbl_t1_Introduction.Location  = '9, 35'
    $lbl_t1_Introduction.Size      = '744, 175'
    $lbl_t1_Introduction.TextAlign = 'TopLeft'
    $lbl_t1_Introduction.Text      = @"
This script will help you create a custom settings file for the QA checks, one that is tailored for your environment.


It will allow you to select which checks you want to use and which to skip.  You will also be able to set specific values for each of the check settings.  For a more detailed description on using this script, please read the documentation.




To start, click the 'Set Check Location' button below...
"@
    $tab_Page1.Controls.Add($lbl_t1_Introduction)

    # btn_t1_Search
    $btn_t1_Search.Location = '306, 325'
    $btn_t1_Search.Size     = '150, 35'
    $btn_t1_Search.Text     = 'Set Check Location'
    $btn_t1_Search.TabIndex = 0
    $btn_t1_Search.Add_Click($btn_t1_Search_Click)
    $tab_Page1.Controls.Add($btn_t1_Search)

    # cmo_t1_Language
    $cmo_t1_Language.Location      = '306, 387'
    $cmo_t1_Language.Size          = '150,  21'
    $cmo_t1_Language.DropDownStyle = 'DropDownList'
    $cmo_t1_Language.Enabled       = $False
    $cmo_t1_Language.TabIndex      = 1
    $tab_Page1.Controls.Add($cmo_t1_Language)
    
    # lbl_t1_Language
    $lbl_t1_Language.Location  = '  9, 387'
    $lbl_t1_Language.Size      = '291,  21'
    $lbl_t1_Language.Text      = 'Language :'
    $lbl_t1_Language.TextAlign = 'MiddleRight'
    $lbl_t1_Language.Enabled   = $False
    $tab_Page1.Controls.Add($lbl_t1_Language)

    # cmo_t1_SettingsFile
    $cmo_t1_SettingsFile.Location      = '306, 423'
    $cmo_t1_SettingsFile.Size          = "150,  $($cmo_t1_Language.Height)"
    $cmo_t1_SettingsFile.DropDownStyle = 'DropDownList'
    $cmo_t1_SettingsFile.Enabled       = $False
    $cmo_t1_SettingsFile.TabIndex      = 2
    $tab_Page1.Controls.Add($cmo_t1_SettingsFile)

    # lbl_t1_SettingsFile
    $lbl_t1_SettingsFile.Location  = '  9, 423'
    $lbl_t1_SettingsFile.Size      = "291,  $($cmo_t1_SettingsFile.Height)"
    $lbl_t1_SettingsFile.Text      = 'Base Settings File :'
    $lbl_t1_SettingsFile.TextAlign = 'MiddleRight'
    $lbl_t1_SettingsFile.Enabled   = $False
    $tab_Page1.Controls.Add($lbl_t1_SettingsFile)

    # btn_t1_Import
    $btn_t1_Import.Location = '306, 471'
    $btn_t1_Import.Size     = '150,  35'
    $btn_t1_Import.Text     = 'Import Settings'
    $btn_t1_Import.Enabled  = $False
    $btn_t1_Import.TabIndex = 3
    $btn_t1_Import.Add_Click($btn_t1_Import_Click)
    $tab_Page1.Controls.Add($btn_t1_Import)

    # lbl_t1_ScanningScripts
    $lbl_t1_ScanningScripts.Location  = '  9, 547'
    $lbl_t1_ScanningScripts.Size      = '744,  20'
    $lbl_t1_ScanningScripts.Text      = ''
    $lbl_t1_ScanningScripts.TextAlign = 'BottomLeft'
    $lbl_t1_ScanningScripts.Visible   = $False
    $tab_Page1.Controls.Add($lbl_t1_ScanningScripts)
#endregion
#region TAB 2 - Select QA Checkes To Include
    # lbl_t2_ScriptSelection
    $lbl_t2_CheckSelection.Location  = '  9,   9'
    $lbl_t2_CheckSelection.Size      = '744,  20'
    $lbl_t2_CheckSelection.Text      = 'Select the QA checks you want to enable for this settings file:'
    $lbl_t2_CheckSelection.TextAlign = 'BottomLeft'
    $tab_Page2.Controls.Add($lbl_t2_CheckSelection)

    # lst_t2_SelectChecks
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
    $lst_t2_SelectChecks.Columns.Add($lst_t2_SelectChecks_CH_Code) | Out-Null
    $lst_t2_SelectChecks.Columns.Add($lst_t2_SelectChecks_CH_Name) | Out-Null
    $lst_t2_SelectChecks.Columns.Add($lst_t2_SelectChecks_CH_Desc) | Out-Null
    $lst_t2_SelectChecks_CH_Code.Text   = 'Check'
    $lst_t2_SelectChecks_CH_Name.Text   = 'Name'
    $lst_t2_SelectChecks_CH_Desc.Text   = ''         # Description
    $lst_t2_SelectChecks_CH_Code.Width  = 100
    $lst_t2_SelectChecks_CH_Name.Width  = 366 - ([System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth + 4)
    $lst_t2_SelectChecks_CH_Desc.Width  =   0
    $lst_t2_SelectChecks.Add_ItemChecked($lst_t2_SelectChecks_ItemChecked)
    $lst_t2_SelectChecks.Add_SelectedIndexChanged($lst_t2_SelectChecks_SelectedIndexChanged)
    $tab_Page2.Controls.Add($lst_t2_SelectChecks)

    # lbl_Description
    $lbl_t2_Description.BackColor   = 'Window'
    $lbl_t2_Description.Location    = '475,  36'
    $lbl_t2_Description.Size        = '277, 449'
    $lbl_t2_Description.Padding     = '3, 3, 3, 3'    # Internal padding
    $lbl_t2_Description.Text        = ''
    $lbl_t2_Description.TextAlign   = 'TopLeft'
    $tab_Page2.Controls.Add($lbl_t2_Description)

    # lbl_t2_SelectedCount
    $lbl_t2_SelectedCount.Location  = '  9, 542'
    $lbl_t2_SelectedCount.Size      = '227,  25'
    $lbl_t2_SelectedCount.Text      = '0 of 0 checks selected'
    $lbl_t2_SelectedCount.TextAlign = 'MiddleLeft'
    $tab_Page2.Controls.Add($lbl_t2_SelectedCount)

    # lbl_t2_Select
    $lbl_t2_Select.Location  = '242, 542'
    $lbl_t2_Select.Size      = ' 50,  25'
    $lbl_t2_Select.Text      = 'Select :'
    $lbl_t2_Select.TextAlign = 'MiddleRight'
    $tab_Page2.Controls.Add($lbl_t2_Select)

    # btn_t2_SelectAll
    $btn_t2_SelectAll.Location = '298, 542'
    $btn_t2_SelectAll.Size     = ' 50,  25'
    $btn_t2_SelectAll.Text     = 'All'
    $btn_t2_SelectAll.Enabled  = $False
    $btn_t2_SelectAll.Add_Click($btn_t2_SelectAll_Click)
    $tab_Page2.Controls.Add($btn_t2_SelectAll)

    # btn_t2_SelectAll
    $btn_t2_SelectInv.Location = '354, 542'
    $btn_t2_SelectInv.Size     = ' 50,  25'
    $btn_t2_SelectInv.Text     = 'Invert'
    $btn_t2_SelectInv.Enabled  = $False
    $btn_t2_SelectInv.Add_Click($btn_t2_SelectInv_Click)
    $tab_Page2.Controls.Add($btn_t2_SelectInv)

    # btn_t2_SelectAll
    $btn_t2_SelectNone.Location = '410, 542'
    $btn_t2_SelectNone.Size     = ' 50,  25'
    $btn_t2_SelectNone.Text     = 'None'
    $btn_t2_SelectNone.Enabled  = $False
    $btn_t2_SelectNone.Add_Click($btn_t2_SelectNone_Click)
    $tab_Page2.Controls.Add($btn_t2_SelectNone)

    # btn_t2_NextPage
    $btn_t2_NextPage.Location = '642, 491'
    $btn_t2_NextPage.Size     = '105,  30'
    $btn_t2_NextPage.Text     = 'Next  >'
    $btn_t2_NextPage.Enabled  = $False
    $btn_t2_NextPage.Add_Click($btn_t2_NextPage_Click)
    $tab_Page2.Controls.Add($btn_t2_NextPage)
    $btn_t2_NextPage.BringToFront()

    # pic_Background
    $pic_t2_Background.Location    = '474,  35'
    $pic_t2_Background.Size        = '279, 492'
    $pic_t2_Background.BackColor   = 'Window'
    $pic_t2_Background.BorderStyle = 'FixedSingle'
    $pic_t2_Background.SendToBack()
    $tab_Page2.Controls.Add($pic_t2_Background)
#endregion
#region TAB 3 - Enter Values For Checks
    # lbl_NoParameters
    $lbl_t3_NoParameters.Location  = '19, 218'
    $lbl_t3_NoParameters.Size      = '724, 50'
    $lbl_t3_NoParameters.Text      = "Enabled QA checks have not been comfirmed yet.`nPlease click 'Next >' on the previous tab."
    $lbl_t3_NoParameters.TextAlign = 'MiddleCenter'
    $lbl_t3_NoParameters.BringToFront()
    $lbl_t3_NoParameters.BackColor = 'Window'
    $lbl_t3_NoParameters.Visible   = $True
    $tab_Page3.Controls.Add($lbl_t3_NoParameters)

    # lbl_t3_ScriptSelection
    $lbl_t3_ScriptSelection.Location  = '  9,   9'
    $lbl_t3_ScriptSelection.Size      = '744,  20'
    $lbl_t3_ScriptSelection.Text      = 'Double-click an enabled entry to set its value'
    $lbl_t3_ScriptSelection.TextAlign = 'BottomLeft'
    $tab_Page3.Controls.Add($lbl_t3_ScriptSelection)

    # tab_t3_Pages
    $tab_t3_Pages.Location      = '  9,  35'
    $tab_t3_Pages.Size          = '744, 532'
    $tab_t3_Pages.Padding       = '  8,   4'
    $tab_t3_Pages.SelectedIndex = 0
    $tab_Page3.Controls.Add($tab_t3_Pages)
#endregion
#region TAB 4 - Generate Settings And QA Script
    # lbl_t1_Welcome
    $lbl_t4_Complete.Location  = '  9,   9'
    $lbl_t4_Complete.Size      = '744,  20'
    $lbl_t4_Complete.Text      = 'Complete.!'
    $lbl_t4_Complete.TextAlign = 'BottomLeft'
    $tab_Page4.Controls.Add($lbl_t4_Complete)

    # lbl_t4_Complete_Info
    $lbl_t4_Complete_Info.Location  = '  9,  35'
    $lbl_t4_Complete_Info.Size      = '744, 175'
    $lbl_t4_Complete_Info.TextAlign = 'TopLeft'
    $lbl_t4_Complete_Info.Text      = @"
Enter a short code for this settings file, this will save the QA script file with it as part of the name.
For example: 'QA_ACME_v3.xx.xxxx.ps1'.

Also enter a name or other label for the HTML results file.  This is automatically appended with 'QA Report'.
For example: 'ACME QA Report'.




Click the 'Save Settings' button below to save your selections and values.
Once done, you can then click 'Generate QA Script' to create the compiled QA script'
"@
    $tab_Page4.Controls.Add($lbl_t4_Complete_Info)

    # lbl_t4_ShortCode
    $lbl_t4_ShortCode.Location  = '  9, 325'
    $lbl_t4_ShortCode.Size      = '291,  20'
    $lbl_t4_ShortCode.TextAlign = 'MiddleRight'
    $lbl_t4_ShortCode.Text      = 'Settings Short Code :'
    $tab_Page4.Controls.Add($lbl_t4_ShortCode)

    # lbl_t4_ReportTitle
    $lbl_t4_ReportTitle.Location  = '  9, 361'
    $lbl_t4_ReportTitle.Size      = '291,  20'
    $lbl_t4_ReportTitle.TextAlign = 'MiddleRight'
    $lbl_t4_ReportTitle.Text      = 'HTML Report Company Name :'
    $tab_Page4.Controls.Add($lbl_t4_ReportTitle)

    # lbl_t4_QAReport
    $lbl_t4_QAReport.Location  = '462, 361'
    $lbl_t4_QAReport.Size      = '291,  20'
    $lbl_t4_QAReport.TextAlign = 'MiddleLeft'
    $lbl_t4_QAReport.Text      = 'QA Report'
    $tab_Page4.Controls.Add($lbl_t4_QAReport)

    # txt_t4_ShortCode
    $txt_t4_ShortCode.Location  = '306, 325'
    $txt_t4_ShortCode.Size      = '150,  20'
    $txt_t4_ShortCode.TextAlign = 'Center'
    $tab_Page4.Controls.Add($txt_t4_ShortCode)

    # txt_t4_ReportTitle
    $txt_t4_ReportTitle.Location  = '306, 361'
    $txt_t4_ReportTitle.Size      = '150,  20'
    $txt_t4_ReportTitle.TextAlign = 'Center'
    $tab_Page4.Controls.Add($txt_t4_ReportTitle)

    # btn_t4_Save
    $btn_t4_Save.Location = '306, 421'
    $btn_t4_Save.Size     = '150,  35'
    $btn_t4_Save.Text     = 'Save Settings'
    $btn_t4_Save.Enabled  = $False
    $btn_t4_Save.Add_Click($btn_t4_Save_Click)
    $tab_Page4.Controls.Add($btn_t4_Save)

    # btn_t4_Generate
    $btn_t4_Generate.Location = '306, 471'
    $btn_t4_Generate.Size     = '150,  35'
    $btn_t4_Generate.Text     = 'Generate QA Script'
    $btn_t4_Generate.Enabled  = $False
    $btn_t4_Generate.Add_Click($btn_t4_Generate_Click)
    $tab_Page4.Controls.Add($btn_t4_Generate)
#endregion
#region Common Controls
    # btn_RestoreINI
    $btn_RestoreINI.Location = ' 12, 635'
    $btn_RestoreINI.Size     = '150,  25'
    $btn_RestoreINI.TabIndex = 99
    $btn_RestoreINI.Text     = 'Restore Settings File'
    $btn_RestoreINI.Add_Click($btn_RestoreINI_Click)
    $MainFORM.Controls.Add($btn_RestoreINI)

    # btn_Cancel
    $btn_Exit.Location = '707, 635'
    $btn_Exit.Size     = '75, 25'
    $btn_Exit.TabIndex = 98
    $btn_Exit.Text     = 'Exit'
    $btn_Exit.DialogResult = [System.Windows.Forms.DialogResult]::Cancel    # Use this instead of a "Click" event
    $MainFORM.Controls.Add($btn_Exit)

    # $tn_Settings
    $btn_Settings.Location = '322, 635'
    $btn_Settings.Size     = '150,  25'
    $btn_Settings.TabIndex = 97
    $btn_Settings.Text     = 'Additonal Settings'
    $btn_Settings.Visible  = $False
    $btn_Settings.Add_Click($btn_Settings_Click)
    $MainFORM.Controls.Add($btn_Settings)

    # lbl_ChangesMade
    $lbl_ChangesMade.Location  = '174, 630'
    $lbl_ChangesMade.Size      = '527,  35'
    $lbl_ChangesMade.Text      = "NOTE: If you make any selection changes and click 'Next', any unsaved changes will be lost."
    $lbl_ChangesMade.TextAlign = 'MiddleLeft'
    $lbl_ChangesMade.Visible   = $False
    $MainFORM.Controls.Add($lbl_ChangesMade)

    # img_ListImages - All 16x16 Icons
    $img_ListImages.TransparentColor = 'Transparent'
    $img_ListImages_binaryFomatter   = New-Object 'System.Runtime.Serialization.Formatters.Binary.BinaryFormatter'
    $img_ListImages_MemoryStream     = New-Object 'System.IO.MemoryStream' (,[byte[]][System.Convert]::FromBase64String('
        AAEAAAD/////AQAAAAAAAAAMAgAAAFdTeXN0ZW0uV2luZG93cy5Gb3JtcywgVmVyc2lvbj00LjAuMC4wLCBDdWx0dXJlPW5ldXRyYWwsIFB1YmxpY0tleVRva2VuPWI3N2E1YzU2MTkzNGUwODkFAQAAACZTeXN0ZW0uV2luZG93cy5Gb3Jtcy5JbWFnZUxpc3RTdHJlYW1lcgEAAAAERGF0YQcCAgAAAAkD
        AAAADwMAAACCCgAAAk1TRnQBSQFMAgEBAwEAAWgBAAFoAQABEAEAARABAAT/AQkBAAj/AUIBTQE2AQQGAAE2AQQCAAEoAwABQAMAARADAAEBAQABCAYAAQQYAAGAAgABgAMAAoABAAGAAwABgAEAAYABAAKAAgADwAEAAcAB3AHAAQAB8AHKAaYBAAEzBQABMwEAATMBAAEzAQACMwIAAxYBAAMcAQADIgEA
        AykBAANVAQADTQEAA0IBAAM5AQABgAF8Af8BAAJQAf8BAAGTAQAB1gEAAf8B7AHMAQABxgHWAe8BAAHWAucBAAGQAakBrQIAAf8BMwMAAWYDAAGZAwABzAIAATMDAAIzAgABMwFmAgABMwGZAgABMwHMAgABMwH/AgABZgMAAWYBMwIAAmYCAAFmAZkCAAFmAcwCAAFmAf8CAAGZAwABmQEzAgABmQFmAgAC
        mQIAAZkBzAIAAZkB/wIAAcwDAAHMATMCAAHMAWYCAAHMAZkCAALMAgABzAH/AgAB/wFmAgAB/wGZAgAB/wHMAQABMwH/AgAB/wEAATMBAAEzAQABZgEAATMBAAGZAQABMwEAAcwBAAEzAQAB/wEAAf8BMwIAAzMBAAIzAWYBAAIzAZkBAAIzAcwBAAIzAf8BAAEzAWYCAAEzAWYBMwEAATMCZgEAATMBZgGZ
        AQABMwFmAcwBAAEzAWYB/wEAATMBmQIAATMBmQEzAQABMwGZAWYBAAEzApkBAAEzAZkBzAEAATMBmQH/AQABMwHMAgABMwHMATMBAAEzAcwBZgEAATMBzAGZAQABMwLMAQABMwHMAf8BAAEzAf8BMwEAATMB/wFmAQABMwH/AZkBAAEzAf8BzAEAATMC/wEAAWYDAAFmAQABMwEAAWYBAAFmAQABZgEAAZkB
        AAFmAQABzAEAAWYBAAH/AQABZgEzAgABZgIzAQABZgEzAWYBAAFmATMBmQEAAWYBMwHMAQABZgEzAf8BAAJmAgACZgEzAQADZgEAAmYBmQEAAmYBzAEAAWYBmQIAAWYBmQEzAQABZgGZAWYBAAFmApkBAAFmAZkBzAEAAWYBmQH/AQABZgHMAgABZgHMATMBAAFmAcwBmQEAAWYCzAEAAWYBzAH/AQABZgH/
        AgABZgH/ATMBAAFmAf8BmQEAAWYB/wHMAQABzAEAAf8BAAH/AQABzAEAApkCAAGZATMBmQEAAZkBAAGZAQABmQEAAcwBAAGZAwABmQIzAQABmQEAAWYBAAGZATMBzAEAAZkBAAH/AQABmQFmAgABmQFmATMBAAGZATMBZgEAAZkBZgGZAQABmQFmAcwBAAGZATMB/wEAApkBMwEAApkBZgEAA5kBAAKZAcwB
        AAKZAf8BAAGZAcwCAAGZAcwBMwEAAWYBzAFmAQABmQHMAZkBAAGZAswBAAGZAcwB/wEAAZkB/wIAAZkB/wEzAQABmQHMAWYBAAGZAf8BmQEAAZkB/wHMAQABmQL/AQABzAMAAZkBAAEzAQABzAEAAWYBAAHMAQABmQEAAcwBAAHMAQABmQEzAgABzAIzAQABzAEzAWYBAAHMATMBmQEAAcwBMwHMAQABzAEz
        Af8BAAHMAWYCAAHMAWYBMwEAAZkCZgEAAcwBZgGZAQABzAFmAcwBAAGZAWYB/wEAAcwBmQIAAcwBmQEzAQABzAGZAWYBAAHMApkBAAHMAZkBzAEAAcwBmQH/AQACzAIAAswBMwEAAswBZgEAAswBmQEAA8wBAALMAf8BAAHMAf8CAAHMAf8BMwEAAZkB/wFmAQABzAH/AZkBAAHMAf8BzAEAAcwC/wEAAcwB
        AAEzAQAB/wEAAWYBAAH/AQABmQEAAcwBMwIAAf8CMwEAAf8BMwFmAQAB/wEzAZkBAAH/ATMBzAEAAf8BMwH/AQAB/wFmAgAB/wFmATMBAAHMAmYBAAH/AWYBmQEAAf8BZgHMAQABzAFmAf8BAAH/AZkCAAH/AZkBMwEAAf8BmQFmAQAB/wKZAQAB/wGZAcwBAAH/AZkB/wEAAf8BzAIAAf8BzAEzAQAB/wHM
        AWYBAAH/AcwBmQEAAf8CzAEAAf8BzAH/AQAC/wEzAQABzAH/AWYBAAL/AZkBAAL/AcwBAAJmAf8BAAFmAf8BZgEAAWYC/wEAAf8CZgEAAf8BZgH/AQAC/wFmAQABIQEAAaUBAANfAQADdwEAA4YBAAOWAQADywEAA7IBAAPXAQAD3QEAA+MBAAPqAQAD8QEAA/gBAAHwAfsB/wEAAaQCoAEAA4ADAAH/AgAB
        /wMAAv8BAAH/AwAB/wEAAf8BAAL/AgAD/xUAAfMB/wEAAe8BkQEAAf8B8QH/NgAB8QG1AfEB8wKRAfEBBwGuAfEpAAP0CgAB8wK1A7sCtQGRAfIFAAH0AVIEMAEDBDABURYAAvQBtQGMAbUC9AYAAvMB7gG7AfACvAEJAbsCtQHvAfMB8gMAARsBWAM4AQMBEwFSAzgBUhUAAfQB7gGMAa8BjAGvAYwB7gH0
        BAAB/wK7AQkB3QEJA7sCtQG7AbUCkQH/AgAB9gF6AV4B+wE4ATABSgE3AjgBNwF0FAAB9AGvAYwBvAH0AYwB9AG8AYwBrwH0BAAB9AEJARkBCQG7AfQCAAHzArUBuwGRAfMDAAH/ARsBegFeAvsBNwM4AVIB8xQAAfQBjAP0AYwD9AGMAfQEAAH0AbsB8AG7AfIEAAHyAbUBuwHtAfQEAAH/AZoB5QFeATcB
        SgE4AfsBNwEcAf8UAAH0AYwC9AHwAYwB8AL0AYwB9AMAArsBCQHwAfcFAAH/AbUBuwG1ApEDAAH/ARsC5QFYARIBOAH7AVIBGgH/FAAB9AGMAfMBtQGvAfEBrwG1AfMBjAH0AwAB8AMJAZEFAAH1AbUBuwK1AQcEAAH/AXoB5QFRAUMBWAE4AXQB/xUAAfQBjAGNAbwD9AG8AY0BjAH0BAAB/wG7ARkBtQHw
        BAAB8QK7AbUB/wYAARsB5QFzAUMBWAE3ARoWAAH0Aa8BjAG8A/QBvAGMAa8B9AMAAf8B8AEJAfEBCQH3AQcC/wHuAbsBBwG7AbUBBwYAAfYCegJYAVEB/xcAAfQB7gGMAa8B8QGvAYwB7gH0BAAB/wK7AQkBGQG8AbsCtQS7AbUBkQYAAf8BGwJeATcBGhkAAvQBtQGMAbUC9AYAA/QBCQPxAfABCQK7AfIC
        9AcAAfYBegFYAXkB9BsAA/QKAAH0AbsECQG7ArUB8wkAAf8C9AH1Af8oAAH0AQcB9AH/ArsB9AHyAbsB9DoAAe4BuycAAUIBTQE+BwABPgMAASgDAAFAAwABEAMAAQEBAAEBBQABgBcAA/8BAAL/AfIBRwL/AgAC/wHgAQcC/wIAAfwBfwHgAQcBwAEDAgAB8AEfAYABAQHAAQMCAAHgAQ8CAAHAAQMCAAHA
        AQcCgQHAAQMCAAHAAQcBgwHBAeABAwIAAcACBwHAAeABAwIAAcACBwHAAfABBwIAAcABBwGDAcEB+AEPAgABwAEHAQABAQH4AQ8CAAHgAQ8BAAEBAfgBHwIAAfABHwGAAQEB/AEfAgAB/AF/AeABBwH8AR8CAAL/AeABBwL/AgAC/wH+AX8C/wIACw=='))
    $img_ListImages.ImageStream      = $img_ListImages_binaryFomatter.Deserialize($img_ListImages_MemoryStream)
    $img_ListImages_binaryFomatter   = $null
    $img_ListImages_MemoryStream     = $null

    # img_Input - 48x16 'INVALID' and 'DUPLICATE' images
    $img_Input.TransparentColor = 'Transparent'
    $img_Input_binaryFomatter   = New-Object 'System.Runtime.Serialization.Formatters.Binary.BinaryFormatter'
    $img_Input_MemoryStream     = New-Object 'System.IO.MemoryStream' (,[byte[]][System.Convert]::FromBase64String('
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
    $img_Input.ImageStream      = $img_Input_binaryFomatter.Deserialize($img_Input_MemoryStream)
    $img_Input_binaryFomatter   = $null
    $img_Input_MemoryStream     = $null

#endregion
#endregion
###################################################################################################
    $InitialFormWindowState = $MainFORM.WindowState
    $MainFORM.Add_Load($MainFORM_StateCorrection_Load)
    Return $MainFORM.ShowDialog()
}
###################################################################################################
        [string]  $script:saveFile        = ''
        [psobject]$script:settings        = New-Object -TypeName PSObject -Property @{
            'Timeout'     = '60';
            'ccTasks'     = '5';
            'ResultsPath' = '$env:SystemDrive\QA\Results\';
        }
Try   { [string]  $script:ExecutionFolder = (Split-Path -Path ((Get-Variable MyInvocation -ValueOnly -ErrorAction SilentlyContinue).MyCommand.Path) -ErrorAction SilentlyContinue) }
Catch { [string]  $script:ExecutionFolder = '' }
###################################################################################################
Display-MainForm | Out-Null
