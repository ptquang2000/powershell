# Import PSReadLine
$module = "PSReadLine"
if (-not (Get-Module -ListAvailable $module)) {
    Install-Module $module -Scope CurrentUser -Force
}
Import-Module $module

Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView

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

Set-PSReadLineKeyHandler -Chord 'Ctrl+Backspace' -Function BackwardKillWord
Set-Location -Path $env:HOMEPATH

$ompExe = (Get-Command oh-my-posh -ErrorAction SilentlyContinue).Source
$themeName = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\bubbles.omp.json"  # Change this as desired
if ($ompExe) {
    & $ompExe init pwsh --config $themeName | Invoke-Expression
}
