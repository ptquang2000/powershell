# =============================================================================
#  Microsoft.PowerShell_profile.ps1
# -----------------------------------------------------------------------------
#  Purpose : Interactive pwsh profile for this machine. Configures PSReadLine,
#            PATH/PATHEXT, tool shortcut functions (Visual Studio, BuildTools,
#            sync-bin, etc.), project environment variables (JAVA_HOME, QT),
#            the oh-my-posh prompt, and a Ctrl+F psmux-sessionizer binding.
#
#  Load order (top to bottom):
#    1. Early exit for non-interactive one-shot pwsh invocations
#    2. Helpers (internal)
#    3. Modules
#    4. PSReadLine (options + key handlers, incl. Ctrl+F sessionizer)
#    5. PATH & PATHEXT
#    6. Tool shortcut functions (Visual Studio, BuildTools)
#    7. Work / project-specific functions and env (JAVA_HOME, QT, sync-bin)
#    8. Prompt (oh-my-posh)
#
#  Notes:
#    - Several functions have been renamed to Verb-Noun form. Command-name
#      compatibility aliases are provided for every old name (vs2017, vs2022,
#      buildtools, crosscompiler, cp_sdk, sync_bin, gen_prj), so existing
#      muscle memory and scripts keep working.
#    - PATH mutations go through Add-PathEntry which dedupes case-insensitively,
#      so `. $PROFILE` is idempotent.
# =============================================================================

#region Early exit for non-interactive one-shot invocations
# Skip expensive profile setup when pwsh is invoked as a one-shot command
# wrapper (e.g., psmux wraps `new-window <cmd>` as `pwsh -NoLogo -Command <cmd>`).
# Interactive panes use `-NoExit` so they still load the full profile.
$__cmdline = [Environment]::GetCommandLineArgs()
if (($__cmdline -match '^-(Command|c|EncodedCommand|e|File|f)$') -and
    -not ($__cmdline -match '^-NoExit$')) {
    return
}
Remove-Variable __cmdline
#endregion

#region Helpers (internal)
function Add-PathEntry {
    <#
    .SYNOPSIS
        Append (or prepend) a directory to $env:Path with dedup + existence checks.
    .DESCRIPTION
        Skips empty/whitespace input. Skips non-existent directories unless -Force.
        Deduplicates case-insensitively against the current $env:Path entries.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Path,

        [switch]$Prepend,
        [switch]$Force
    )
    process {
        if ([string]::IsNullOrWhiteSpace($Path)) { return }
        if (-not $Force -and -not (Test-Path -LiteralPath $Path -PathType Container)) { return }

        $existing = $env:Path -split ';' | Where-Object { $_ -ne '' }
        foreach ($e in $existing) {
            if ([string]::Equals($e.TrimEnd('\'), $Path.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) {
                return
            }
        }

        if ($Prepend) {
            $env:Path = "$Path;$($env:Path)"
        } else {
            if ($env:Path -and -not $env:Path.EndsWith(';')) {
                $env:Path = "$($env:Path);$Path"
            } else {
                $env:Path = "$($env:Path)$Path"
            }
        }
    }
}
#endregion

#region Modules
if (Get-Module -ListAvailable -Name CompletionPredictor) {
    Import-Module CompletionPredictor -ErrorAction SilentlyContinue
}
#endregion

#region PSReadLine
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineOption -ShowToolTips
Set-PSReadLineOption -CompletionQueryItems 65

Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
Set-PSReadLineKeyHandler -Key End            -Function AcceptSuggestion
Set-PSReadLineKeyHandler -Chord 'Tab'            -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+Backspace' -Function BackwardKillWord

# Ctrl+F triggers psmux-sessionizer (create/switch sessions via fzf)
$__psmuxRoot = if ($PSScriptRoot) {
    $PSScriptRoot
} elseif ($PROFILE) {
    Split-Path -Parent $PROFILE
} else {
    $null
}

if ([string]::IsNullOrWhiteSpace($__psmuxRoot)) {
    Write-Warning "psmux-sessionizer path could not be resolved; Ctrl+F binding skipped."
} else {
    $script:PsmuxSessionizerPath = Join-Path $__psmuxRoot 'psmux-sessionizer.ps1'
    Set-PSReadLineKeyHandler -Key Ctrl+f -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("& '$script:PsmuxSessionizerPath'")
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}
Remove-Variable __psmuxRoot -ErrorAction SilentlyContinue
#endregion

#region PATH & PATHEXT
# Core toolchain entries
Add-PathEntry 'C:\Python314'
Add-PathEntry 'C:\Python314\Scripts'
Add-PathEntry 'C:\Strawberry\perl\bin'

# Add .PY to PATHEXT (idempotent)
if ($env:PATHEXT -notlike '*.PY*') {
    $env:PATHEXT += ';.PY'
}

# Dynamic: every subdir of ~\.local\bin (prefer <subdir>\bin if it exists)
$BIN_DIR = Join-Path $env:USERPROFILE '.local\bin'
if (Test-Path -LiteralPath $BIN_DIR -PathType Container) {
    foreach ($d in [System.IO.Directory]::GetDirectories($BIN_DIR)) {
        $bin = [System.IO.Path]::Combine($d, 'bin')
        if ([System.IO.Directory]::Exists($bin)) {
            Add-PathEntry $bin
        } else {
            Add-PathEntry $d
        }
    }
}

# Scripts dir and VMWare
Add-PathEntry (Join-Path $env:USERPROFILE '.local\bin\scripts')
Add-PathEntry "${env:ProgramFiles(x86)}\VMWare\VMWare Workstation"

Write-Verbose "PATH entries added"
#endregion

#region Tool shortcut functions (Visual Studio, BuildTools)
$script:VS2017_DevEnv = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\Professional\Common7\IDE\devenv.exe"
$script:VS2022_DevEnv = "$env:ProgramFiles\Microsoft Visual Studio\2022\Professional\Common7\IDE\devenv.exe"
$script:VsDevCmdBat   = "C:\BuildTools\Common7\Tools\VsDevCmd.bat"
$script:VcVarsAllBat  = "C:\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
$script:VsWhereExe    = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

function Resolve-VsInstallRoot {
    <#
    .SYNOPSIS
        Resolve a Visual Studio / Build Tools installation root.
        Prefers C:\BuildTools when present, otherwise falls back to vswhere -latest.
        Returns $null if nothing is found (caller is responsible for error handling).
    #>
    [CmdletBinding()]
    param()

    if (Test-Path -LiteralPath 'C:\BuildTools\Common7\Tools\VsDevCmd.bat') {
        return 'C:\BuildTools'
    }
    if (Test-Path -LiteralPath $script:VsWhereExe) {
        try {
            $root = & $script:VsWhereExe -latest -products '*' `
                -requires Microsoft.Component.MSBuild `
                -property installationPath 2>$null | Select-Object -First 1
            if ($root -and (Test-Path -LiteralPath $root)) {
                return $root
            }
        } catch {
            Write-Verbose "vswhere failed: $_"
        }
    }
    return $null
}

function Resolve-VsBatPath {
    <#
    .SYNOPSIS
        Resolve a VS *.bat under the discovered install root, given a relative subpath.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RelativePath)

    $root = Resolve-VsInstallRoot
    if (-not $root) { return $null }
    $full = Join-Path $root $RelativePath
    if (Test-Path -LiteralPath $full) { return $full }
    return $null
}

function Start-VS2017 {
    if (-not (Test-Path -LiteralPath $script:VS2017_DevEnv)) {
        Write-Warning "Visual Studio 2017 devenv.exe not found at: $script:VS2017_DevEnv"
        return
    }
    & $script:VS2017_DevEnv @args
}

function Start-VS2022 {
    if (-not (Test-Path -LiteralPath $script:VS2022_DevEnv)) {
        Write-Warning "Visual Studio 2022 devenv.exe not found at: $script:VS2022_DevEnv"
        return
    }
    & $script:VS2022_DevEnv @args
}

function Invoke-VsBatEnv {
    <#
    .SYNOPSIS
        Run a VS-style *.bat env initializer and import the resulting env vars
        into the current PowerShell process.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$BatPath,

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [string[]]$BatArgs
    )

    if (-not (Test-Path -LiteralPath $BatPath)) {
        Write-Error "VS env batch file not found: $BatPath"
        return
    }

    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        $quoted = if ($BatArgs) {
            (@($BatArgs) | Where-Object { -not [string]::IsNullOrEmpty($_) } |
                ForEach-Object {
                    if ($_ -match '\s') { "`"$_`"" } else { $_ }
                }) -join ' '
        } else { '' }
        # Run the bat, then dump env to $tmp. Use `call` + explicit exit so we
        # propagate the bat's errorlevel back to PowerShell via $LASTEXITCODE,
        # and so that `set` runs even when the bat sets a non-zero errorlevel
        # (we still want to see whatever it printed).
        $cmdLine = " call `"$BatPath`" $quoted & set _vsbat_rc=%ERRORLEVEL% & set > `"$tmp`" & exit /b %_vsbat_rc% "
        $output = & cmd /c $cmdLine 2>&1
        $rc = $LASTEXITCODE
        Write-Verbose ($output -join [Environment]::NewLine)

        if ($rc -ne 0) {
            $msg  = "VS env batch failed (exit $rc): $BatPath $quoted"
            if ($output) { $msg += [Environment]::NewLine + ($output -join [Environment]::NewLine) }
            Write-Error $msg
            return
        }

        if (-not (Test-Path -LiteralPath $tmp) -or ((Get-Item -LiteralPath $tmp).Length -eq 0)) {
            Write-Error "VS env batch produced no environment output: $BatPath $quoted"
            return
        }

        Get-Content -LiteralPath $tmp | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$' -and $Matches[1] -ne '_vsbat_rc') {
                [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
            }
        }
    } finally {
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}

function Enter-BuildTools {
    <#
    .SYNOPSIS
        Import a Visual Studio / Build Tools developer environment (VsDevCmd.bat).
    #>
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]$BatArgs)

    $bat = if (Test-Path -LiteralPath $script:VsDevCmdBat) {
        $script:VsDevCmdBat
    } else {
        Resolve-VsBatPath 'Common7\Tools\VsDevCmd.bat'
    }
    if (-not $bat) {
        Write-Error "Could not locate VsDevCmd.bat. Checked '$script:VsDevCmdBat' and vswhere ('$script:VsWhereExe'). Install Build Tools or Visual Studio."
        return
    }
    Invoke-VsBatEnv $bat @BatArgs
}

function Enter-CrossCompiler {
    <#
    .SYNOPSIS
        Import a VC cross-compiler environment (vcvarsall.bat). Defaults to amd64.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Arch = 'amd64',

        [Parameter(ValueFromRemainingArguments)]
        [string[]]$ExtraArgs
    )

    $bat = if (Test-Path -LiteralPath $script:VcVarsAllBat) {
        $script:VcVarsAllBat
    } else {
        Resolve-VsBatPath 'VC\Auxiliary\Build\vcvarsall.bat'
    }
    if (-not $bat) {
        Write-Error "Could not locate vcvarsall.bat. Checked '$script:VcVarsAllBat' and vswhere ('$script:VsWhereExe'). Install Build Tools or Visual Studio with the C++ workload."
        return
    }
    Invoke-VsBatEnv $bat $Arch @ExtraArgs
}
#endregion

#region Work / project-specific functions and env
$script:CpSdkBat   = "$env:USERPROFILE\.local\bin\sync-bin\cp_sdk.bat"
$script:SyncBinPy  = "$env:USERPROFILE\work\sync-bin\sync.py"
$script:GenPrjPy   = "$env:USERPROFILE\work\upd-sln\gen_prj.py"
$script:JavaHome   = "C:\jdk-21"
$script:QtDir      = "C:\Qt\5.15.10\msvc2017\"
$script:QtArm64Dir = "C:\Qt\5.15.10\win32-arm64-msvc2017\"

function Invoke-CpSdk   { & $script:CpSdkBat @args }
function Invoke-SyncBin { python $script:SyncBinPy @args }
function Invoke-GenPrj  { python $script:GenPrjPy  @args }

$env:JAVA_HOME   = $script:JavaHome
$env:QT_DIR      = $script:QtDir
$env:QT_ARM64_DIR = $script:QtArm64Dir

# Qt paths go on PATH after QT_DIR is assigned
Add-PathEntry $env:QT_DIR
Add-PathEntry (Join-Path $env:QT_DIR 'bin')

# Command-name-compat aliases for renamed functions
Set-Alias -Name vs2017        -Value Start-VS2017        -Scope Global -Force
Set-Alias -Name vs2022        -Value Start-VS2022        -Scope Global -Force
Set-Alias -Name buildtools    -Value Enter-BuildTools    -Scope Global -Force
Set-Alias -Name crosscompiler -Value Enter-CrossCompiler -Scope Global -Force
Set-Alias -Name cp_sdk        -Value Invoke-CpSdk        -Scope Global -Force
Set-Alias -Name sync_bin      -Value Invoke-SyncBin      -Scope Global -Force
Set-Alias -Name gen_prj       -Value Invoke-GenPrj       -Scope Global -Force
#endregion

#region Prompt (oh-my-posh)
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    try {
        oh-my-posh init pwsh --config material | Invoke-Expression
    } catch {
        Write-Warning "oh-my-posh failed to load: $_"
    }
}
#endregion
