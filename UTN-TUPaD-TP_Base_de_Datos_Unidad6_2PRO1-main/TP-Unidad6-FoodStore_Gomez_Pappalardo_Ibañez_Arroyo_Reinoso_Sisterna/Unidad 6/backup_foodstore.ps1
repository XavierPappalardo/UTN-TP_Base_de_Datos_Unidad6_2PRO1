# backup_foodstore.ps1
# Genera un respaldo custom (formato -Fc) de la base foodstore.
# Requisitos: PostgreSQL 16+ con pg_dump en el PATH.
# Seguridad: no contiene contraseña. Se espera autenticación vía variable de entorno PGPASSWORD
# o archivo de conexión (.pgpass) del entorno de ejecución.

$ErrorActionPreference = "Stop"

# --- Configuración (ajustar al entorno) ---
$pgHost     = "localhost"
$pgPort     = "5432"
$pgUser     = "postgres"
$pgDatabase = "foodstore"

# Rutas relativas a la ubicación de este script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$backupDir = Join-Path $scriptDir "backups"
$logDir    = Join-Path $scriptDir "logs"

# Crear carpetas si no existen
if (!(Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }
if (!(Test-Path $logDir))    { New-Item -ItemType Directory -Path $logDir | Out-Null }

# Nombre del archivo con fecha y hora
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = Join-Path $backupDir ("foodstore_" + $timestamp + ".dump")
$logFile    = Join-Path $logDir    ("backup_" + $timestamp + ".log")

# Comando de respaldo (formato custom para pg_restore)
$pgDumpArgs = @(
    "-h", $pgHost,
    "-p", $pgPort,
    "-U", $pgUser,
    "-d", $pgDatabase,
    "-Fc",
    "-f", $backupFile
)

Write-Host "Iniciando respaldo de $pgDatabase ..." -ForegroundColor Cyan
Write-Host "Destino: $backupFile" -ForegroundColor Cyan

$start = Get-Date

try {
    & pg_dump @pgDumpArgs 2>&1 | Tee-Object -FilePath $logFile
    $exitCode = $LASTEXITCODE
}
catch {
    $exitCode = 1
    $_ | Out-File -FilePath $logFile -Append
}

$end = Get-Date
$duracion = ($end - $start).TotalSeconds

# Registrar resultado en el log
"Finalizado: $end" | Out-File -FilePath $logFile -Append
"Duracion (s): $duracion" | Out-File -FilePath $logFile -Append
"Codigo de salida pg_dump: $exitCode" | Out-File -FilePath $logFile -Append

if ($exitCode -ne 0) {
    Write-Host "ERROR: pg_dump falló con código $exitCode. Revisar $logFile" -ForegroundColor Red
    exit 1
}

Write-Host "Respaldo generado correctamente: $backupFile" -ForegroundColor Green
Write-Host "Log: $logFile" -ForegroundColor Green
exit 0
