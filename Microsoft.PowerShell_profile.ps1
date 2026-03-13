# Import PSReadLine
$module = "PSReadLine"
if (-not (Get-Module -ListAvailable $module)) {
    Install-Module $module -Scope CurrentUser -Force
}
# ImportTabExpansionPlusPlus 
$module = "TabExpansionPlusPlus"
if (-not (Get-Module -ListAvailable $module)) {
    Install-Module $module -Scope CurrentUser -Force -AllowClobber
}
# Import PSReadLine
$module = "CompletionPredictor"
if (-not (Get-Module -ListAvailable $module)) {
    Install-Module $module -Scope CurrentUser -Force -Repository PSGallery
}

Import-Module PSReadLine
Import-Module CompletionPredictor 
Import-Module TabExpansionPlusPlus

Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord 
Set-PSReadLineKeyHandler -Key End -Function AcceptSuggestion
Set-PSReadLineKeyHandler -Chord 'Tab' -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+Backspace' -Function BackwardKillWord
Set-PSReadLineOption -ShowToolTips
Set-PSReadLineOption -CompletionQueryItems 65

# Update Path Environment Variable

$env:Path += ";C:\Python314;C:\Python314\Scripts"
$env:Path += ";C:\Strawberry\perl\bin"

# Add .PY to PATHEXT
if ($env:PATHEXT -notlike '*.PY*') {
    $env:PATHEXT += ';.PY'
}

# Add every BIN_DIR and BIN_DIR\bin to PATH
$BIN_DIR = Join-Path $env:USERPROFILE ".local\bin"
if (Test-Path $BIN_DIR) {
    Get-ChildItem -Directory $BIN_DIR | ForEach-Object {
        $subdir = $_.FullName
        $binSubdir = Join-Path $subdir "bin"
        if (Test-Path $binSubdir) {
            $env:PATH += ";$binSubdir"
        } else {
            $env:PATH += ";$subdir"
        }
    }
}

Write-Host "`nPATH added`n"

# VS and Tools shortcuts (PowerShell functions)
Function vs2017 { & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\Professional\Common7\IDE\devenv.exe" @args }
Function vs2022 { & "$env:ProgramFiles\Microsoft Visual Studio\2022\Professional\Common7\IDE\devenv.exe" @args }
Function buildtools { & "C:\BuildTools\Common7\Tools\VsDevCmd" @args }
Function crosscompiler { & "C:\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" @args }
Function cp_sdk { & "$env:USERPROFILE\.local\bin\sync-bin\cp_sdk.bat" @args }
Function sync_bin { python "$env:USERPROFILE\.local\bin\sync-bin\sync.py" @args }
Function gen_prj { python "$env:USERPROFILE\.local\bin\upd-sln\gen_prj.py" @args }

# To set WIX (currently commented out):
# $env:WIX = "$env:USERPROFILE\wix311-binaries"

# Set JAVA_HOME
$env:JAVA_HOME = "C:\jdk-21"

# Add scripts and VMWare to Path
$env:Path += ";$env:USERPROFILE\.local\bin\scripts;${env:ProgramFiles(x86)}\VMWare\VMWare Workstation"

# Bind Ctrl+F to fuzzy directory search
Set-PSReadLineKeyHandler -Key Ctrl+f -ScriptBlock {
    $selectedPath = Get-ChildItem -Path "$env:USERPROFILE\Documents", "$env:USERPROFILE\work", "$env:USERPROFILE\.local\bin", "$env:USERPROFILE\.config" -Recurse -Depth 2 -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/]\.git([\\/]|$)' } |
        ForEach-Object { $_.FullName } |
        fzf
    
    if ($selectedPath) {
	Set-Location -Path $selectedPath
	[Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()

	$dirName = Split-Path $selectedPath -Leaf
	$tabTitle = $dirName -replace '\.', '_'
	$host.UI.RawUI.WindowTitle = $tabTitle
    }
}

if (-not $env:NVIM_LOG_FILE) {
	Set-Location -Path $env:HOMEPATH
}

$ompExe = (Get-Command oh-my-posh -ErrorAction SilentlyContinue).Source
$themeName = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\material.omp.json"  # Change this as desired
if ($ompExe) {
    & $ompExe init pwsh --config $themeName | Invoke-Expression
}

$env:QT_DIR="C:\Qt\5.15.10\msvc2017\"
$env:QT_ARM64_DIR="C:\Qt\5.15.10\win32-arm64-msvc2017\"
$env:PATH+=";$env:QT_DIR;$env:QT_DIR\bin"
