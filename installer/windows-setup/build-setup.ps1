# Gera o GoLiveBypass-Setup-<versao>.exe a partir do exe portable de uma release oficial.
#
#   .\build-setup.ps1                  # ultima release estavel de bezumiya/GoLiveBypass
#   .\build-setup.ps1 -Tag v2.0.18     # release especifica
#   .\build-setup.ps1 -ExePath C:\...\GoLiveBypass-2.0.18.exe -Version 2.0.18   # exe local
#
# O exe baixado e conferido pelo SHA-256 que a API do GitHub publica para o asset.
# Precisa do NSIS 3 (winget install NSIS.NSIS).
param(
  [string]$Tag = "",
  [string]$ExePath = "",
  [string]$Version = "",
  [string]$Repo = "bezumiya/GoLiveBypass",
  [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $OutDir) { $OutDir = Join-Path $here "dist" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$headers = @{ "User-Agent" = "golivebypass-setup-build"; "Accept" = "application/vnd.github+json" }
if ($env:GITHUB_TOKEN) { $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN" }

if (-not $ExePath) {
  $url = if ($Tag) { "https://api.github.com/repos/$Repo/releases/tags/$Tag" } else { "https://api.github.com/repos/$Repo/releases/latest" }
  $release = Invoke-RestMethod -Uri $url -Headers $headers
  $Version = $release.tag_name -replace '^v', ''
  $assetName = "GoLiveBypass-$Version.exe"
  $asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
  if (-not $asset) { throw "A release $($release.tag_name) nao tem o asset $assetName." }
  $ExePath = Join-Path $OutDir $assetName
  Write-Host "Baixando $assetName ($([math]::Round($asset.size / 1MB)) MB)..."
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $ExePath -Headers @{ "User-Agent" = $headers["User-Agent"] }
  if (-not $asset.digest -or $asset.digest -notmatch '^sha256:([0-9a-f]{64})$') {
    throw "A API nao informou o SHA-256 de $assetName; abortando sem conferir."
  }
  $expected = $Matches[1]
  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $ExePath).Hash.ToLowerInvariant()
  if ($actual -ne $expected) {
    Remove-Item -LiteralPath $ExePath -Force
    throw "SHA-256 diferente em ${assetName}: esperado $expected, veio $actual."
  }
  Write-Host "SHA-256 conferido: $actual"
} elseif (-not $Version) {
  $Version = (Get-Item -LiteralPath $ExePath).VersionInfo.ProductVersion
  if (-not $Version) { throw "Informe -Version para o exe local." }
}
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
  throw "Versao '$Version' fora do formato x.y.z (betas nao geram instalador)."
}

$makensis = (Get-Command makensis -ErrorAction SilentlyContinue).Source
if (-not $makensis) {
  foreach ($c in @("${env:ProgramFiles(x86)}\NSIS\makensis.exe", "$env:ProgramFiles\NSIS\makensis.exe")) {
    if (Test-Path $c) { $makensis = $c; break }
  }
}
if (-not $makensis) { throw "makensis nao encontrado. Instale o NSIS 3: winget install NSIS.NSIS" }

$out = Join-Path $OutDir "GoLiveBypass-Setup-$Version.exe"
& $makensis /V2 /INPUTCHARSET UTF8 "/DAPP_EXE=$((Resolve-Path $ExePath).Path)" "/DAPP_VERSION=$Version" "/DOUT_FILE=$out" (Join-Path $here "GoLiveBypass-Setup.nsi")
if ($LASTEXITCODE -ne 0) { throw "makensis falhou ($LASTEXITCODE)." }
Write-Host "Instalador gerado: $out"
"$out"
