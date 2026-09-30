# SiteMills CLI installer for Windows.
#
#   irm https://raw.githubusercontent.com/SiteMills/sitemills-cli/main/install.ps1 | iex
#
# Environment variables:
#   SITEMILLS_VERSION      Install a specific version (e.g. 1.0.2). Default: latest release.
#   SITEMILLS_INSTALL_DIR  Directory to install into. Default: %LOCALAPPDATA%\Programs\sitemills-cli
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Repo = 'SiteMills/sitemills-cli'
$Asset = 'sitemills-win.exe'
$BinName = 'sitemills-cli.exe'

if (-not [Environment]::Is64BitOperatingSystem) {
    throw 'SiteMills CLI requires 64-bit Windows.'
}

if ($env:SITEMILLS_VERSION) {
    $Version = $env:SITEMILLS_VERSION.TrimStart('v')
    $BaseUrl = "https://github.com/$Repo/releases/download/v$Version"
} else {
    $BaseUrl = "https://github.com/$Repo/releases/latest/download"
}

$InstallDir = if ($env:SITEMILLS_INSTALL_DIR) { $env:SITEMILLS_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\sitemills-cli' }
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$TmpDir = Join-Path ([IO.Path]::GetTempPath()) ("sitemills-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
try {
    Write-Host "Downloading $Asset from $BaseUrl ..."
    $ExePath = Join-Path $TmpDir $Asset
    $SumsPath = Join-Path $TmpDir 'SHA256SUMS'
    Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/$Asset" -OutFile $ExePath
    Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/SHA256SUMS" -OutFile $SumsPath

    $Line = Get-Content $SumsPath | Where-Object { $_ -match " $([regex]::Escape($Asset))$" } | Select-Object -First 1
    if (-not $Line) { throw "No checksum for $Asset in SHA256SUMS" }
    $Expected = ($Line -split ' ')[0].ToLower()
    $Actual = (Get-FileHash -Algorithm SHA256 $ExePath).Hash.ToLower()
    if ($Expected -ne $Actual) { throw "Checksum mismatch for $Asset (expected $Expected, got $Actual)" }

    Move-Item -Force $ExePath (Join-Path $InstallDir $BinName)
} finally {
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
}

Write-Host "Installed $BinName to $InstallDir"

$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$Entries = if ($UserPath) { $UserPath -split ';' } else { @() }
if ($Entries -notcontains $InstallDir) {
    $NewPath = (@($Entries | Where-Object { $_ }) + $InstallDir) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $NewPath, 'User')
    $env:Path = "$env:Path;$InstallDir"
    Write-Host "Added $InstallDir to your user PATH. Open a new terminal for it to take effect."
}

Write-Host ""
Write-Host "Get started:  sitemills-cli login"
