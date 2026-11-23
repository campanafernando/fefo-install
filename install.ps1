# FEFO installer: downloads the FEFO workspace template and links the fefo CLI.
# PowerShell 5.1+, Windows 10/11. Linux, macOS and WSL use install.sh.
$ErrorActionPreference = 'Stop'

$Repo = if ($env:FEFO_REPO) { $env:FEFO_REPO } else { 'campanafernando/FEFO' }
$Ref = if ($env:FEFO_REF) { $env:FEFO_REF } else { 'main' }
$InstallDir = if ($env:FEFO_INSTALL_DIR) { $env:FEFO_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'fefo' }
$BinDir = if ($env:FEFO_BIN_DIR) { $env:FEFO_BIN_DIR } else { Join-Path $env:USERPROFILE '.local\bin' }
$Url = if ($env:FEFO_ZIP_URL) { $env:FEFO_ZIP_URL } else { "https://codeload.github.com/$Repo/zip/$Ref" }
$UpdateUrl = if ($env:FEFO_UPDATE_URL) { $env:FEFO_UPDATE_URL } else { 'https://opencode.ai/update/api/latest/cli/npm' }

if (-not $InstallDir -or $InstallDir -eq $env:USERPROFILE) {
    throw "fefo-install: refusing unsafe install dir: $InstallDir"
}

$pyExe = $null
$pyArgs = @()
if (Get-Command py -ErrorAction SilentlyContinue) {
    $pyExe = 'py'
    $pyArgs = @('-3')
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $pyExe = 'python'
}
if (-not $pyExe) {
    throw 'fefo-install: Python 3.10+ is required (https://www.python.org/downloads/)'
}
& $pyExe @pyArgs -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)"
if ($LASTEXITCODE -ne 0) {
    throw 'fefo-install: Python 3.10+ is required'
}

if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
    throw 'fefo-install: opencode not found. Install the latest OpenCode first: https://opencode.ai'
}

if ($env:FEFO_SKIP_UPDATE_CHECK -ne '1') {
    $installed = [string]((& opencode --version 2>$null) -replace '.*\s', '' -replace '^v', '')
    if (-not $installed) {
        throw 'fefo-install: could not determine the OpenCode version; run: opencode upgrade'
    }
    $latest = $null
    try {
        $info = Invoke-RestMethod -Uri $UpdateUrl -TimeoutSec 10
        $latest = [string]$info.version
    } catch {
        Write-Warning 'could not check the latest OpenCode version; continuing.'
    }
    if ($latest -and ([version]$installed -lt [version]$latest)) {
        throw "fefo-install: OpenCode $installed is older than the latest $latest; run: opencode upgrade"
    }
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('fefo-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    $zip = Join-Path $tmp 'fefo.zip'
    $source = $Url -replace '^file://', ''
    if (Test-Path $source) {
        Copy-Item $source $zip
    } else {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $zip
    }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $src = Get-ChildItem $tmp -Directory | Select-Object -First 1
    if (-not $src) {
        throw 'fefo-install: unexpected archive layout'
    }
    if (Test-Path $InstallDir) {
        Remove-Item $InstallDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $InstallDir) | Out-Null
    Move-Item $src.FullName $InstallDir
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
$shim = @"
@echo off
setlocal
set "PYTHONUTF8=1"
set "FEFO_HOME=$InstallDir"
where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%FEFO_HOME%\tools\fefo.py" %*
) else (
  python "%FEFO_HOME%\tools\fefo.py" %*
)
exit /b %errorlevel%
"@
Set-Content -Path (Join-Path $BinDir 'fefo.cmd') -Value $shim -Encoding ASCII

if ($env:FEFO_NO_MODIFY_PATH -ne '1') {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($userPath -split ';') -notcontains $BinDir) {
        $newPath = if ($userPath) { "$userPath;$BinDir" } else { $BinDir }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Host "Added $BinDir to your user PATH. Open a new terminal."
    }
    $env:Path = "$BinDir;$env:Path"
}

& $pyExe @pyArgs (Join-Path $InstallDir 'tools\fefo.py') --help | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'fefo-install: installed CLI did not run'
}

Write-Host @"

FEFO installed.
  CLI:  $(Join-Path $BinDir 'fefo.cmd')
  Home: $InstallDir

Next:
  mkdir $HOME\EXEMPLO; cd $HOME\EXEMPLO
  git clone <repository> exemplo-api
  git clone <repository> exemplo-web
  fefo build

Helpers:
  fefo cmg             suggest a Conventional Commit message
  fefo bng             suggest and create a branch
  fefo doit "task"     run a task through OpenCode
"@
