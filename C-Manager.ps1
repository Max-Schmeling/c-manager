# ####################################################
#
# Name:                     C-Manager
# Creator:                  Max Schmeling
# Version:                  3.6
# Start Date of Project:    2018-11-16
# Release Date of Version:  2019-01-26
# Deprecation Date:         2020-05-18
#
# ####################################################

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net
#Add-Type -AssemblyName System.IO.Compression.FileSystem
#Add-Type -AssemblyName PresentationFramework # for Windows Msgbox (not used due to bug. Alternative is System.Windows.Forms.Messagebox)
[System.Windows.Forms.Application]::EnableVisualStyles()

# Constants:
$VERSION = "3.6"
$FILENAME = "C-Manager.exe" # needs to be identical with this script's name
$TEMPNAME = $FILENAME + ".tmp" # replacement name for updates
$LATESTVERSION_LINK = $WEBSITE_LINK + "/checkversion.php"
$INVALIDS = "*",":",";","\","/","?","<",">",",","ä","ö","ü","|","´",'"' # Invalid characters in file/foldernames
$CWD = (Get-Item -Path ".\").FullName
$MYPATH = Join-Path -Path $CWD -ChildPath $FILENAME

$TEMP = $env:TEMP
$APPDATA = $env:APPDATA
$CONFIGFILE = "settings.ini"
$CONFIGDIR = "$($APPDATA)\ProMan"
$CONFIGPATH = Join-Path -Path $CONFIGDIR -ChildPath $CONFIGFILE
$USERNAME_IDENTIFIER = "username" # the name used in the configfile to identify the username
$COMPILERDIR_IDENTIFIER = "compilerdir"
$EDITORLAUNCHER_IDENTIFIER = "editorlauncher"
$INFOCOMMENT_IDENTIFIER = "infocomment"
$CODETEMPLATE_IDENTIFIER = "codetemplate"
$CLOSEONCREATION_IDENTIFIER = "closeoncreate"
$EDITORPATH_IDENTIFIER = "editorpath"
$SOURCEFILE_EXTENSION = ".c"

# Variables:
$nameofuser = ""
$compilerdir = ""
$editorpath = ""
$fontfam = "Segoe UI" #Microsoft Sans Serif #Segoe UI
$fontsize = "9"
$font = "$($fontfam),$($fontsize)" #'Segoe UI,9'
$entryfont = "$($fontfam),10"


# Delete *.tmp file if it exists in CWD. This is cleanup for update
if (Test-Path $TEMPNAME -PathType Leaf) {
    Remove-Item -Path $TEMPNAME -Force
}


Function ClearAllEntryFields () {
    $entry_foldername.Clear()
    $entry_filename.Clear()
    $combo_filetemplate.SelectedIndex = 0
    $entry_foldername.Focus()
}

Function PopulateFileTemplates() {
    # Populate filetemplate combobox with all existing c files sorted by last-write-time
    $combo_filetemplate.Items.Clear()
    [void]$combo_filetemplate.Items.Add("Choose File")
    $templatefiles = @()
    Get-ChildItem -Recurse -Depth 3 -Filter *.c | Sort-Object LastWriteTime -Descending | ForEach-Object {
        $templatefiles += ,@($_.FullName, $_.Name)
        [void]$combo_filetemplate.Items.Add($_.Name)
    }
    $combo_filetemplate.SelectedIndex = 0
    return $templatefiles
}



Function CheckForUpdateDialog() {
    start $LATESTVERSION_LINK
}


Function CheckForUpdateDialog2() {
    # Compares current version with latest version
    # and downloads and installs the new version
    # there is one available and the user chooses
    # to.
    # Problem: Does not work with VPN tunneled labtops
    # like the telekom-labtops. Thats why we use an
    # alternative function: CheckForUpdateDialog()
    $webClient = New-Object System.Net.WebClient
    try {
        $response = $webClient.DownloadString($LATESTVERSION_LINK)
    } catch {
        $reponse = $null
    }

    if ($response -ne $null) {
        $data = $response.Split(" ", 2)
        $newversion = $data[0]
        $newversionRaw = $newversion.replace(".", "")
        $file = $data[1]
        $downloadUrl = $WEBSITE_LINK + "/" + $file
        $outDir = Join-Path -Path $TEMP -ChildPath "cmanager_updater"
        $outFile = "update_" + $newversion + ".zip"
        $outPath = Join-Path -Path $outDir -ChildPath $outFile

        # Check if retrieved version is newer than THIS one. If yes prompt for update installation
        if ($newversionRaw -gt $VERSION.replace(".", "")) {
            $confirmupdate = [System.Windows.Forms.MessageBox]::Show("Version " + $newversion +  " is available. Would you like to download it now?",'Update available','YesNoCancel','Question')
            if ($confirmupdate -eq 'Yes') {
                start "$downloadUrl"
            }
            return

            # Further impementation of autoupdater
            $confirmupdate = [System.Windows.Forms.MessageBox]::Show("Version " + $newversion +  " is available. Would you like to install it now?",'Update Ready for Installation','YesNoCancel','Question')
            if ($confirmupdate -eq 'No') {
                return
            }

            # Create temp folder
            if (-Not (Test-Path $outDir)) {
                New-Item -ItemType Directory -Path $outDir -Force
            } else {
                Remove-Item -Path $outDir -Recurse -Force
                New-Item -ItemType Directory -Path $outDir -Force
            }

            # Download file
            try {
                $webClient.DownloadFile($downloadUrl, $outPath)
            } catch {
                [System.Windows.Forms.MessageBox]::Show("An error ocurred during download of the update. Update failed.","Error",'OK','Error')
                return
            }

            if (-not (Test-Path -Path $outPath)) {
                [System.Windows.Forms.MessageBox]::Show("Downloaded file not found. Update failed.","Error",'OK','Error')
                return
            }

            # Extract zip
            $extract_folder = "extracted_v" + $newversion
            $extract_path = Join-Path -Path $outDir -ChildPath $extract_folder
            Expand-Archive -Path $outPath -DestinationPath $extract_path

            # Rename THIS file to *.tmp so we can replace it with the new version
            Rename-Item -Path $MYPATH -NewName $TEMPNAME

            # Move new file into CWD
            $tempfilepath = (Get-ChildItem $extract_path -Filter *.exe | Select-Object -First 1).FullName
            $newfilepath = Join-Path -Path $CWD -ChildPath "C-Manager.exe"
            Move-Item -Path $tempfilepath -Destination $newfilepath

            # Clean Up temp dir
            if (Test-Path $outDir) {
                Remove-Item -Path $outDir -Recurse -Force
            }

            [System.Windows.Forms.MessageBox]::Show("Update installed. The app will close itself now. The $($TEMPNAME)-file will disappear as soon as you launch the new version. If it remains you can delete it.","Done",'OK','Information')
            $main_frame.Close()

        } else {
            [System.Windows.Forms.MessageBox]::Show("No update available. You are up-to-date!","No Update",'OK','Information')
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Could not fetch update information. Fix incoming...!","I know I know",'OK','Error')
    }
}


Function ShowCredits {
    # About Form Objects
    $aboutForm          = New-Object System.Windows.Forms.Form
    $aboutFormExit      = New-Object System.Windows.Forms.Button
    $aboutFormText1     = New-Object System.Windows.Forms.Label
    $aboutFormText2     = New-Object System.Windows.Forms.Label
    $aboutFormText3     = New-Object System.Windows.Forms.Label
 
    # About Form
    $aboutForm.AcceptButton  = $aboutFormExit
    $aboutForm.CancelButton  = $aboutFormExit
    $aboutForm.ClientSize    = "500, 145"
    $aboutForm.ControlBox    = $false
    $aboutForm.ShowInTaskBar = $false
    $aboutForm.StartPosition = "CenterParent"
    $aboutForm.Text          = "Credits"
    $aboutForm.TopMost              = $true
    $aboutForm.FormBorderStyle      = "FixedDialog"
 
    # About Name Label
    $aboutFormText1.Font     = New-Object Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    $aboutFormText1.Location = "0, 20"
    $aboutFormText1.Size     = "500, 18"
    $aboutFormText1.Text     = "C - Manager v" + $VERSION
    $aboutFormText1.TextAlign= "MiddleCenter"
    $aboutForm.Controls.Add($aboutFormText1)

    # About Description Label
    $aboutFormText2.Font     = New-Object Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Italic)
    $aboutFormText2.Location = "0, 50"
    $aboutFormText2.Size     = "500, 18"
    $aboutFormText2.Text     = '"A lightweight tool geared towards improving programming workflow."'
    $aboutFormText2.TextAlign= "MiddleCenter"
    $aboutForm.Controls.Add($aboutFormText2)
 
    # About Text Label
    $aboutFormText3.Location = "0, 70"
    $aboutFormText3.Size     = "500, 20"
    $aboutFormText3.Text     = "Max Schmeling. All Rights Reserved. 2020"
    $aboutFormText3.TextAlign= "MiddleCenter"
    $aboutForm.Controls.Add($aboutFormText3)
 
    # About Exit Button
    $aboutFormExit.Size     = "120, 30"
    $aboutFormExit.Location = "190, 105"
    $aboutFormExit.Text     = "Thank You"
    $aboutForm.Controls.Add($aboutFormExit)
 
    [void]$aboutForm.ShowDialog()
}



###################### USER-SETTINGS FILE OPERATIONS ######################



Function LoadSettings () {
    # Returns all settings in configfile

    if (-Not (Test-Path $CONFIGPATH)) {
        return $null
    }

    $settings = @()
    $cfgfile = Get-Content $CONFIGPATH
    foreach ($line in $cfgfile) {
        if ($line.Length -gt 0) {
            if ($line.Contains("=")) {
                $pair = $line.Split("=", 2)
                $key = $pair[0]
                $val = $pair[1]
                $settings += ,$pair
            }
        }
    }
    if ($settings.Count -gt 0) {
        return ,$settings
    } else {
        return @()
    }
}


Function LoadSettingVal ($getkey) {
    # If $getkey is specified returns the value
    # of the given key if it exists.

    if (-Not (Test-Path $CONFIGPATH)) {
        return $null
    }

    $cfgfile = Get-Content $CONFIGPATH
    foreach ($line in $cfgfile) {
        if ($line.Length -gt 0) {
            if ($line.Contains("=")) {
                $pair = $line.Split("=")
                $key = $pair[0]
                $val = $pair[1]
                if ($key -eq $getkey) {
                    if ($val.Length -ge 1) {
                        return $val
                    }
                }
            }
        }
    }
    return $null
}


Function WriteSettings ($key, $val) {
    # Updates or appends a key-value pair
    # in the configfile. If the file does not
    # exist create it.

    if (-Not (Test-Path $CONFIGPATH)) {
        New-Item -ItemType Directory -Path $CONFIGDIR -Force
    }

    if (-Not (Test-Path $CONFIGPATH)) {
        New-Item -ItemType File -Path $CONFIGPATH -Force
    }

    $result = LoadSettingVal $key
    if ($null -eq $result) {
        # The key does not exist yet. So we create it
        "`r`n$($key)=$($val)" | Out-File $CONFIGPATH -Encoding ascii -ErrorAction SilentlyContinue -Append
    } else {
        # The key exists already so we upate its value
        $settings = LoadSettings
        $newsettings = @()
        foreach ($pair in $settings) {
        #Write-Host Pair: $pair
            if ($pair[0] -eq $key) {
                $newsettings += ,($key, $val)
            } else {
                $newsettings += ,$pair
            }
        }
        # Clear config file content
        Clear-Content $CONFIGPATH -Force

        # Write updated settings to it
        foreach ($pair in $newsettings) {
            "`r`n$($pair[0])=$($pair[1])" | Out-File $CONFIGPATH -Encoding ascii -ErrorAction SilentlyContinue -Append
        }
    }
}



###################### CHOOSE COMPILER DIRECTORY ######################



Function DirChooseDialog ($startvalue) {
    # Let user choose the compiler directory
    $browsedir = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($startvalue -ne $null) {
        $browsedir.SelectedPath = $startvalue
    } else {
        $browsedir.SelectedPath = "."
    }
    $browsedir.ShowNewFolderButton = $false
    $browsedir.Description = "Choose your GCC-compiler directory"

    $browsedir.ShowDialog() | Out-Null
    $browsedir.Dispose()
    return $browsedir.SelectedPath
}


Function ShowCompilerdirDialog ($startvalue) {
    $namedialog = New-Object System.Windows.Forms.Form
    $entry_compilerdir = New-Object system.Windows.Forms.TextBox
    $button_dirchoose = New-Object System.Windows.Forms.Button
    $button_confirmname = New-Object System.Windows.Forms.Button
    $button_cancel = New-Object System.Windows.Forms.Button
    $label_info = New-Object system.Windows.Forms.Label

    $namedialog.ClientSize    = "470, 110"
    $namedialog.ControlBox    = $false
    $namedialog.ShowInTaskBar = $false
    $namedialog.StartPosition = "CenterParent"
    $namedialog.Text          = "Choose Compiler Directory"
    $namedialog.TopMost       = $false
    $namedialog.FormBorderStyle = "FixedDialog"

    $label_info.text           = "Choose the installation (i.e. \bin) directory of your GCC-Compiler:"
    $label_info.AutoSize       = $true
    $label_info.width          = 200
    $label_info.height         = 10
    $label_info.location       = New-Object System.Drawing.Point(5,15)
    $label_info.Font           = $font

    $entry_compilerdir.multiline        = $false
    $entry_compilerdir.width            = 415
    $entry_compilerdir.height           = 20
    $entry_compilerdir.location         = New-Object System.Drawing.Point(5,40)
    $entry_compilerdir.Font             = $entryfont
    if ($startvalue -ne $null) {
        $entry_compilerdir.text = $startvalue
    }
    $entry_compilerdir.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        if ($entry_compilerdir.text.Length -gt 0) {
            if (Test-Path -Path $entry_compilerdir.text) {
                if (Test-Path -Path (Join-Path -Path $entry_compilerdir.text -Childpath "gcc.exe")) {
                    $namedialog.Close()
                } else {
                    [System.Windows.Forms.MessageBox]::Show("The chosen path does not contain the following compiler: gcc.exe",'Wrong Path','OK','Error')
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show("The path could not be found because it does not exist.",'Invalid Path','OK','Error')
            }
        }
    }
    })


    $button_dirchoose            = New-Object system.Windows.Forms.Button
    $button_dirchoose.text       = "..."
    $button_dirchoose.width      = 40
    $button_dirchoose.height     = 27
    $button_dirchoose.location   = New-Object System.Drawing.Point(420,39)
    $button_dirchoose.Font       = "$($fontfam),12"
    #$button_dirchoose.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $button_dirchoose.Add_Click({
        if ($startvalue -ne $null) {
            $directory = DirChooseDialog $startvalue
        } else {
            $directory = DirChooseDialog
        }
        if ($directory.Length -gt 1) {
            $entry_compilerdir.text = $directory
        }
    })

    $button_confirmname            = New-Object system.Windows.Forms.Button
    $button_confirmname.text       = "Confirm"
    $button_confirmname.width      = 225
    $button_confirmname.height     = 30
    $button_confirmname.location   = New-Object System.Drawing.Point(5,70)
    $button_confirmname.Font       = $font
    $button_confirmname.Add_Click({
        if ($entry_compilerdir.text.Length -gt 0) {
            if (Test-Path -Path $entry_compilerdir.text) {
                if (Test-Path -Path (Join-Path -Path $entry_compilerdir.text -Childpath "gcc.exe")) {
                    $namedialog.Close()
                } else {
                    [System.Windows.Forms.MessageBox]::Show("The chosen path does not contain the following compiler: gcc.exe",'Wrong Path','OK','Error')
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show("The path could not be found because it does not exist.",'Invalid Path','OK','Error')
            }
        }
    })

    $button_cancel            = New-Object system.Windows.Forms.Button
    $button_cancel.text       = "Cancel"
    $button_cancel.width      = 225
    $button_cancel.height     = 30
    $button_cancel.location   = New-Object System.Drawing.Point(235,70)
    $button_cancel.Font       = $font
    $button_cancel.Add_Click({
            $entry_compilerdir.text = ""
            $namedialog.Close()})

    $namedialog.Controls.Add($label_info)
    $namedialog.Controls.Add($entry_compilerdir)
    $namedialog.Controls.Add($button_dirchoose)
    $namedialog.Controls.Add($button_confirmname)
    $namedialog.Controls.Add($button_cancel)
    [void]$namedialog.ShowDialog()

    return $entry_compilerdir.text
}


Function GetCompilerDir () {
    ### Tries to get compilerdir form configfile

    $result = LoadSettingVal $COMPILERDIR_IDENTIFIER
    if ($result -is [system.array]) {
        return $null
    }
    return $result
}


Function ChooseCompilerDirectory () {
    ### Prompts user for compilerdirectory until a valid one is given

    $oldcompilerdir = GetCompilerDir
    $statusbar.text = "Requesting compiler directory"
    if ($oldcompilerdir -ne $null) {
        $compdir = ShowCompilerdirDialog($oldcompilerdir)
    } else {
        $compdir = ShowCompilerdirDialog
    }

    if ($compdir -ne "") {
        $compdir = $compdir.Trim()
    } else {
        return $false
    }
    $compilerdir = $compdir

    # Update username in config file
    $statusbar.text = "Saving user settings"
    WriteSettings $COMPILERDIR_IDENTIFIER $compilerdir
    $statusbar.text = "successfully saved compiler directory"
    return $compilerdir
}




###################### CHOOSE CUSTOM EDITOR ######################




Function EditorChooseDialog ($startvalue) {
    # Let user choose their custom editor's filepath
    $browsepathDialog = New-Object System.Windows.Forms.OpenFileDialog
    if ($startvalue -ne $null) {
        $browsepathDialog.initialDirectory = $startvalue
    } else {
        $browsepathDialog.initialDirectory = "."
    }
    $browsepathDialog.filter = "All files (*.*)| *.exe"
    $browsepathDialog.ShowDialog() | Out-Null
    return $browsepathDialog.FileName
}


Function ShowEditorSelectionDialog ($startvalue) {
    $namedialog = New-Object System.Windows.Forms.Form
    $entry_editorpath = New-Object system.Windows.Forms.TextBox
    $button_pathchoose = New-Object System.Windows.Forms.Button
    $button_confirmname = New-Object System.Windows.Forms.Button
    $button_cancel = New-Object System.Windows.Forms.Button
    $label_info = New-Object system.Windows.Forms.Label

    $namedialog.ClientSize    = "470, 110"
    $namedialog.ControlBox    = $false
    $namedialog.ShowInTaskBar = $false
    $namedialog.StartPosition = "CenterParent"
    $namedialog.Text          = "Choose Text Editor"
    $namedialog.TopMost       = $false
    $namedialog.FormBorderStyle = "FixedDialog"

    $label_info.text           = "Choose the text editor you want to write your programs with:"
    $label_info.AutoSize       = $true
    $label_info.width          = 200
    $label_info.height         = 10
    $label_info.location       = New-Object System.Drawing.Point(5,15)
    $label_info.Font           = $font

    $entry_editorpath.multiline        = $false
    $entry_editorpath.width            = 415
    $entry_editorpath.height           = 20
    $entry_editorpath.location         = New-Object System.Drawing.Point(5,40)
    $entry_editorpath.Font             = $entryfont
    if ($startvalue -ne $null) {
        $entry_editorpath.text = $startvalue
    }
    $entry_editorpath.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        if ($entry_editorpath.text.Trim() -eq "") {
            $namedialog.Close()
        } elseif (Test-Path -Path $entry_editorpath.text) {
            $namedialog.Close()
        }
    }
    })


    $button_pathchoose            = New-Object system.Windows.Forms.Button
    $button_pathchoose.text       = "..."
    $button_pathchoose.width      = 40
    $button_pathchoose.height     = 27
    $button_pathchoose.location   = New-Object System.Drawing.Point(420,39)
    $button_pathchoose.Font       = "$($fontfam),12"
    #$button_pathchoose.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $button_pathchoose.Add_Click({
        if ($startvalue -ne $null) {
            $editorpath = EditorChooseDialog $startvalue
        } else {
            $editorpath = EditorChooseDialog
        }
        if ($editorpath.Length -gt 1) {
            $entry_editorpath.text = $editorpath
        }
    })

    $button_confirmname            = New-Object system.Windows.Forms.Button
    $button_confirmname.text       = "Confirm"
    $button_confirmname.width      = 225
    $button_confirmname.height     = 30
    $button_confirmname.location   = New-Object System.Drawing.Point(5,70)
    $button_confirmname.Font       = $font
    $button_confirmname.Add_Click({
        if ($entry_editorpath.text.Trim() -eq "") {
            $namedialog.Close()
        } elseif (Test-Path -Path $entry_editorpath.text) {
            $namedialog.Close()
        }
    })

    $button_cancel            = New-Object system.Windows.Forms.Button
    $button_cancel.text       = "Cancel"
    $button_cancel.width      = 225
    $button_cancel.height     = 30
    $button_cancel.location   = New-Object System.Drawing.Point(235,70)
    $button_cancel.Font       = $font
    $button_cancel.Add_Click({
            $entry_editorpath.text = ""
            $namedialog.Close()})

    $namedialog.Controls.Add($label_info)
    $namedialog.Controls.Add($entry_editorpath)
    $namedialog.Controls.Add($button_pathchoose)
    $namedialog.Controls.Add($button_confirmname)
    $namedialog.Controls.Add($button_cancel)
    [void]$namedialog.ShowDialog()

    return $entry_editorpath.text
}


Function GetEditorPath () {
    ### Tries to get editorpath form configfile

    $result = LoadSettingVal $EDITORPATH_IDENTIFIER
    if ($result -is [system.array]) {
        return $null
    }
    return $result
}


Function ChooseEditorPath () {
    ### Prompts user for editorpath until a valid one is given

    $oldeditorpath = GetEditorPath
    $statusbar.text = "Requesting user custom editor path"
    if (($oldeditorpath -ne $null) -and ($oldeditorpath -ne "none")) {
        $editorpath_ = ShowEditorSelectionDialog($oldeditorpath)
    } else {
        $editorpath_ = ShowEditorSelectionDialog
    }

    if ($editorpath_ -ne "") {
        $editorpath_ = $editorpath_.Trim()
    } else {
        $editorpath_ = "none" # identifier for "no custom editor chosen"
    }
    $editorpath = $editorpath_

    # Update username in config file
    $statusbar.text = "Saving user settings"
    WriteSettings $EDITORPATH_IDENTIFIER $editorpath
    $statusbar.text = "successfully saved editor path"
    return $editorpath
}




###################### CHOOSE USERNAME ######################



Function ShowUsernameDialog ($startvalue) {
    $namedialog = New-Object System.Windows.Forms.Form
    $entry_username = New-Object system.Windows.Forms.TextBox
    $button_confirmname = New-Object System.Windows.Forms.Button
    $button_cancel = New-Object System.Windows.Forms.Button
    $label_info = New-Object system.Windows.Forms.Label

    $namedialog.ClientSize    = "480, 110"
    $namedialog.ControlBox    = $false
    $namedialog.ShowInTaskBar = $false
    $namedialog.StartPosition = "CenterParent"
    $namedialog.Text          = "Set Username"
    $namedialog.TopMost       = $false
    $namedialog.FormBorderStyle = "FixedDialog"

    $label_info.text           = "Enter your name. You will see it in future generated projects:"
    $label_info.AutoSize       = $true
    $label_info.width          = 200
    $label_info.height         = 10
    $label_info.location       = New-Object System.Drawing.Point(5,15)
    $label_info.Font           = $font

    $entry_username.multiline        = $false
    $entry_username.width            = 470
    $entry_username.height           = 20
    $entry_username.location         = New-Object System.Drawing.Point(5,40)
    $entry_username.Font             = $entryfont
    if ($startvalue -ne $null) {
        $entry_username.text = $startvalue
    }
    $entry_username.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        if ($entry_username.text.Length -ge 3) {
            $namedialog.Close()
        }
    }
    })

    $button_confirmname            = New-Object system.Windows.Forms.Button
    $button_confirmname.text       = "Confirm"
    $button_confirmname.width      = 235
    $button_confirmname.height     = 30
    $button_confirmname.location   = New-Object System.Drawing.Point(5,70)
    $button_confirmname.Font       = $font
    $button_confirmname.Add_Click({
            if ($entry_username.text.Length -ge 3) {
                $namedialog.Close()
            }
            })

    $button_cancel            = New-Object system.Windows.Forms.Button
    $button_cancel.text       = "Cancel"
    $button_cancel.width      = 235
    $button_cancel.height     = 30
    $button_cancel.location   = New-Object System.Drawing.Point(240,70)
    $button_cancel.Font       = $font
    $button_cancel.Add_Click({
            $entry_username.text = ""
            $namedialog.Close()})

    $namedialog.Controls.Add($label_info)
    $namedialog.Controls.Add($entry_username)
    $namedialog.Controls.Add($button_confirmname)
    $namedialog.Controls.Add($button_cancel)
    [void]$namedialog.ShowDialog()

    return $entry_username.text
}



Function GetUsername () {
    ### Tries to get username form configfile

    $result = LoadSettingVal $USERNAME_IDENTIFIER
    if ($result -is [system.array]) {
        return $null
    }
    return $result
}


Function SetUsername () {
    ### Prompts user for name input until valid name was found

    $oldusername = GetUsername
    $statusbar.text = "Requesting username"
    if ($oldusername -ne $null) {
        $username = ShowUsernameDialog($oldusername)
    } else {
        $username = ShowUsernameDialog
    }

    if ($username -ne "") {
        $username = $username.Trim()
        $username = (Get-Culture).TextInfo.ToTitleCase($username)
    } else {
        return
    }
    $nameofuser = $username

    # Update username in config file
    $statusbar.text = "Saving user settings"
    WriteSettings $USERNAME_IDENTIFIER $nameofuser
    $statusbar.text = "successfully saved username"
}


Function InitSettings () {
    ### Tries to get user settings from config file and
    ### initializes the widgets (checkboxes, comboboxes)
    ### accordingly.

    $state_editorlauncher = LoadSettingVal $EDITORLAUNCHER_IDENTIFIER
    if ($state_editorlauncher -eq 1) {
        $check_editorlauncher.Checked = $true
    } elseif ($state_editorlauncher -eq 0) {
        $check_editorlauncher.Checked = $false
    }

    $state_infocomment = LoadSettingVal $INFOCOMMENT_IDENTIFIER
    if ($state_infocomment -eq 1) {
        $check_includecomment.Checked = $true
    } elseif ($state_infocomment -eq 0) {
        $check_includecomment.Checked = $false
    }

    $state_closeoncreation = LoadSettingVal $CLOSEONCREATION_IDENTIFIER
    if ($state_closeoncreation -eq 1) {
        $check_closeoncreate.Checked = $true
    } elseif ($state_closeoncreation -eq 0) {
        $check_closeoncreate.Checked = $false
    }

    $state_codetemplate = LoadSettingVal $CODETEMPLATE_IDENTIFIER
    if ($state_codetemplate -ge 0) {
        if ($state_codetemplate -le 5) {
            $combo_defaulttext.SelectedIndex = $state_codetemplate
        }
    }
}

Function onSearch () {
    $filelist.Items.Clear()
    $search_string = $entry_searchterm.Text.ToLower()
    if ($search_string.Length -eq 0) {
        $statusbar.text = "No search string given"
        return
    }

    $statusbar.text = "Scanning files and folders"

    Get-ChildItem -Recurse -Include *.c, *.txt, *.log, *.ini, *.cpp, *.o, *.a, *.json |
        ForEach-Object {
            $filepath = $_.FullName
            $parentname = (Get-Item $filepath).Directory.Name
            if ($parentname -eq $null) {
                $parentname = (Get-Item $filepath).PSDrive.Name + ":"
            } else {
                $parentname = $parentname.ToString()
            }

            
            # Check file content for search string first so that the user gets the $line if available
            $lineno = 0
            $found = $false
            try {
                $Default = [System.Text.Encoding]::Default
                $reader = New-Object -TypeName System.IO.StreamReader($filepath, $Default)
                #$reader = [System.IO.File]::OpenText($filepath)
                while($null -ne ($line = $reader.ReadLine())) {
                    $lineno++
                    if ($line.ToLower().Contains($search_string)) {
                        $listitem = New-Object System.Windows.Forms.ListViewItem($_.Name)
                        $listitem.SubItems.Add($parentname)
                        $listitem.SubItems.Add($lineno)
                        if ($line.Trim().Length -ge 90) {
                            $line = $line.Trim().SubString(0,86) + " ..."
                        }
                        $listitem.SubItems.Add($line.Trim())
                        $listitem.SubItems.Add($filepath)
                        $listitem.Font = $entryfont
                        $filelist.Items.Add($listitem)
                        $counter++
                        $found = $true
                        break
                    }
                }
            } catch {}
            finally {$reader.Close()}
            

            # If search string not found in file content check filename and name of containing folder
            if (-not $found) {
                if ($_.Name.ToLower().Contains($search_string) -or $parentname.ToLower().Contains($search_string)) {
                    $listitem = New-Object System.Windows.Forms.ListViewItem($_.Name)
                    $listitem.SubItems.Add($parentname)
                    $listitem.SubItems.Add("-")
                    $listitem.SubItems.Add("-")
                    $listitem.SubItems.Add($filepath)
                    $listitem.Font = $entryfont
                    $filelist.Items.Add($listitem)
                    $counter++
                }
            }
            $statusbar.text = "Matches Found: $counter"
        }
        <#
    if ($counter > 0) {
        $statusbar.text = "Scanning finished. Found $counter files and folders."
    } else {
        $statusbar.text = "Scanning finished. No matches found."
    }#>
    $filelist.Columns[0].Width = -2
    $filelist.Columns[1].Width = -2
    $filelist.Columns[2].Width = -2
    $filelist.Columns[3].Width = -2
    $filelist.Columns[4].Width = 0
}

Function onCreate ($launcheditornow) {
    $statusbar.text = "Validating user data"
    $foldername = $entry_foldername.Text.Trim()
    $filename = $entry_filename.Text.Trim()
    $codetemplate = $combo_defaulttext.SelectedIndex
    $filetemplate = $combo_filetemplate.SelectedIndex


    # Validate variables
    $varflag = 1 # Keeps track of which variable is currently being validated so we can manipulate the corresponding entry field
    foreach ($var in $foldername,$filename) {
        if ($var.Length -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("You need to specify a file and folder name!",'Usage','OK','Information')
            $entry_foldername.Focus()
            return
        }
        foreach ($char in $var.ToCharArray()) {
            if ($INVALIDS -match [Regex]::Escape($char)) {
                if ($char -eq " ") {
                    [System.Windows.Forms.MessageBox]::Show("Spaces are not allowed in file and folder names","Usage",'OK','Information')
                    # Convert entire string to camel case for convenience
                    $stringarray = $var.ToCharArray()
                    $newstring = ""
                    for ($i = 0; $i -lt $stringarray.Length; $i++) {
                        if ($stringarray[$i] -eq " ") {
                            $newstring += $stringarray[$i + 1].ToString().ToUpper()
                            $i++
                        } else {
                            if ($i -eq 0) {
                                $newstring += $stringarray[$i].ToString().ToUpper()
                            } else {
                                $newstring += $stringarray[$i].ToString().ToLower()
                            }
                        }
                        $index++
                    }

                    if ($varflag -eq 1) { $entry_foldername.Text = $newstring }
                    else { $entry_filename.Text = $newstring }

                } else {
                    [System.Windows.Forms.MessageBox]::Show("Invalid character in name: $($char)",'Information','OK','Warning')
                    # Remove invalid characters from entry box for convenience and replace some characters
                    $newstring = $var.Replace('ö','oe').Replace('ä','ae').Replace('ü','ue').Replace('ß','ss').Replace('Ö','Oe').Replace('Ü','Ue').Replace('Ä','Ae')
                    if ($varflag -eq 1) { $entry_foldername.Text = $newstring }
                    else { $entry_filename.Text = $newstring }
                }
                return
            }
        }
        $varflag++
    }


    # Append ".c" to file if it does not exist already
    if (-Not ($filename.endswith($SOURCEFILE_EXTENSION))) {
        $filename = $filename + $SOURCEFILE_EXTENSION
    }

    # Check for other user errors
    if ($filetemplate -eq 0 -and $codetemplate -eq 4) {
        [System.Windows.Forms.MessageBox]::Show("You chose 'Existing File' as template, but you did not specify the file.",'Error','OK','Error')
        return
    }

    # Validate and initialize User settings
    $statusbar.text = "Validating user settings"

    # Username
    $checkusername = GetUsername
    if ($checkusername -ne $null) {
        if ($checkusername -eq "" -or $checkusername -eq "#noname#") {
            $nameofuser = "anonymous"
        } else {
            $nameofuser = $checkusername
        }
    }

    # Editorpath
    $checkeditorpath = GetEditorPath
    $checkeditorpath = $checkeditorpath
    if ($checkeditorpath -ne $null) {
        if ($checkeditorpath -ne "") {
            if (Test-Path -Path $checkeditorpath) {
                $editorpath = $checkeditorpath
            } else {
                $editorpath = ""
                #$continue = [System.Windows.Forms.MessageBox]::Show("The path of your specified text editor could not be found. This error commonly occurres when the path has been changed outside the C-Manager. Would you still like to create the project?",'Text Editor Not Found','YesNo','Error')
                #if ($continue -eq "No") {
                #    return
                #}
            }
        }
    }

    # Check if user set the compiler directory and prompt them if not.
    # If the user cancels the compiler directory dialog, quit the process
    # because we need the compiler directory
    $checkcompdir = GetCompilerDir
    if ($checkcompdir -ne $null) {
        $compilerdir = $checkcompdir
    } else {
        $success = ChooseCompilerDirectory
        if (-not $success) {
            $statusbar.text = "You need to set the compiler directory first in order to create projects."
        } else {
            $compilerdir = $success
        }
    }

    # Create Folder
    If (-Not (Test-Path -Path $foldername)) {
        New-Item -ItemType Directory -Path $foldername
    } else {
        [System.Windows.Forms.MessageBox]::Show("Folder name already taken!",'Information','OK','Warning')
        $entry_foldername.Clear()
        return
    }

    # Create sourcefile
    $statusbar.text = "Creating sourcefile ($($filename))"
    $relative_filepath = Join-Path -Path $foldername -Childpath $filename
    New-Item -ItemType File -Path $relative_filepath

    # Write default text to sourcefile regarding the user's options
    $statusbar.text = "Writing template to sourcefile"
    if ($codetemplate -ne 5) { # = Not empty file

        if ($codetemplate -eq 4) { # = File as template
            Get-Content -Path $templatefiles[$filetemplate-1][0] | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
        }  else {

            "#include <stdio.h>`r`n`r`n" | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
            
            if ($check_includecomment.Checked) {
                "/*" | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
                " * Name        : " + $filename.TrimEnd($SOURCEFILE_EXTENSION) | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
                " * Synopsis    : " + $description | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
                if ($nameofuser -ne "") {
                    " * Creator     : " + (Get-Culture).TextInfo.ToTitleCase($nameofuser) | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
                }
                " * Date        : " + (Get-Date -Format "yyyy-MM-dd") | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
                " */`r`n`r`n" | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
            }

            switch ($codetemplate) {
                0 {
                    "void main(void)`r`n{" | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
                }

                1 {
                    "int main(void)`r`n{" | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
                    "`treturn 0;" | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
                }

                2 {
                    "void main(int argc, char *argv[])`r`n{" | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
                }

                3 {
                    "int main(int argc, char *argv[])`r`n{" | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
                    "`treturn 0;" | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
                }
            }
            "}" | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
        }
    } else {
        if ($check_includecomment.Checked) {
            "/*" | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
            " * Name        : " + $filename.TrimEnd($SOURCEFILE_EXTENSION) | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
            " * Description : " + $description | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
            if ($nameofuser -ne "") {
                " * Creator     : " + (Get-Culture).TextInfo.ToTitleCase($nameofuser) | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
            }
            " * Date        : " + (Get-Date -Format "yyyy-MM-dd") | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
            " */`r`n`r`n" | Out-File $relative_filepath -Encoding ascii -ErrorAction SilentlyContinue -Append
        }
    }

    # Create gcc2exe.bat (ie. compilebatch)
    $statusbar.text = "Creating compile batch (gcc2exe.bat)"
    $compilebatch = Join-Path -Path $foldername -Childpath "gcc2exe.bat"
    New-Item -ItemType File -Path $compilebatch
    $basename = $filename.Replace(".c", "")

    "@echo off" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    #"chcp 1252" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    "Set PATH=%PATH%;$($compilerdir)" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    "Set FILENAME=$($basename)" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    'gcc.exe "' + "%FILENAME%.c" + '" -o "' + "%~dp0%FILENAME%" + '"' | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    "Set compilestatus=%ERRORLEVEL%" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    "IF %compilestatus% EQU 0 (" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    "echo Compilation successful!" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    'IF not exist "%FILENAME%.exe" echo File' + " '%filename%.exe' not found!" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    'IF exist "%FILENAME%.exe" echo -------------- Launching Executable --------------' | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    'IF exist "%FILENAME%.exe" "%FILENAME%.exe" %*' | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    ")" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    "IF %compilestatus% EQU 0 (" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    #"Set execstatus=%ERRORLEVEL%" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    "echo." | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    "echo ---------------- End of Execution ----------------" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    'IF exist "%FILENAME%.exe" echo Exit Status: %ERRORLEVEL%' | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    "pause" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    ")" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    "IF NOT %compilestatus% EQU 0 (" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    "echo." | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    "echo Error/Warning during compilation or execution process!" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    "echo Press any key to terminate the compiling-assisstant..." | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    "pause >nul" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append
    ")" | Out-File $compilebatch -Encoding ascii -ErrorAction SilentlyContinue -Append

    # Create editor launcher if user chose to
    if ($check_editorlauncher.Checked) {
        $statusbar.text = "Creating editor launcher (Launch Editor.bat)"
        $editorlauncher = (Join-Path -Path $foldername -ChildPath "Launch Editor.bat")
        # Create batch file
        New-Item -ItemType File -Path $editorlauncher
        "@echo off" | Out-File $editorlauncher -Encoding ascii -ErrorAction SilentlyContinue -Append
        #"chcp 1252`r`n" | Out-File $editorlauncher -Encoding ascii -ErrorAction SilentlyContinue -Append
        if ($editorpath -ne "") {
            'start "" "' + $editorpath + '"' + ' "%~dp0' + $filename + '"' | Out-File $editorlauncher -Encoding ascii -ErrorAction SilentlyContinue -Append
        } else {
            if (Test-Path -Path "$($APPDATA)\Downloaded Apps\DALauncher\*\DLStart.exe") {
                'start "" "' + $APPDATA + '\Downloaded Apps\DALauncher\3.0\DLStart.exe" notepad++ ' + '"%~dp0' + $filename + '"' | Out-File $editorlauncher -Encoding ascii -ErrorAction SilentlyContinue -Append
            } else {
                'REM start "" "xyz" "%~dp0' + $filename + '"' | Out-File $editorlauncher -Encoding ascii -ErrorAction SilentlyContinue -Append
                "echo You did not specify a file path in the C-Manager. Right-Click ^>^> Edit this file, remove the 'REM' at the beginning of the line and replace the xyz with your preferred text editor's filepath. This will set the text editor for this project" | Out-File $editorlauncher -Encoding ascii -ErrorAction SilentlyContinue -Append
                "echo If you want to set a text editor for all future projects you need to do so in the C-Manager in the 'Settings'-Tab." | Out-File $editorlauncher -Encoding ascii -ErrorAction SilentlyContinue -Append
                "pause" | Out-File $editorlauncher -Encoding ascii -ErrorAction SilentlyContinue -Append
            }
        }
    }

    # Reset UI after project creation
    ClearAllEntryFields
    $statusbar.text = "Project successfully created"

    # Launch editor if user choosed to
    if ($launcheditornow) {
        if ($editorpath -ne "") {
            start "$editorpath" "$relative_filepath"
        } else {
            if (Test-Path -Path "$($APPDATA)\Downloaded Apps\DALauncher\*\DLStart.exe") {
                start "$APPDATA\Downloaded Apps\DALauncher\*\DLStart.exe" notepad++ "$relative_filepath"
            }
        }
    }

    # Close app if the user check the box
    if ($check_closeoncreate.Checked) {
        $main_frame.Close()
    }
}


$menubar = New-Object System.Windows.Forms.MenuStrip
$menu_settings = New-Object System.Windows.Forms.ToolStripMenuItem
$menu_extras = New-Object System.Windows.Forms.ToolStripMenuItem
$menu_compilerdir = New-Object System.Windows.Forms.ToolStripMenuItem
$menu_setname = New-Object System.Windows.Forms.ToolStripMenuItem
$menu_editorpath = New-Object System.Windows.Forms.ToolStripMenuItem
$menu_reset = New-Object System.Windows.Forms.ToolStripMenuItem
$menu_credits = New-Object System.Windows.Forms.ToolStripMenuItem
$menu_openurl = New-Object System.Windows.Forms.ToolStripMenuItem
$menu_checkupdate = New-Object System.Windows.Forms.ToolStripMenuItem


# "Settings" Menu
[void]$menubar.Items.Add($menu_settings)
$menu_settings.text = "Settings"
$menu_settings.font = $font

# "Compiler chooser" item
$menu_compilerdir.text = "Choose Compiler Directory"
[void]$menu_settings.DropDownItems.Add($menu_compilerdir)
$menu_compilerdir.Add_Click({ChooseCompilerDirectory})

# "Editor chooser" item
$menu_editorpath.text = "Choose Text Editor"
[void]$menu_settings.DropDownItems.Add($menu_editorpath)
$menu_editorpath.Add_Click({ChooseEditorPath})

# "Set name" item
$menu_setname.text = "Set Username"
[void]$menu_settings.DropDownItems.Add($menu_setname)
$menu_setname.Add_Click({SetUsername})

# "Reset all settings" item
$menu_reset.text = "Reset Default Settings"
[void]$menu_settings.DropDownItems.Add($menu_reset)
$menu_reset.Add_Click({
    $confirmdelete = [System.Windows.Forms.MessageBox]::Show("Do you really want to reset the settings to default?",'Confirm Reset','YesNoCancel','Warning')
    if ($confirmdelete -eq 'Yes') {
        if (Test-Path $CONFIGPATH) {
            Remove-Item $CONFIGDIR -Recurse
    }
    }
})


# "Extras" Menu
[void]$menubar.Items.Add($menu_extras)
$menu_extras.text = "Extras"
$menu_extras.font = $font


# "Credits" Item
$menu_credits.text = "Credits"
[void]$menu_extras.DropDownItems.Add($menu_credits)
$menu_credits.Add_Click({ShowCredits})

# "Open Website" Item
$menu_openurl.text = "Open Github"
[void]$menu_extras.DropDownItems.Add($menu_openurl)
$menu_openurl.Add_Click({start "https://github.com/Max-Schmeling"})

<# "Open Website" Item
$menu_checkupdate.text = "Check For Update"
[void]$menu_extras.DropDownItems.Add($menu_checkupdate)
$menu_checkupdate.Add_Click({CheckForUpdateDialog})


# "Check for updates" Item
$menu_checkupdate.text = "Check for Updates"
[void]$menu_extras.DropDownItems.Add($menu_checkupdate)
$menu_checkupdate.Add_Click({CheckForUpdateDialog})
#>


$main_frame                      = New-Object system.Windows.Forms.Form
$main_frame.ClientSize           = '420,480'
$main_frame.text                 = "C - Manager"
$main_frame.TopMost              = $false
$main_frame.FormBorderStyle      = "FixedDialog" #'Fixed3D'
$main_frame.MaximizeBox          = $false
$main_frame.MinimizeBox          = $true
$main_frame.StartPosition       = "CenterScreen"
$main_frame.MainMenuStrip        = $menubar
$main_frame.Add_MouseHover({
    $statusbar.text = ""
})


$group_newproject                = New-Object system.Windows.Forms.Groupbox
$group_newproject.height         = 189
$group_newproject.width          = 400
$group_newproject.Anchor         = 'top,right,left'
$group_newproject.text           = " Create New Project "
$group_newproject.font           = $font
$group_newproject.location       = New-Object System.Drawing.Point(8,33)
$group_newproject.Add_MouseHover({
    $statusbar.text = ""
})

$group_search                    = New-Object system.Windows.Forms.Groupbox
$group_search.height             = 220
$group_search.width              = 400
$group_search.Anchor             = 'top,right,bottom,left'
$group_search.text               = " Search in Projects "
$group_search.font               = $font
$group_search.location           = New-Object System.Drawing.Point(9,230)
$group_search.Add_MouseHover({
    $statusbar.text = ""
})

$label_foldername                = New-Object system.Windows.Forms.Label
$label_foldername.text           = "Folder Name:"
$label_foldername.AutoSize       = $true
$label_foldername.width          = 25
$label_foldername.height         = 10
$label_foldername.location       = New-Object System.Drawing.Point(13,29)
$label_foldername.Font           = $font

$label_filename                  = New-Object system.Windows.Forms.Label
$label_filename.text             = "File Name:"
$label_filename.AutoSize         = $true
$label_filename.width            = 25
$label_filename.height           = 10
$label_filename.location         = New-Object System.Drawing.Point(13,59)
$label_filename.Font             = $font

$entry_foldername                = New-Object system.Windows.Forms.TextBox
$entry_foldername.multiline      = $false
$entry_foldername.width          = 250
$entry_foldername.height         = 20
$entry_foldername.location       = New-Object System.Drawing.Point(140,26)
$entry_foldername.Font           = $entryfont
$entry_foldername.TabStop        = $true
$entry_foldername.TabIndex       = 1
$entry_foldername.Add_MouseHover({
    $statusbar.text = "Enter the name of the project folder"
})

$entry_foldername.Add_KeyDown({
    if ($_.KeyCode -eq "Enter" -and $_.Modifiers -eq "Control") {
        onCreate $true
    } elseif ($_.KeyCode -eq "Enter") {
        $entry_filename.Focus()
    }
})
$entry_foldername.add_Enter({
    if ($entry_foldername.Text.Length -eq 0) {
            $entry_foldername.text = $entry_filename.text
            $entry_foldername.SelectAll()
    }
})

$entry_filename                  = New-Object system.Windows.Forms.TextBox
$entry_filename.multiline        = $false
$entry_filename.width            = 250
$entry_filename.height           = 20
$entry_filename.location         = New-Object System.Drawing.Point(140,56)
$entry_filename.Font             = $entryfont
$entry_filename.TabStop          = $true
$entry_filename.TabIndex         = 2
$entry_filename.Add_MouseHover({
    $statusbar.text = "Enter the name of the project's sourcefile, the actual c-file."
})

$entry_filename.Add_KeyDown({
    if ($_.KeyCode -eq "Enter" -and $_.Modifiers -eq "Control") {
        onCreate $true
    } elseif ($_.KeyCode -eq "Enter") {
        onCreate $true
    }
})
$entry_filename.add_Enter({
    if ($entry_filename.Text.Length -eq 0) {
            $entry_filename.text = $entry_foldername.text
            $entry_filename.SelectAll()
    }
})


$label_defaulttext               = New-Object system.Windows.Forms.Label
$label_defaulttext.text          = "Code Template:"
$label_defaulttext.AutoSize      = $true
$label_defaulttext.width         = 25
$label_defaulttext.height        = 10
$label_defaulttext.location      = New-Object System.Drawing.Point(13,89)
$label_defaulttext.Font          = $font
$label_defaulttext.TabStop       = $false
$label_defaulttext.TabIndex      = 0

$combo_defaulttext               = New-Object system.Windows.Forms.ComboBox
$combo_defaulttext.AutoSize      = $true
$combo_defaulttext.width         = 120
$combo_defaulttext.height        = 10
$combo_defaulttext.location      = New-Object System.Drawing.Point(140,89)
$combo_defaulttext.Font          = $font
$combo_defaulttext.TabStop       = $false
$combo_defaulttext.TabIndex      = 0
$combo_defaulttext.DropDownStyle = "DropDownList"
[void]$combo_defaulttext.Items.Add('void main')
[void]$combo_defaulttext.Items.Add('int main')
[void]$combo_defaulttext.Items.Add('void main + args')
[void]$combo_defaulttext.Items.Add('int main + args')
[void]$combo_defaulttext.Items.Add("Existing File")
[void]$combo_defaulttext.Items.Add("No Template")
$combo_defaulttext.SelectedIndex = 0
$combo_defaulttext.Add_MouseHover({
    $statusbar.text = "Choose the text you will see once you open the sourcefile."
})

# Enable/Disable combo_filetemplate based on selection of combo_defaulttext
$combo_defaulttext.Add_SelectedIndexChanged({
    WriteSettings $CODETEMPLATE_IDENTIFIER $combo_defaulttext.SelectedIndex
    if ($combo_defaulttext.SelectedIndex -eq 4) {
        $combo_filetemplate.Enabled = $true
        $check_includecomment.Enabled = $false
        $combo_filetemplate.Focus()
    } else {
        $combo_filetemplate.SelectedIndex = 0
        $combo_filetemplate.Enabled = $false
        $check_includecomment.Enabled = $true
        $button_createproject.Focus()
    }
})


$combo_filetemplate              = New-Object system.Windows.Forms.ComboBox
$combo_filetemplate.AutoSize      = $true
$combo_filetemplate.width         = 125
$combo_filetemplate.height        = 10
$combo_filetemplate.location      = New-Object System.Drawing.Point(265,89)
$combo_filetemplate.Font          = $font
$combo_filetemplate.DropDownStyle = "DropDownList"
$combo_filetemplate.Enabled       = $false
$combo_filetemplate.TabStop       = $false
$combo_filetemplate.TabIndex      = 0
$templatefiles = PopulateFileTemplates
$combo_filetemplate.Add_MouseHover({
    $statusbar.text = "Choose an existing c-file you would like to take as the template"
})
$combo_filetemplate.Add_SelectedIndexChanged({
    $button_createproject.Focus()
})


$check_editorlauncher            = New-Object system.Windows.Forms.CheckBox
$check_editorlauncher.text       = "Editor Launcher"
$check_editorlauncher.width      = 125
$check_editorlauncher.height     = 20
$check_editorlauncher.location   = New-Object System.Drawing.Point(15,121)
$check_editorlauncher.Font       = $font
$check_editorlauncher.Checked    = $true
$check_editorlauncher.TabStop    = $false
$check_editorlauncher.TabIndex   = 0
$check_editorlauncher.Add_MouseHover({
    $statusbar.text = "When enabled creates a batch file that launches your preferred editor."
})

$check_editorlauncher.Add_CheckStateChanged({
    if ($check_editorlauncher.Checked) {
        WriteSettings $EDITORLAUNCHER_IDENTIFIER 1
    } else {
        WriteSettings $EDITORLAUNCHER_IDENTIFIER 0
    }
    $button_createproject.Focus()
})

$check_includecomment            = New-Object system.Windows.Forms.CheckBox
$check_includecomment.text       = "Info Comment"
$check_includecomment.width      = 125
$check_includecomment.height     = 20
$check_includecomment.location   = New-Object System.Drawing.Point(140,121)
$check_includecomment.Font       = $font
$check_includecomment.Checked    = $true
$check_includecomment.TabStop    = $false
$check_includecomment.TabIndex   = 0
$check_includecomment.Add_MouseHover({
    $statusbar.text = "When enabled includes a comment with general information."
})

$check_includecomment.Add_CheckStateChanged({
    if ($check_includecomment.Checked) {
        WriteSettings $INFOCOMMENT_IDENTIFIER 1
    } else {
        WriteSettings $INFOCOMMENT_IDENTIFIER 0
    }
    $button_createproject.Focus()
})

$check_closeoncreate            = New-Object system.Windows.Forms.CheckBox
$check_closeoncreate.text       = "Close on Creation"
$check_closeoncreate.width      = 125
$check_closeoncreate.height     = 20
$check_closeoncreate.location   = New-Object System.Drawing.Point(265,121)
$check_closeoncreate.Font       = $font
$check_closeoncreate.Checked    = $true
$check_closeoncreate.TabStop    = $false
$check_closeoncreate.TabIndex   = 0
$check_closeoncreate.Add_MouseHover({
    $statusbar.text = "When enabled closes this app after a project has been created."
})

$check_closeoncreate.Add_CheckStateChanged({
    if ($check_closeoncreate.Checked) {
        WriteSettings $CLOSEONCREATION_IDENTIFIER 1
    } else {
        WriteSettings $CLOSEONCREATION_IDENTIFIER 0
    }
    $button_createproject.Focus()
})


$button_createproject            = New-Object system.Windows.Forms.Button
$button_createproject.text       = "Create"
$button_createproject.width      = 377
$button_createproject.height     = 35
$button_createproject.location   = New-Object System.Drawing.Point(13,145)
$button_createproject.Font       = $font
$button_createproject.TabStop    = $false
$button_createproject.TabIndex   = 0
$button_createproject.Add_Click({onCreate})
$button_createproject.Add_MouseHover({
    $statusbar.text = "Creates the project. Hit CTRL + ENTER to launch text editor upon creation."
})
$button_createproject.Add_KeyDown({
    if ($_.KeyCode -eq "Enter" -and $_.Modifiers -eq "Control") {
        onCreate $true
    } elseif ($_.KeyCode -eq "Enter") {
        onCreate $true
    }
})


#### Search in Projects ####

$label_searchterm                = New-Object system.Windows.Forms.Label
$label_searchterm.text           = "Search String:"
$label_searchterm.AutoSize       = $true
$label_searchterm.width          = 25
$label_searchterm.height         = 10
$label_searchterm.location       = New-Object System.Drawing.Point(13,29)
$label_searchterm.Font           = $font

$entry_searchterm                = New-Object system.Windows.Forms.TextBox
$entry_searchterm.multiline      = $false
$entry_searchterm.width          = 170
$entry_searchterm.height         = 20
$entry_searchterm.location       = New-Object System.Drawing.Point(130,29)
$entry_searchterm.Font           = $entryfont
$entry_searchterm.Add_MouseHover({
    $statusbar.text = "The string to be searched for in filenames, foldernames and files."
})

$entry_searchterm.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        onSearch
    }
})

$button_search                   = New-Object system.Windows.Forms.Button
$button_search.text              = "Search"
$button_search.width             = 80
$button_search.height            = 25
$button_search.location          = New-Object System.Drawing.Point(307,29)
$button_search.Font              = $font
$button_search.TabStop           = $false
$button_search.TabIndex          = 0
$button_search.Add_Click({onSearch})

$filelist                        = New-Object system.Windows.Forms.ListView
$filelist.width                  = 375
$filelist.height                 = 150
$filelist.Anchor                 = 'top,right,bottom,left'
$filelist.View                   = "Details"
$filelist.FullRowSelect          = $true
$filelist.MultiSelect            = $false
$filelist.Sorting                = "None"
$filelist.AllowColumnReorder     = $false
$filelist.GridLines              = $true
$filelist.TabStop                = $false
$filelist.TabIndex               = 0
$filelist.location               = New-Object System.Drawing.Point(13,60)
[void]$filelist.Columns.Add("File")
[void]$filelist.Columns.Add("Folder")
[void]$filelist.Columns.Add("Line Nr")
[void]$filelist.Columns.Add("Line")
[void]$filelist.Columns.Add("File Path")
$filelist.Columns[0].Width = -2
$filelist.Columns[1].Width = -2
$filelist.Columns[2].Width = -2
$filelist.Columns[3].Width = -2
$filelist.Columns[4].Width = 0
$filelist.Add_MouseHover({
    $statusbar.text = "Displays the search results of the file and folder search"
})

$filelist.Add_ItemActivate({
    if ($filelist.SelectedItems.SubItems -ne $null) {
        explorer (Get-Item $filelist.SelectedItems.SubItems[4].text).Directory
    }
})

$filelist_contextmenu = New-Object System.Windows.Forms.ContextMenuStrip
$filelist_menuitem1 = $filelist_contextmenu.Items.Add("Show in Explorer")
$filelist_menuitem1.Font = $font
$filelist_menuitem1.add_Click({
    if ($filelist.SelectedItems.SubItems -ne $null) {
        explorer (Get-Item $filelist.SelectedItems.SubItems[4].text).Directory
    }
})

$filelist_menuitem7 = $filelist_contextmenu.Items.Add("Open with Text Editor")
$filelist_menuitem7.Font = $font
$filelist_menuitem7.add_Click({
    if ($filelist.SelectedItems.SubItems -ne $null) {
    $editorpath = GetEditorPath
    if ($editorpath -ne $null) {
        if ($editorpath -ne "") {
            & $editorpath $filelist.SelectedItems.SubItems[4].text
    }
    }
    }
})

$filelist_menuitem2 = $filelist_contextmenu.Items.Add("Open in Notepad")
$filelist_menuitem2.Font = $font
$filelist_menuitem2.add_Click({
    if ($filelist.SelectedItems.SubItems -ne $null) {
        notepad $filelist.SelectedItems.SubItems[4].text
    }
})

$filelist_menuitem3 = $filelist_contextmenu.Items.Add("Open with other Program")
$filelist_menuitem3.Font = $font
$filelist_menuitem3.add_Click({
    if ($filelist.SelectedItems.SubItems -ne $null) {
        $LaunchProgramDialog = New-Object System.Windows.Forms.OpenFileDialog
        $LaunchProgramDialog.initialDirectory = "."
        $LaunchProgramDialog.filter = "All files (*.*)| *.exe"
        $LaunchProgramDialog.ShowDialog() | Out-Null
        $launchfilepath = $LaunchProgramDialog.FileName
        if ($launchfilepath -ne $null -and $launchfilepath -ne "") {
            & $launchfilepath $filelist.SelectedItems.SubItems[4].text
        }
    }
})

$filelist_menuitem4 = $filelist_contextmenu.Items.Add("Copy Filepath")
$filelist_menuitem4.Font = $font
$filelist_menuitem4.add_Click({
    if ($filelist.SelectedItems.SubItems -ne $null) {
    Set-Clipboard -Value $filelist.SelectedItems.SubItems[4].text
    }
})

$filelist_menuitem5 = $filelist_contextmenu.Items.Add("Copy Filename")
$filelist_menuitem5.Font = $font
$filelist_menuitem5.add_Click({
    if ($filelist.SelectedItems.SubItems -ne $null) {
        Set-Clipboard -Value $filelist.SelectedItems.SubItems[0].text
    }
})

$filelist_menuitem8 = $filelist_contextmenu.Items.Add("Copy Line")
$filelist_menuitem8.Font = $font
$filelist_menuitem8.add_Click({
    if ($filelist.SelectedItems.SubItems -ne $null) {
        Set-Clipboard -Value $filelist.SelectedItems.SubItems[3].text
    }
})

$filelist_menuitem6 = $filelist_contextmenu.Items.Add("Delete Folder Permanently")
$filelist_menuitem6.Font = $font
$filelist_menuitem6.add_Click({
    if ($filelist.SelectedItems.SubItems -ne $null) {
        $confirmdelete = [System.Windows.Forms.MessageBox]::Show("Do you really want to delete the project '$($filelist.SelectedItems.SubItems[1].text)'? The action cannot be undone. ",'Confirm Removal','YesNoCancel','Warning')
        if ($confirmdelete -eq 'Yes') {
            Remove-Item -Path (Get-Item $filelist.SelectedItems.SubItems[3].text).Directory -Recurse
        }
    }
})

$statusbar                        = New-Object system.Windows.Forms.StatusBar
$statusbar.width                  = 420
$statusbar.height                 = 22
$statusbar.location               = New-Object System.Drawing.Point(0,458)
$statusbar.font                   = $font
$statusbar.SizingGrip             = $false
$statusbar.text                   = ""

# Init user settings such as comboboxes, checkboxes
InitSettings

<#
$tooltip1                        = New-Object System.Windows.Forms.ToolTip
$tooltip1.ToolTipIcon            = "Info"
$tooltip1.InitialDelay           = 500;  
$tooltip1.ReshowDelay            = 100;  
$tooltip1.AutoPopDelay           = 5000;
$tooltip1.IsBalloon              = $true
#>

$filelist.ContextMenuStrip = $filelist_contextmenu

$main_frame.controls.AddRange(@($menubar,$group_newproject,$group_search,$statusbar))
$group_newproject.controls.AddRange(@($label_foldername,$label_filename,$entry_foldername,$entry_filename,$label_defaulttext,$combo_defaulttext,$combo_filetemplate,$check_editorlauncher,$check_includecomment,$check_closeoncreate,$button_createproject))
$group_search.controls.AddRange(@($label_searchterm, $entry_searchterm, $button_search, $filelist))

[void]$main_frame.ShowDialog()