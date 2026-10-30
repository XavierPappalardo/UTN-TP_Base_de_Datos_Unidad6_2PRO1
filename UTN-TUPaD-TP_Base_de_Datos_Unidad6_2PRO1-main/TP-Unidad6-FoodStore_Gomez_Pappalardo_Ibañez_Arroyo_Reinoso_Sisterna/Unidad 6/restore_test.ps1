# restore_test.ps1
# Ensayo de restauración de Food Store en foodstore_restore_test (base descartable).
# NO toca la base principal foodstore.
# Requisitos: PostgreSQL 16+ con pg_restore, createdb, psql en el PATH.
# Seguridad: no contiene contraseña. Se espera autenticación vía PGPASSWORD o .pgpass.

$ErrorActionPreference = "Stop"

# --- Configuración (ajustar al entorno) ---
$pgHost     = "localhost"
$pgPort     = "5432"
$pgUser     = "postgres"

# Rutas relativas a la ubicación de este script
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$backupDir  = Join-Path $scriptDir "backups"
$logDir     = Join-Path $scriptDir "logs"

if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

# Seleccionar el último respaldo .dump en backups/
$backups = Get-ChildItem -Path $backupDir -Filter "*.dump" | Sort-Object LastWriteTime -Descending
if ($backups.Count -eq 0) {
    Write-Host "ERROR: No se encontraron archivos .dump en $backupDir" -ForegroundColor Red
    exit 1
}
$ultimoRespald = $backups[0]
$backupFile    = $ultimoRespald.FullName
$fechaRespaldo = $ultimoRespald.LastWriteTime

$restoreDb   = "foodstore_restore_test"
$timestamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile     = Join-Path $logDir ("restore_test_" + $timestamp + ".log")

Write-Host "=== ENSAYO DE RESTAURACIÓN - Food Store ===" -ForegroundColor Cyan
Write-Host "Respaldo utilizado: $backupFile" -ForegroundColor Cyan
Write-Host "Fecha del respaldo: $fechaRespaldo" -ForegroundColor Cyan
Write-Host "Base de prueba: $restoreDb (descartable)" -ForegroundColor Cyan

# Cronómetro: inicia ANTES de crear la base de prueba
$cronometroInicio = Get-Date
Write-Host "Cronómetro iniciado: $cronometroInicio" -ForegroundColor Cyan

# Función para escribir en log y consola
function Escribir-Log($mensaje) {
    $linea = "{0:yyyy-MM-dd HH:mm:ss} - {1}" -f (Get-Date), $mensaje
    Write-Host $linea
    Add-Content -Path $logFile -Value $linea
}

# --- Paso 1: Crear base de prueba ---
Escribir-Log "Creando base $restoreDb ..."
try {
    & "C:\Program Files\PostgreSQL\18\bin\createdb.exe" -h $pgHost -p $pgPort -U $pgUser $restoreDb 2>&1 | Tee-Object -FilePath $logFile -Append
    if ($LASTEXITCODE -ne 0) { throw "createdb falló" }
}
catch {
    Escribir-Log "ERROR al crear $restoreDb: $_"
    exit 1
}

# --- Paso 2: Restaurar respaldo ---
Escribir-Log "Restaurando desde $backupFile ..."
try {
    & "C:\Program Files\PostgreSQL\18\bin\pg_restore.exe" -h $pgHost -p $pgPort -U $pgUser -d $restoreDb --no-owner --no-privileges $backupFile 2>&1 | Tee-Object -FilePath $logFile -Append
    if ($LASTEXITCODE -ne 0) { throw "pg_restore falló" }
}
catch {
    Escribir-Log "ERROR al restaurar: $_"
    exit 1
}

# --- Paso 3: Validaciones mínimas ---
Escribir-Log "Ejecutando validaciones mínimas sobre $restoreDb ..."

$psqlBaseArgs = @("-h", $pgHost, "-p", $pgPort, "-U", $pgUser, "-d", $restoreDb, "-t", "-A")

# Validación A: conteo de filas por tabla
$consultaFilas = @"
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria 
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente 
UNION ALL SELECT 'producto', COUNT(*) FROM producto 
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido 
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;
"@

# Validación B: productos inválidos
$consultaProdInvalidos = @"
SELECT COUNT(*) AS productos_invalidos 
FROM producto 
WHERE precio < 0 OR stock < 0;
"@

# Validación C: detalles inválidos
$consultaDetInvalidos = @"
SELECT COUNT(*) AS detalles_invalidos 
FROM detalle_pedido 
WHERE cantidad <= 0 OR precio_unitario < 0;
"@

$resultadoFilas   = & "C:\Program Files\PostgreSQL\18\bin\psql.exe" @psqlBaseArgs -c $consultaFilas   2>&1
$resultadoProd    = & "C:\Program Files\PostgreSQL\18\bin\psql.exe" @psqlBaseArgs -c $consultaProdInvalidos 2>&1
$resultadoDet     = & "C:\Program Files\PostgreSQL\18\bin\psql.exe" @psqlBaseArgs -c $consultaDetInvalidos 2>&1

Escribir-Log "Filas por tabla:`n$resultadoFilas"
Escribir-Log "Productos inválidos:`n$resultadoProd"
Escribir-Log "Detalles inválidos:`n$resultadoDet"

# Cronómetro: finaliza cuando las validaciones terminan
$cronometroFin = Get-Date
$rtoSegundos   = ($cronometroFin - $cronometroInicio).TotalSeconds

# Cálculo de antigüedad del respaldo (RPO observado)
$antiguedadHoras = ((Get-Date) - $fechaRespaldo).TotalHours

Escribir-Log "=== RESULTADO DEL ENSAYO ==="
Escribir-Log "Hora inicio: $cronometroInicio"
Escribir-Log "Hora fin: $cronometroFin"
Escribir-Log "RTO observado (segundos): $rtoSegundos"
Escribir-Log "RTO observado (minutos): $([math]::Round($rtoSegundos / 60, 2))"
Escribir-Log "Fecha del respaldo utilizado: $fechaRespaldo"
Escribir-Log "Antigüedad del respaldo al momento del simulacro (horas): $([math]::Round($antiguedadHoras, 2))"
Escribir-Log "RPO observado (horas transcurridas desde el respaldo): $([math]::Round($antiguedadHoras, 2))"

Write-Host "`nRTO observado: $([math]::Round($rtoSegundos / 60, 2)) minutos" -ForegroundColor Green
Write-Host "RPO observado (antigüedad del respaldo): $([math]::Round($antiguedadHoras, 2)) horas" -ForegroundColor Green
Write-Host "Log completo: $logFile" -ForegroundColor Green

# Verificación de restricciones lógicas: productos_invalidos y detalles_invalidos deben ser 0
# (El equipo debe inspeccionar el log para confirmar que ambos devuelven 0)

exit 0
