param([switch]$NoBrowser)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

# Reuse the Hugo and Go tools already installed for the academic site.
$academicSite = Join-Path (Split-Path -Parent $PSScriptRoot) 'jiaxun-li.github.io'
$toolDirs = @(
  (Join-Path $academicSite '.local-tools/hugo'),
  (Join-Path $academicSite '.local-tools/go/bin'),
  (Join-Path $PSScriptRoot 'node_modules/.bin')
)
$env:Path = ($toolDirs -join ';') + ';' + $env:Path
if (-not (Get-Command hugo -ErrorAction SilentlyContinue)) {
  throw 'Hugo was not found. Keep this blog beside the jiaxun-li.github.io folder.'
}

# Tailwind resolves CSS imports from the blog folder, so it needs local packages.
$dependenciesReady = (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'node_modules/tailwindcss/package.json')) -and
  (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'node_modules/@tailwindcss/cli/package.json')) -and
  (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'node_modules/@tailwindcss/typography/package.json'))
if (-not $dependenciesReady) {
  if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
    throw 'Node.js is required to install the blog dependencies.'
  }
  Write-Host 'First-time setup: installing blog dependencies...'
  & npm.cmd install --no-audit --no-fund
  if ($LASTEXITCODE -ne 0) {
    throw 'Installing blog dependencies failed. Check your internet connection and try again.'
  }
}

$previewUrl = 'http://localhost:1315/blogs/zh/'
$browserJob = $null
if (-not $NoBrowser) {
  # Open the browser after Hugo has finished building the preview.
  $browserJob = Start-Job -ArgumentList $previewUrl -ScriptBlock {
    param($url)
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
      try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
          Start-Process $url
          return
        }
      } catch {}
      Start-Sleep -Seconds 1
    }
  }
}

Write-Host "Preview: $previewUrl"
Write-Host 'Keep this window open. Press Ctrl+C to stop.'
try {
  & hugo server --port 1315 --baseURL 'http://localhost:1315/blogs/' --bind 127.0.0.1 --disableFastRender
  if ($LASTEXITCODE -ne 0) {
    throw 'The preview could not start. See the Hugo error above for details.'
  }
} finally {
  if ($browserJob) {
    Stop-Job -Job $browserJob -ErrorAction SilentlyContinue
    Remove-Job -Job $browserJob -Force -ErrorAction SilentlyContinue
  }
}
