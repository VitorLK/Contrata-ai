[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$flutterRoot = $PSScriptRoot
$backendRoot = (Resolve-Path (Join-Path $flutterRoot '..\backend')).Path
$webBuild = Join-Path $flutterRoot 'build\web'
$demoPort = 8090
$demoProcess = $null
$previousDemoPort = $env:DEMO_PORT
$previousWebDir = $env:FLUTTER_WEB_DIR

function Write-Step([string]$message) {
  Write-Host "`n==> $message" -ForegroundColor Cyan
}

function Test-PortInUse([int]$port) {
  return $null -ne (
    Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
      Select-Object -First 1
  )
}

try {
  Write-Host 'Contrata Ai - Demonstracao remota' -ForegroundColor Green
  Write-Host 'Nada sera enviado ao Firebase e nenhum dado local sera apagado.'

  foreach ($command in @('flutter', 'node', 'npx')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
      throw "O comando '$command' nao foi encontrado no computador."
    }
  }

  if (-not (Test-Path (Join-Path $backendRoot '.env'))) {
    throw 'O arquivo backend\.env nao foi encontrado. Configure o banco antes de iniciar a demonstracao.'
  }

  while (Test-PortInUse $demoPort) {
    $demoPort++
    if ($demoPort -gt 8099) {
      throw 'As portas 8090 ate 8099 estao ocupadas. Feche uma demonstracao anterior e tente novamente.'
    }
  }

  Write-Step 'Gerando a versao Web otimizada'
  Push-Location $flutterRoot
  try {
    & flutter build web --release --no-wasm-dry-run
    if ($LASTEXITCODE -ne 0) {
      throw 'A compilacao Flutter Web falhou.'
    }
  } finally {
    Pop-Location
  }

  $logDir = Join-Path $env:TEMP 'contrata-ai-demo'
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $stdoutLog = Join-Path $logDir "servidor-$timestamp.log"
  $stderrLog = Join-Path $logDir "servidor-$timestamp-error.log"

  $env:DEMO_PORT = [string]$demoPort
  $env:FLUTTER_WEB_DIR = $webBuild

  Write-Step "Iniciando frontend e API na porta $demoPort"
  $nodePath = (Get-Command node).Source
  $demoProcess = Start-Process `
    -FilePath $nodePath `
    -ArgumentList 'src/demoServer.js' `
    -WorkingDirectory $backendRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput $stdoutLog `
    -RedirectStandardError $stderrLog `
    -PassThru

  $serverReady = $false
  for ($attempt = 0; $attempt -lt 30; $attempt++) {
    if ($demoProcess.HasExited) {
      $details = if (Test-Path $stderrLog) {
        Get-Content $stderrLog -Raw
      } else {
        'O servidor encerrou sem registrar detalhes.'
      }
      throw "Nao foi possivel iniciar o servidor de demonstracao.`n$details"
    }

    try {
      $health = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$demoPort/health" `
        -TimeoutSec 2
      if ($health.status -eq 'ok') {
        $serverReady = $true
        break
      }
    } catch {
      Start-Sleep -Milliseconds 500
    }
  }

  if (-not $serverReady) {
    throw 'O servidor de demonstracao nao respondeu dentro do tempo esperado.'
  }

  Write-Step 'Abrindo o link publico seguro'
  Write-Host 'Aguarde a linha "Your tunnel URL" e abra o endereco https no celular.' -ForegroundColor Yellow
  Write-Host 'O computador deve continuar ligado. Pressione Ctrl+C para encerrar.' -ForegroundColor Yellow
  Write-Host ''

  Push-Location $flutterRoot
  try {
    & npx --yes wrangler@latest tunnel quick-start "http://127.0.0.1:$demoPort"
  } finally {
    Pop-Location
  }
} catch {
  Write-Host "`nERRO: $($_.Exception.Message)" -ForegroundColor Red
  if ($stderrLog -and (Test-Path $stderrLog)) {
    Write-Host "Detalhes: $stderrLog" -ForegroundColor DarkYellow
  }
  exit 1
} finally {
  if ($demoProcess -and -not $demoProcess.HasExited) {
    Write-Host "`nEncerrando o servidor de demonstracao..." -ForegroundColor DarkGray
    Stop-Process -Id $demoProcess.Id -Force -ErrorAction SilentlyContinue
  }

  $env:DEMO_PORT = $previousDemoPort
  $env:FLUTTER_WEB_DIR = $previousWebDir
}
