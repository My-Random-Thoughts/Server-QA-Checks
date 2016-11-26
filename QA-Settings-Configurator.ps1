Remove-Variable * -ErrorAction SilentlyContinue
Clear-Host

[Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')      | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Data')               | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Drawing')            | Out-Null
[System.Drawing.Font]$sysFont       =                                   [System.Drawing.SystemFonts]::MessageBoxFont
[System.Drawing.Font]$sysFontBold   = New-Object 'System.Drawing.Font' ([System.Drawing.SystemFonts]::MessageBoxFont.Name, [System.Drawing.SystemFonts]::MessageBoxFont.SizeInPoints, [System.Drawing.FontStyle]::Bold)
[System.Drawing.Font]$sysFontItalic = New-Object 'System.Drawing.Font' ([System.Drawing.SystemFonts]::MessageBoxFont.Name, [System.Drawing.SystemFonts]::MessageBoxFont.SizeInPoints, [System.Drawing.FontStyle]::Italic)

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

Function Save-File ( [string]$InitialDirectory, [string]$Title, [string]$InitialFileName )
{
    [string]$return = ''
    $filename = New-Object 'System.Windows.Forms.SaveFileDialog'
    $filename.InitialDirectory = $InitialDirectory
    $filename.Title            = $Title
    $filename.FileName         = $InitialFileName
    $filename.Filter           = 'QA Configuration Settings (*.ini)|*.ini|All Files|*.*'
    If ([threading.thread]::CurrentThread.GetApartmentState() -ne 'STA') { $filename.ShowHelp = $true }    # Workaround for MTA issues not showing dialog box
    If ($filename.ShowDialog($MainForm) -eq [System.Windows.Forms.DialogResult]::OK) { [string]$return = ($filename.FileName) }
    Try { $filename.Dispose() } Catch {}
    Return $return
}

Function Load-ComboBox ( [System.Windows.Forms.ComboBox]$ComboBox, $Items, [string]$SelectedItem, [switch]$Clear )
{
    If ($Clear) { $ComboBox.Items.Clear() }
    If ($Items -is [Object[]]) { $ComboBox.Items.AddRange($Items) | Out-Null } Else { $ComboBox.Items.Add($Items) | Out-Null }
    If ([string]::IsNullOrEmpty($SelectedItem) -eq $False) { $ComboBox.SelectedItem = $SelectedItem }
}

Function Add-ListViewItem ( [System.Windows.Forms.ListView]$ListView, $Items, [int]$ImageIndex = -1, [string[]]$SubItems, [string]$Group, [switch]$Clear )
{
    If ($Clear) { $ListView.Items.Clear(); }
    [System.Windows.Forms.ListViewGroup]$lvGroup = $null
    ForEach ($groupItem in $ListView.Groups) { If ($groupItem.Name -eq $Group) { $lvGroup = $groupItem; Break } }
    If ($lvGroup -eq $null) { $lvGroup = $ListView.Groups.Add($Group, "ERR: $Group") }

    $listitem = $ListView.Items.Add($Items.ToString(), $Items.ToString(), $ImageIndex)
    If ($SubItems -ne $null) { $listitem.SubItems.AddRange($SubItems) }
    If ($lvGroup  -ne $null) { $listitem.Group = $lvGroup }
}

Function Load-IniFile ( [string]$Inputfile )
{
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
#endregion
###################################################################################################
##                                                                                               ##
##   Secondary Forms                                                                             ##
##                                                                                               ##
###################################################################################################
#region Secondary Forms
Function InputBoxFORM ( [string]$Type, [string]$Title, [string]$Instruction, [string]$InputList, [string]$SelectedValue)
{
#region Form Scripts
    [string]$script:ValidateAgainst = ''

    $AddButton_Click = {
        #     | Buttons: $OKButton, $CancelButton, $AddButton
        # 5 = | Label:   $lbl_Instruction
        #     | Picture: $img_Input
        AddButton_Click -BoxNumber (($inputForm.Controls.Count - 5) / 2) -Value '' -Override $false
    }
    Function AddButton_Click ( [int]$BoxNumber, [string]$Value, [boolean]$Override )
    {
        ForEach ($control In $inputForm.Controls) {
            If ($control -is [System.Windows.Forms.TextBox]) {
                [System.Windows.Forms.TextBox]$isEmtpy = $null
                If ([string]::IsNullOrEmpty($control.Text) -eq $True) { $isEmtpy = $control; Break }
            }
        }

        If ($Override -eq $true) { $isEmtpy = $null } 
        If ($isEmtpy -ne $null)
        {
            $isEmtpy.Select()
            $isEmtpy.Text = ($Value.Trim())
        }
        Else
        {
            # Increase form size, move buttons down, add new field
            $numberOfTextBoxes++
            $inputForm.ClientSize   = "394, $(147 + ($BoxNumber * 26))"
            $OKButton.Location      = "307, $(110 + ($BoxNumber * 26))"
            $CancelButton.Location  = "220, $(110 + ($BoxNumber * 26))"
            $AddButton.Location     = " 39, $(110 + ($BoxNumber * 26))"

            # Add new counter label
            $labelCounter           = New-Object 'System.Windows.Forms.Label'
            $labelCounter.Location  = " 12, $( 75 + ($BoxNumber * 26))"
            $labelCounter.Size      = ' 21,    20'
            $labelCounter.Text      = "$($BoxNumber + 1):"
            $labelCounter.TextAlign = 'MiddleRight'
            $inputForm.Controls.Add($labelCounter)

            # Add new text box and select it for focus
            $textBox                = New-Object 'System.Windows.Forms.TextBox'
            $textBox.Location       = " 39, $( 75 + ($BoxNumber * 26))"
            $textBox.Size           = '343,    20'
            $textBox.Font           = $sysFont
            $textBox.Name           = "textBox$BoxNumber"
            $textBox.Text           = ($Value.Trim())
            $inputForm.Controls.Add($textBox)
            $inputForm.Controls["textbox$BoxNumber"].Select()

            Start-Sleep -Milliseconds 75
        }
    }

    # Start form validation and make sure everything entered is correct
    $OKButton_Click = {
        [string[]]$currentValues = @('')
        [boolean]$ValidatedInput = $true

        ForEach ($Control In $inputForm.Controls)
        {
            If (($Control -is [System.Windows.Forms.TextBox]) -and ($Control.Visible -eq $true))
            {
                $Control.BackColor = 'Window'
                If (($Type -eq 'LIST') -and ($Control.Text.Contains(';') -eq $true))
                {
                    [string[]]$ControlText = ($Control.Text).Split(';')
                    $Control.Text = ''    # Remove current data so that it can be used as a landing control for the split data
                    ForEach ($item In $ControlText) { AddButton_Click -BoxNumber (($inputForm.Controls.Count - 5) / 2) -Value ($item.Trim()) -Override $false }
                }
            }
        }

        # Reset Control Loop for any new fields that may have been added
        ForEach ($Control In $inputForm.Controls)
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
        If ($ValidatedInput -eq $true) { $inputForm.DialogResult = [System.Windows.Forms.DialogResult]::OK }
    }

    Function ValidateInputBox ([System.Windows.Forms.Control]$Control)
    {
        $Control.Text = ($Control.Text.Trim())
        [boolean]$ValidateResult = $false
        [string] $StringToCheck  = $($Control.Text)

        # Ignore control if empty
        If ([string]::IsNullOrEmpty($StringToCheck) -eq $true) { Return $true }

        # Validate
        Switch ($script:ValidateAgainst)
        {
            'int' { $ValidateResult =  ($StringToCheck -match '^[\d]+$');                                              Break }    # Integer numbers only
            'dec' { $ValidateResult =  ($StringToCheck -match '^[\d]+\.[\d]+$');                                       Break }    # Decimal numbers only
            'num' { $ValidateResult =  ($StringToCheck -match '^([\d]+)?\.?[\d]+$');                                   Break }    # Both integer and decimal
            'url' { $ValidateResult =  ($StringToCheck -match '(https?|s?ftp|ftps?):\/\/');                            Break }    # URL protocols
            '@'   {                                                                                                               # email@address.validation
                Try   { $ValidateResult = (($StringToCheck -as [System.Net.Mail.MailAddress]).Address -eq $StringToCheck) }
                Catch { $ValidateResult = $false }; Break
            }
            'ip'  {                                                                                                               # IP address (1.2.3.4)
                [boolean]$Octets  = (($StringToCheck.Split(';') | Measure-Object).Count -eq 4)
                [boolean]$ValidIP =  ($StringToCheck -as [ipaddress]) -as [boolean]
                $ValidateResult   =  ($ValidIP -and $Octets)
                Break
            }
            Default { $ValidateResult = $true }
        }
        Return $ValidateResult
    }

    $InputForm_Cleanup_FormClosed = {
        Try {
            $OKButton.Remove_Click($OKButton_Click)
            $AddButton.Remove_Click($AddButton_Click)
        } Catch {}
        $inputForm.Remove_FormClosed($InputForm_Cleanup_FormClosed)
    }
#endregion
#region Input Form Controls
    $inputForm = New-Object 'System.Windows.Forms.Form'
    $inputForm.FormBorderStyle     = 'FixedDialog'
    $inputForm.MaximizeBox         = $False
    $inputForm.MinimizeBox         = $False
    $inputForm.ControlBox          = $False
    $inputForm.Text                = " $Title"    # Title
    $inputForm.ShowInTaskbar       = $false
    $inputForm.AutoScaleDimensions = '6, 13'
    $inputForm.AutoScaleMode       = 'Font'
    $inputForm.ClientSize          = '394, 147'    # 400 x 175
    $inputForm.StartPosition       = 'CenterParent'

    $pic_InvalidValue           = New-Object 'System.Windows.Forms.PictureBox'
    $pic_InvalidValue.BackColor = 'Info'
    $pic_InvalidValue.Location  = '  0,   0'
    $pic_InvalidValue.Size      = ' 48,  16'
    $pic_InvalidValue.Visible   = $false
    $pic_InvalidValue.TabStop   = $False
    $pic_InvalidValue.BringToFront()
    $inputForm.Controls.Add($pic_InvalidValue)

    $ToolTip                    = New-Object 'System.Windows.Forms.ToolTip'

    $lbl_Instruction            = New-Object 'System.Windows.Forms.Label'
    $lbl_Instruction.Location   = ' 12,  12'
    $lbl_Instruction.Size       = '370,  48'
    $lbl_Instruction.Text       =  $($Instruction.Split('|')[0].Trim())
    Try { $script:ValidateAgainst = ($Instruction.Split('|')[1].Trim()) } Catch { $script:ValidateAgainst = 'EVERYTHING' }
    $inputForm.Controls.Add($lbl_Instruction)

    $OKButton                   = New-Object 'System.Windows.Forms.Button'
    $OKButton.Location          = '307, 110'
    $OKButton.Size              = ' 75,  25'
    $OKButton.Text              = 'OK'
    $OKButton.TabIndex          = '97'
    $OKButton.Add_Click($OKButton_Click)
    If (($Type -ne 'MULTI') -and ($Type -ne 'LARGE')) { $inputForm.AcceptButton = $OKButton }
    $inputForm.Controls.Add($OKButton)

    $CancelButton               = New-Object 'System.Windows.Forms.Button'
    $CancelButton.Location      = '220, 110'
    $CancelButton.Size          = ' 75,  25'
    $CancelButton.Text          = 'Cancel'
    $CancelButton.TabIndex      = '98'
    $CancelButton.DialogResult  = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.CancelButton = $CancelButton
    $inputForm.Controls.Add($CancelButton)
    $inputForm.Add_FormClosed($InputForm_Cleanup_FormClosed)
#endregion
#region Input Form Controls Part 2
    Switch ($Type)
    {
        'LIST' {
            # List of text boxes
            $itemCount = ($SelectedValue.ToCharArray() | Where-Object { $_ -eq ';' } | Measure-Object).Count
            If ($itemCount -gt 5) { [int]$numberOfTextBoxes = $itemCount + 1 } Else { [int]$numberOfTextBoxes = 5 }
            $numberOfTextBoxes--    # Count from zero

            # Add [+] button
            $AddButton              = New-Object 'System.Windows.Forms.Button'
            $AddButton.Location     = " 39, $(110 + ($numberOfTextBoxes * 26))"
            $AddButton.Size         = ' 75,   25'
            $AddButton.Text         = 'Add'
            $AddButton.Add_Click($AddButton_Click)
            $inputForm.Controls.Add($AddButton)

            # Add initial textboxes
            # Clean up input first
            $SelectedValue = $SelectedValue.TrimStart('(').TrimEnd(')').Replace("'", "")
            For ($i = 0; $i -le $numberOfTextBoxes; $i++) { AddButton_Click -BoxNumber $i -Value $($SelectedValue.Split(";")[$i]) -Override $true }
            $inputForm.Controls['textbox0'].Select()
            Break
        }

        'TEXT' {
            # Add default text box
            $textBox                = New-Object 'System.Windows.Forms.TextBox'
            $textBox.Location       = ' 12,  75'
            $textBox.Size           = '370,  20'
            $textBox.Text            = ($SelectedValue.Trim())
            $inputForm.Controls.Add($textBox)
            Break
        }
        Default { Write-Warning "Invalid Input Form Type: $Type" }
    }
#endregion
#region Show Form And Return Value
    ForEach ($control In $inputForm.Controls) { $control.Font = $sysFont; }
    $result = $inputForm.ShowDialog($MainForm)

    If ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        Switch ($Type)
        {
            'LIST'  {
                [string]$return = ''
                ForEach ($Control In $inputForm.Controls) { If ($control -is [System.Windows.Forms.TextBox]) { [string]$return += "'$($control.Text.Trim())';" }}
                Do { $return = $return.Replace(';;',';').Replace("''","") } While ( $return.IndexOf(';;') -gt -1 )
                Return "($($return.Trim(';').Replace(';', '; ')))"
            }
            'TEXT'  {
                Return "'$($textBox.Text.Trim())'"
            }
            Default {
                Return "Invalid return type: $Type"
            }
        }
    }
    ElseIf ($result -eq [System.Windows.Forms.DialogResult]::Cancel) { Return '!!-CANCELED-!!' }
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
#region FORM STARTUP / SHUTDOWN CODE
    $InitialFormWindowState    = New-Object 'System.Windows.Forms.FormWindowState'
    $MainFORM_StateCorrection_Load = { $MainFORM.WindowState = $InitialFormWindowState }

    $MainFORM_Load = {
        # Change font to a nicer one
        ForEach ($control In $MainFORM.Controls) { $control.Font = $sysFont }
    }

    $MainFORM_FormClosing = [System.Windows.Forms.FormClosingEventHandler] {
        $quit = [System.Windows.Forms.MessageBox]::Show($MainFORM, 'Are you sure you want to exit this form.?', ' Quit', 'YesNo', 'Question')
        If ($quit -eq 'No') { $_.Cancel = $True }
    }

    $MainFORM_Cleanup_FormClosed = {
        $btn_t1_Search.Remove_Click($btn_t1_Search_Click)
        $btn_t1_Import.Remove_Click($btn_t1_Import_Click)

        $btn_t4_Save.Remove_Click($btn_t4_Save_Click)
        $btn_t4_Generate.Remove_Click($btn_t4_Generate_Click)

        Try {
            $sysFont.Dispose()
            $sysFontBold.Dispose()
            $sysFontItalic.Dispose()
        } Catch {}

        $MainFORM.Remove_FormClosing($MainFORM_FormClosing)
        $MainFORM.Remove_Load($MainFORM_Load)
        $MainFORM.Remove_Load($MainFORM_StateCorrection_Load)
        $MainFORM.Remove_FormClosed($MainFORM_Cleanup_FormClosed)
    }
#endregion
###################################################################################################
#region FORM Scripts
    Function Update-SelectedCount
    {
        [int]$iCnt = 0
        ForEach ($item In $lst_t2_SelectChecks.Items) { If ($item.Checked -eq $True) { $iCnt++ } }
        $lbl_t2_SelectedCount.Text = "$iCnt of $($lst_t2_SelectChecks.Items.Count) selected"
    }

    Function ListView_DoubleClick ( [System.Windows.Forms.ListView]$SourceControl )
    {
        If ([string]::IsNullOrEmpty(($SourceControl.SelectedItems[0].Text).Trim()) -eq $True) { Return }

        # Start EDIT for selected item
        Try { [System.Windows.Forms.ListViewItem]$selectedItem = $($SourceControl.SelectedItems[0]) } Catch { }

        [string]$returnValue = '!ERROR!'
        Switch -Wildcard ($($selectedItem.SubItems[2].Text))
        {
            'LIST'   { $returnValue = (InputBoxFORM -Type 'LIST' -Title $($selectedItem.SubItems[0].Text) -Instruction $($selectedItem.SubItems[0].Text) -SelectedValue $($selectedItem.SubItems[1].Text)                       ); Break }
            Default  { $returnValue = (InputBoxFORM -Type 'TEXT' -Title $($selectedItem.SubItems[0].Text) -Instruction $($selectedItem.SubItems[0].Text) -SelectedValue $($selectedItem.SubItems[1].Text)                       ); Break }
        }
        If ($returnValue -ne '!!-CANCELED-!!') { $SourceControl.SelectedItems[0].SubItems[1].Text = $returnValue }
    }

    $btn_t1_Search_Click = {
        # Search location and read in scripts
        $btn_t1_Search.Enabled       = $False
        $btn_t1_Import.Enabled       = $False
        $cmo_t1_Language.Enabled     = $False
        $cmo_t1_SettingsFile.Enabled = $False
        
        [string]$InitialDirectory = "$script:ExecutionFolder"
        $script:scriptLocation = (Get-Folder -Description 'Select the QA checks root folder:' -InitialDirectory $InitialDirectory -ShowNewFolderButton $False)
        If ([string]::IsNullOrEmpty($script:scriptLocation) -eq $True) { $btn_t1_Search.Enabled = $True; Return }
        If ($script:scriptLocation.EndsWith('\scripts')) { $script:scriptLocation = $script:scriptLocation.TrimEnd('\scripts') }

        $btn_t1_Search.Enabled       = $True
        $btn_t1_Import.Enabled       = $True
        $cmo_t1_Language.Enabled     = $True
        $cmo_t1_SettingsFile.Enabled = $True
        $btn_t1_Import.Focus()

        # Get list of languages
        [string[]]$langList = (Get-ChildItem -Path "$script:scriptLocation\i18n" -Filter '*_text.ps1' | Select-Object -ExpandProperty Name | Sort-Object Name)
        Load-ComboBox -ComboBox $cmo_t1_Language -Items ($langList | Sort-Object Name) -SelectedItem 'en-gb_text.ps1' -Clear

        # Get list of custom settings
        [string[]]$settingList = (Get-ChildItem -Path "$script:scriptLocation\settings" -Filter '*.ini' | Select-Object -ExpandProperty Name | Sort-Object Name)
        Load-ComboBox -ComboBox $cmo_t1_SettingsFile -Items ($settingList | Sort-Object Name) -SelectedItem 'default-settings.ini' -Clear
    }

    $btn_t1_Import_Click = {
        [System.Globalization.TextInfo]$TextInfo = (Get-Culture).TextInfo
        $languageINI = (Load-IniFile -Inputfile "$script:scriptLocation\i18n\$($cmo_t1_Language.Text)")
        $settingsINI = (Load-IniFile -Inputfile "$script:scriptLocation\settings\$($cmo_t1_SettingsFile.Text)")

        If ((Test-Path -Path "$script:scriptLocation\i18n\$(($cmo_t1_Language.Text).Replace('_text','_help'))") -eq $True)
        {
            # Load language specific descriptions
            $descINI = (Load-IniFile -Inputfile "$script:scriptLocation\i18n\$(($cmo_t1_Language.Text).Replace('_text','_help'))")
        }
        Else
        {
            # Fall back to EN-GB descriptions
            $descINI = (Load-IniFile -Inputfile "$script:scriptLocation\i18n\en-gb_help.ps1")
        }

        $lbl_t1_ScanningScripts.Visible = $True
        $lbl_t1_ScanningScripts.Text    = 'Scanning Check Location: '
        $txt_t1_Location.Text           = "$script:scriptLocation\checks"
        $txt_t4_ShortCode.Text          = ($settingsINI.settings.shortcode)
        $txt_t4_ReportTitle.Text        = ($settingsINI.settings.reportCompanyName)
        $txt_t1_Location.Refresh()
        $tab_t3_Pages.TabPages.Clear()
        $lst_t2_SelectChecks.Items.Clear()
        $lst_t2_SelectChecks.Groups.Clear()

        [object[]]$folders = (Get-ChildItem -Path "$script:scriptLocation\checks" | Where-Object { $_.PsIsContainer -eq $True } | Select-Object -ExpandProperty Name | Sort-Object Name )
        ForEach ($folder In ($folders | Sort-Object Name))
        {
            $folder = $($TextInfo.ToTitleCase($folder))
            $lbl_t1_ScanningScripts.Text = "Scanning script folder: $($folder.ToUpper())"
            $lbl_t1_ScanningScripts.Refresh(); [System.Windows.Forms.Application]::DoEvents()

            # Add TabPage for folder and create a ListView item
            $newTab = New-Object 'System.Windows.Forms.TabPage'
            $newTab.Text = $folder
            $newTab.Name = "tab_$folder"
            $newTab.Tag  = "tab_$folder"
            $newTab.Font = $sysFont
            $tab_t3_Pages.TabPages.Add($newTab)

            # lst_t3_EnterDetails
            $newLVW = New-Object 'System.Windows.Forms.ListView'
            $newLVW.Name           = "lvw_$folder"
            $newLVW.HeaderStyle    = 'Nonclickable'
            $newLVW.FullRowSelect  = $True
            $newLVW.GridLines      = $False
            $newLVW.LabelWrap      = $False
            $newLVW.MultiSelect    = $False
            $newLVW.Location       = '  3,  3'
            $newLVW.Size           = '730, 498'
            $newLVW.View           = 'Details'
            $newLVW.Font           = $sysFont
            $newLVW.SmallImageList = $img_ListImages
            $newLVW_CH_Name  = New-Object 'System.Windows.Forms.ColumnHeader'; $newLVW_CH_Name.Text  = 'Check'; $newLVW_CH_Name.Width  = 225
            $newLVW_CH_Value = New-Object 'System.Windows.Forms.ColumnHeader'; $newLVW_CH_Value.Text = 'Value'; $newLVW_CH_Value.Width = 519 - ([System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth + 4)
            $newLVW_CH_Type  = New-Object 'System.Windows.Forms.ColumnHeader'; $newLVW_CH_Type.Text  = ''     ; $newLVW_CH_Type.Width  =   0
            $newLVW.Columns.Add($newLVW_CH_Name)  | Out-Null
            $newLVW.Columns.Add($newLVW_CH_Value) | Out-Null
            $newLVW.Columns.Add($newLVW_CH_Type)  | Out-Null
            $newLVW.Add_KeyPress( { If ($_.KeyChar -eq 13) { ListView_DoubleClick -SourceControl $this } } )
            $newLVW.Add_DoubleClick(                       { ListView_DoubleClick -SourceControl $this }   )
            $newTab.Controls.Add($newLVW)

            [string]$guid = ([guid]::NewGuid() -as [string]).Split('-')[0]
            $lst_t2_SelectChecks.Groups.Add($(New-Object 'System.Windows.Forms.ListViewGroup' ("$guid", " $folder"))) | Out-Null

            [object[]]$scripts = (Get-ChildItem -Path "$script:scriptLocation\checks\$folder" -Filter 'c-*.ps1' | Select-Object -ExpandProperty Name | Sort-Object Name )
            ForEach ($script In ($scripts | Sort-Object Name))
            {
                [string]  $script    = $script.Replace($script.Split('.')[-1], '').TrimEnd('.')
                [string[]]$content   = (Get-Content -Path ("$script:scriptLocation\checks\$folder\$script.ps1") -TotalCount 16)

                [string]  $checkCode = ($script.Substring(2, 6).Replace('-',''))
                [string]  $checkName = ($languageINI.$($checkCode).Name)
                If ([string]::IsNullOrEmpty($checkName) -eq $True) { $checkName = '*' + $TextInfo.ToTitleCase($(($script.Substring(9)).Replace('-', ' '))) } Else { $checkName = $checkName.Trim("'") }

                $regEx = [RegEx]::Match($content, "DESCRIPTION:((?:.|\s)+?)(?:(?:[A-Z\- ]+:)|(?:#>))")
                [string]  $checkDesc = $regEx.Groups[1].Value.Replace("`r`n", ' ').Replace('  ', '').Trim()

                Add-ListViewItem -ListView $lst_t2_SelectChecks -Items $checkCode -SubItems ($checkName, $checkDesc) -Group $guid -ImageIndex 1
                If ($settingsINI.ContainsKey($checkCode) -eq $true) { $lst_t2_SelectChecks.Items["$checkCode"].Checked = $True }
            }
        }
        Update-SelectedCount

        $lbl_t1_ScanningScripts.Visible = $False
        $btn_t1_Search.Enabled          = $True
        $btn_t1_Import.Enabled          = $True
        $btn_t2_NextPage.Enabled        = $True
        $tab_Pages.SelectedIndex        = 1
        $lst_t2_SelectChecks.Items[0].Selected = $True
    }

    $btn_t2_SelectAll_Click  = { ForEach ($item In $lst_t2_SelectChecks.Items) { $item.Checked = $true                }; Update-SelectedCount }
    $btn_t2_SelectInv_Click  = { ForEach ($item In $lst_t2_SelectChecks.Items) { $item.Checked = (-not $item.Checked) }; Update-SelectedCount }
    $btn_t2_SelectNone_Click = { ForEach ($item In $lst_t2_SelectChecks.Items) { $item.Checked = $false               }; Update-SelectedCount }

    $lst_t2_SelectChecks_ItemChecked          = { Update-SelectedCount }
    $lst_t2_SelectChecks_SelectedIndexChanged = { If ($lst_t2_SelectChecks.SelectedItems.Count -eq 1) { $lbl_t2_Description.Text = ($lst_t2_SelectChecks.SelectedItems[0].SubItems[2].Text) } }

    $btn_t2_NextPage_Click = {
        $tab_Pages.SelectedIndex = 2
        $settingsINI = (Load-IniFile -Inputfile "$script:scriptLocation\settings\$($cmo_t1_SettingsFile.Text)")

        ForEach ($folder In $lst_t2_SelectChecks.Groups)
        {
            # Get correct ListView object
            [System.Windows.Forms.TabPage] $tabObject = $tab_t3_Pages.TabPages["tab_$($folder.Header.Trim())"]
            [System.Windows.Forms.ListView]$lvwObject =    $tabObject.Controls["lvw_$($folder.Header.Trim())"]

            ForEach ($listItem In $folder.Items)
            {
                If ($listItem.Checked -eq $true)
                {
                    # Create group for the checks
                    #[string]$guid = ([guid]::NewGuid() -as [string]).Split('-')[0]
                    [string]$guid = $($listItem.Text)
                    $lvwObject.Groups.Add($(New-Object 'System.Windows.Forms.ListViewGroup' ($guid, " $($listItem.SubItems[1].Text) ($($listItem.Text.ToUpper()))"))) | Out-Null

                    # Create each item
                    ForEach ($item In (($settingsINI.$($listItem.Text).Keys) | Sort-Object))
                    {
                        [string]$value = $($settingsINI.$($listItem.Text).$item)
                        If ($value.StartsWith('(')) { [string]$type = 'LIST' } Else { [string]$type = 'TEXT' }
                        $value = $value.Replace("', '", "'; '").Replace("','", "'; '")
                        Add-ListViewItem -ListView $lvwObject -Items $item -SubItems ($value, $type) -Group $guid -ImageIndex 1
                    }

                    # Add 'spacing' gap between groups
                    #If ($lvwObject.Groups[$guid].Items.Count -gt 0) { Add-ListViewItem -ListView $lvwObject -Items ' ' -Group $guid -ImageIndex -1 }
                }
            }

            # Remove empty pages
            If ($lvwObject.Items.Count -eq 0) { $tab_t3_Pages.TabPages.Remove($tabObject) }
        }

        $btn_t4_Save.Enabled     = $True
    }

    $btn_t4_Save_Click = {
        If (([string]::IsNullOrEmpty($txt_t4_ShortCode.Text) -eq $true) -or ([string]::IsNullOrEmpty($txt_t4_ReportTitle.Text) -eq $true))
        {
            [System.Windows.Forms.MessageBox]::Show($MainFORM, 'Please fill in a "ShortCode" and "ReportTitle" value.', 'Error', 'OK', 'Warning')
            Return
        }

        $script:saveFile = (Save-File -InitialDirectory "$script:ExecutionFolder\settings" -Title 'Save Settings File')
        If ([string]::IsNullOrEmpty($script:saveFile) -eq $True) { Return }

        [System.Text.StringBuilder]$outputFile = ''
        # Write out header information
        $outputFile.AppendLine('[settings]')
        $outputFile.AppendLine("shortcode         = $($txt_t4_ShortCode.Text)")
        $outputFile.AppendLine("language          = $($cmo_t1_Language.Text.Split('_')[0])")
        $outputFile.AppendLine("reportCompanyName = $($txt_t4_ReportTitle.Text)")
        $outputFile.AppendLine('outputLocation    = $env:SystemDrive\QA\Results\')
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
                            If (($item.SubItems[2].Text) -eq 'LIST') { [string]$out = "$(($item.SubItems[1].Text).Replace(';', ','))" }
                            Else                                     { [string]$out = "$($item.SubItems[1].Text)" }
                            $outputFile.AppendLine("$(($item.Text).Trim().PadRight(34)) = $out")
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
    }

    $btn_t4_Generate_Click = {
        $btn_t4_Save.Enabled     = $False
        $btn_t4_Generate.Enabled = $False

        Start-Process -FilePath 'PowerShell.exe' -ArgumentList "$script:ExecutionFolder\compiler.ps1 -Settings $(Split-Path -Path $script:saveFile -Leaf)" -Wait
        [System.Windows.Forms.MessageBox]::Show($MainFORM, "Custom QA Script generated", 'Generate QA Script', 'OK', 'Information') 

        $btn_t4_Save.Enabled     = $True
        $btn_t4_Generate.Enabled = $True
    }
#endregion
###################################################################################################
#region FORM ITEMS
#region MAIN FORM
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $MainFORM                    = New-Object 'System.Windows.Forms.Form'
    $img_ListImages              = New-Object 'System.Windows.Forms.ImageList'
    $img_Input                   = New-Object 'System.Windows.Forms.ImageList'
    $tab_Pages                   = New-Object 'System.Windows.Forms.TabControl'
    $tab_Page1                   = New-Object 'System.Windows.Forms.TabPage'
    $tab_Page2                   = New-Object 'System.Windows.Forms.TabPage'
    $tab_Page3                   = New-Object 'System.Windows.Forms.TabPage'
    $tab_Page4                   = New-Object 'System.Windows.Forms.TabPage'
    $btn_Help                    = New-Object 'System.Windows.Forms.Button'
    $btn_Cancel                  = New-Object 'System.Windows.Forms.Button'

    # TAB 1
    $lbl_t1_Welcome               = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_Introduction          = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_ScanningScripts       = New-Object 'System.Windows.Forms.Label'
    $txt_t1_Location              = New-Object 'System.Windows.Forms.TextBox'
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
    $MainFORM.CancelButton        = $btn_Cancel
    $MainFORM.Add_Load($MainFORM_Load)
    $MainFORM.Add_FormClosing($MainFORM_FormClosing)

    $tab_Pages.Location      = '12, 12'
    $tab_Pages.SelectedIndex = 0
    $tab_Pages.Size          = '770, 608'
    $tab_Pages.TabIndex      = 0
    $tab_Pages.Padding       = '12, 6'
    $tab_Pages.Controls.Add($tab_Page1)    # Select Location / Import
    $tab_Pages.Controls.Add($tab_Page2)    # Select QA Checks
    $tab_Pages.Controls.Add($tab_Page3)    # Enter Values for QA checks
    $tab_Pages.Controls.Add($tab_Page4)    # Compile
    $tab_Pages.Add_SelectedIndexChanged($tab_Pages_SelectedIndexChanged)
    $MainFORM.Controls.Add($tab_Pages)

    # tabpage1
    $tab_Page1.Text      = 'Introduction'
    $tab_Page1.TabIndex  = 0
    $tab_Page1.BackColor = 'Control'

    # tabpage2
    $tab_Page2.Text      = 'Select Checks'
    $tab_Page2.TabIndex  = 1
    $tab_Page2.BackColor = 'Control'

    # tabpage3
    $tab_Page3.Text      = 'Check Details'
    $tab_Page3.TabIndex  = 2
    $tab_Page3.BackColor = 'Control'

    # tabpage4
    $tab_Page4.Text      = 'Generate QA'
    $tab_Page4.TabIndex  = 3
    $tab_Page4.BackColor = 'Control'
#endregion
#region TAB 1 - Introduction / Select Location / Import
    # lbl_t1_Welcome
    $lbl_t1_Welcome.Font      = $sysFontBold
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
Please read the documention to help fill in this form.


This form will help you create custom settings file for the QA checks.  This settings file is used to make the QA checks specific to your environments.  As many settings files can be created as needed.
"@
    $tab_Page1.Controls.Add($lbl_t1_Introduction)

    # btn_t1_Search
    $btn_t1_Search.Location = '306, 325'
    $btn_t1_Search.Size     = '150, 35'
    $btn_t1_Search.Text     = 'Set Check Location'
    $btn_t1_Search.TabIndex = 0
    $btn_t1_Search.Add_Click($btn_t1_Search_Click)
    $tab_Page1.Controls.Add($btn_t1_Search)

    # lbl_t1_Language
    $lbl_t1_Language.Location  = '  9, 387'
    $lbl_t1_Language.Size      = '291,  21'
    $lbl_t1_Language.Text      = 'Language :'
    $lbl_t1_Language.TextAlign = 'MiddleRight'
    $tab_Page1.Controls.Add($lbl_t1_Language)

    # cmo_t1_Language
    $cmo_t1_Language.Location      = '306, 387'
    $cmo_t1_Language.Size          = '150,  21'
    $cmo_t1_Language.DropDownStyle = 'DropDownList'
    $cmo_t1_Language.Enabled       = $False
    $cmo_t1_Language.TabIndex      = 1
    $tab_Page1.Controls.Add($cmo_t1_Language)
    
    # lbl_t1_SettingsFile
    $lbl_t1_SettingsFile.Location  = '  9, 423'
    $lbl_t1_SettingsFile.Size      = '291,  21'
    $lbl_t1_SettingsFile.Text      = 'Base Settings File :'
    $lbl_t1_SettingsFile.TextAlign = 'MiddleRight'
    $tab_Page1.Controls.Add($lbl_t1_SettingsFile)

    # cmo_t1_SettingsFile
    $cmo_t1_SettingsFile.Location      = '306, 423'
    $cmo_t1_SettingsFile.Size          = '150,  21'
    $cmo_t1_SettingsFile.DropDownStyle = 'DropDownList'
    $cmo_t1_SettingsFile.Enabled       = $False
    $cmo_t1_SettingsFile.TabIndex      = 2
    $tab_Page1.Controls.Add($cmo_t1_SettingsFile)

    # btn_t1_Import
    $btn_t1_Import.Location = '306, 471'
    $btn_t1_Import.Size     = '150,  35'
    $btn_t1_Import.Text     = 'Import Settings'
    $btn_t1_Import.Enabled  = $False
    $btn_t1_Import.TabIndex = 3
    $btn_t1_Import.Add_Click($btn_t1_Import_Click)
    $tab_Page1.Controls.Add($btn_t1_Import)

    # lbl_t1_ScanningScripts
    $lbl_t1_ScanningScripts.Location  = '  9, 524'
    $lbl_t1_ScanningScripts.Size      = '744,  20'
    $lbl_t1_ScanningScripts.Text      = ''
    $lbl_t1_ScanningScripts.TextAlign = 'BottomLeft'
    $lbl_t1_ScanningScripts.Visible   = $False
    $tab_Page1.Controls.Add($txt_t1_Location)

    # txt_t1_Location
    $txt_t1_Location.Enabled   = $False
    $txt_t1_Location.Location  = '9, 547'
    $txt_t1_Location.Multiline = $True
    $txt_t1_Location.Size      = '744, 20'
    $txt_t1_Location.TabStop   = $False
    $txt_t1_Location.TextAlign = 'Center'
    $tab_Page1.Controls.Add($lbl_t1_ScanningScripts)
#endregion
#region TAB 2 - Select QA Checkes To Include
    # lbl_t2_ScriptSelection
    $lbl_t2_CheckSelection.Location  = '  9,   9'
    $lbl_t2_CheckSelection.Size      = '744,  20'
    $lbl_t2_CheckSelection.Text      = 'Select which QA checks to enable for this settings file'
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
    $lst_t2_SelectChecks_CH_Desc.Text   = 'Description'
    $lst_t2_SelectChecks_CH_Code.Width  = 100
    $lst_t2_SelectChecks_CH_Name.Width  = 366 - ([System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth + 4)
    $lst_t2_SelectChecks_CH_Desc.Width  =   0
    $lst_t2_SelectChecks.Add_ItemChecked($lst_t2_SelectChecks_ItemChecked)
    $lst_t2_SelectChecks.Add_SelectedIndexChanged($lst_t2_SelectChecks_SelectedIndexChanged)
    $tab_Page2.Controls.Add($lst_t2_SelectChecks)

    # lbl_Description
    $lbl_t2_Description.BackColor   = 'Window'
    $lbl_t2_Description.Location    = '475,  36'
    $lbl_t2_Description.Size        = '277, 490'
    $lbl_t2_Description.Padding     = '3, 3, 3, 3'
    $lbl_t2_Description.Text        = ''
    $lbl_t2_Description.TextAlign   = 'TopLeft'
    $tab_Page2.Controls.Add($lbl_t2_Description)

    # lbl_t2_SelectedCount
    $lbl_t2_SelectedCount.Location  = '  9, 542'
    $lbl_t2_SelectedCount.Size      = '227,  25'
    $lbl_t2_SelectedCount.Text      = '0 of 0 selected :'
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
    $btn_t2_SelectAll.Add_Click($btn_t2_SelectAll_Click)
    $tab_Page2.Controls.Add($btn_t2_SelectAll)

    # btn_t2_SelectAll
    $btn_t2_SelectInv.Location = '354, 542'
    $btn_t2_SelectInv.Size     = ' 50,  25'
    $btn_t2_SelectInv.Text     = 'Invert'
    $btn_t2_SelectInv.Add_Click($btn_t2_SelectInv_Click)
    $tab_Page2.Controls.Add($btn_t2_SelectInv)

    # btn_t2_SelectAll
    $btn_t2_SelectNone.Location = '410, 542'
    $btn_t2_SelectNone.Size     = ' 50,  25'
    $btn_t2_SelectNone.Text     = 'None'
    $btn_t2_SelectNone.Add_Click($btn_t2_SelectNone_Click)
    $tab_Page2.Controls.Add($btn_t2_SelectNone)

    # btn_t2_NextPage
    $btn_t2_NextPage.Location = '678, 542'
    $btn_t2_NextPage.Size     = ' 75,  25'
    $btn_t2_NextPage.Text     = 'Next  >'
    $btn_t2_NextPage.Enabled  = $False
    $btn_t2_NextPage.Add_Click($btn_t2_NextPage_Click)
    $tab_Page2.Controls.Add($btn_t2_NextPage)

    # pic_Background
    $pic_t2_Background.Location    = '474,  35'
    $pic_t2_Background.Size        = '279, 492'
    $pic_t2_Background.BackColor   = 'Window'
    $pic_t2_Background.BorderStyle = 'FixedSingle'
    $pic_t2_Background.SendToBack()
    $tab_Page2.Controls.Add($pic_t2_Background)

#endregion
#region TAB 3 - Enter Values For Checks
    # lbl_t3_ScriptSelection
    $lbl_t3_ScriptSelection.Location  = '  9,   9'
    $lbl_t3_ScriptSelection.Size      = '744,  20'
    $lbl_t3_ScriptSelection.Text      = 'Enter settings for each check'
    $lbl_t3_ScriptSelection.TextAlign = 'BottomLeft'
    $tab_Page3.Controls.Add($lbl_t3_ScriptSelection)

    # tab_t3_Pages
    $tab_t3_Pages.Location      = '  9,  35'
    $tab_t3_Pages.Size          = '744, 532'
    $tab_t3_Pages.Padding       = '8, 4'
    $tab_t3_Pages.SelectedIndex = 0
    $tab_Page3.Controls.Add($tab_t3_Pages)
#endregion
#region TAB 4 - Generate Settings And QA Script
    # lbl_t1_Welcome
    $lbl_t4_Complete.Font      = $sysFontBold
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
    # btn_Cancel
    $btn_Cancel.Location = '707, 635'
    $btn_Cancel.Size     = '75, 25'
    $btn_Cancel.TabIndex = 98
    $btn_Cancel.Text     = 'Cancel'
    $btn_Cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel    # Use this instead of a "Click" event
    $MainFORM.Controls.Add($btn_Cancel)

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
#region FORM STARTUP / SHUTDOWN
    $InitialFormWindowState        = New-Object 'System.Windows.Forms.FormWindowState'
    $MainFORM_StateCorrection_Load = { $MainForm.WindowState = $InitialFormWindowState }

    $MainForm_Load = {
        # Change font to a nicer one
        ForEach ($control In $MainForm.Controls) { $control.Font = $sysFont }
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
        $lst_t2_SelectChecks.RemoveF_ItemChecked($lst_t2_SelectChecks_ItemChecked)
        $lst_t2_SelectChecks.Remove_SelectedIndexChanged($lst_t2_SelectChecks_SelectedIndexChanged)

        $tab_Pages
        Try {
            $sysFont.Dispose()
            $sysFontBold.Dispose()
            $sysFontItalic.Dispose()
        } Catch {}

        $MainFORM.Remove_FormClosing($MainFORM_FormClosing)
        $MainFORM.Remove_Load($MainFORM_Load)
        $MainFORM.Remove_Load($MainFORM_StateCorrection_Load)
        $MainFORM.Remove_FormClosed($MainFORM_Cleanup_FormClosed)
    }
#endregion
    $InitialFormWindowState = $MainFORM.WindowState
    $MainFORM.Add_Load($MainFORM_StateCorrection_Load)
    $MainFORM.Add_FormClosed($MainFORM_Cleanup_FormClosed)
    Return $MainFORM.ShowDialog()
}
###################################################################################################
        [string]$script:saveFile        = ''
Try   { [string]$script:ExecutionFolder = (Split-Path -Path ((Get-Variable MyInvocation -ValueOnly -ErrorAction SilentlyContinue).MyCommand.Path) -ErrorAction SilentlyContinue) }
Catch { [string]$script:ExecutionFolder = '' }
###################################################################################################
Display-MainForm | Out-Null