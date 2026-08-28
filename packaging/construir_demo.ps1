# Construye la carpeta portable y el ZIP para demo RRHH.
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
$packaging = $PSScriptRoot
$dist = Join-Path $raiz "dist\GestorHorasExtra-Demo"
$venv = Join-Path $packaging ".venv"

Write-Host "==> Cliente Flutter (Windows release)"
Push-Location (Join-Path $raiz "desktop_client")
try {
    flutter pub get
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "Falló flutter build windows" }
}
finally {
    Pop-Location
}

$flutterRelease = Join-Path $raiz "desktop_client\build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $flutterRelease "gestor_horas_extra_client.exe"))) {
    throw "No se generó el cliente Flutter en $flutterRelease"
}

Write-Host "==> Entorno Python y PyInstaller"
if (-not (Test-Path (Join-Path $venv "Scripts\python.exe"))) {
    python -m venv $venv
}
& (Join-Path $venv "Scripts\python.exe") -m pip install --upgrade pip
& (Join-Path $venv "Scripts\pip.exe") install -r (Join-Path $raiz "backend\requirements.txt")
& (Join-Path $venv "Scripts\pip.exe") install pyinstaller

$icono = Join-Path $raiz "desktop_client\windows\runner\resources\app_icon.ico"
$iconoArgs = @()
if (Test-Path $icono) {
    $iconoArgs = @("--icon", $icono)
}

Write-Host "==> Lanzador GestorHorasExtra.exe"
$pyi = Join-Path $venv "Scripts\pyinstaller.exe"
$work = Join-Path $packaging "build"
$pyiDist = Join-Path $packaging "pyi_dist"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
if (Test-Path $pyiDist) { Remove-Item $pyiDist -Recurse -Force }

& $pyi `
    --noconfirm `
    --clean `
    --windowed `
    --name "GestorHorasExtra" `
    --paths (Join-Path $raiz "backend") `
    --collect-submodules app `
    --collect-all uvicorn `
    --collect-all fastapi `
    --collect-all starlette `
    --collect-all sqlalchemy `
    --hidden-import jwt `
    --hidden-import pydantic `
    --hidden-import app.main `
    --hidden-import sqlalchemy.dialects.sqlite `
    --hidden-import sqlalchemy.dialects.sqlite.pysqlite `
    --exclude-module pytest `
    --exclude-module httpx `
    --distpath $pyiDist `
    --workpath $work `
    --specpath $work `
    @iconoArgs `
    (Join-Path $packaging "lanzador.py")

$lanzadorDir = Join-Path $pyiDist "GestorHorasExtra"
if (-not (Test-Path (Join-Path $lanzadorDir "GestorHorasExtra.exe"))) {
    throw "PyInstaller no generó GestorHorasExtra.exe"
}

Write-Host "==> Armando carpeta dist\GestorHorasExtra-Demo"
if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Path $dist | Out-Null
Copy-Item -Path (Join-Path $lanzadorDir "*") -Destination $dist -Recurse
$clienteDest = Join-Path $dist "cliente"
New-Item -ItemType Directory -Path $clienteDest | Out-Null
Copy-Item -Path (Join-Path $flutterRelease "*") -Destination $clienteDest -Recurse
Copy-Item -Path (Join-Path $packaging "LEEME-RRHH.txt") -Destination (Join-Path $dist "LEEME-RRHH.txt")
New-Item -ItemType Directory -Path (Join-Path $dist "datos") | Out-Null

$zip = Join-Path $raiz "dist\GestorHorasExtra-Demo-Windows.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $dist "*") -DestinationPath $zip -CompressionLevel Optimal

Write-Host ""
Write-Host "Listo para RRHH:"
Write-Host "  Carpeta: $dist"
Write-Host "  ZIP:     $zip"
Write-Host "  Abrir:   $(Join-Path $dist 'GestorHorasExtra.exe')"
