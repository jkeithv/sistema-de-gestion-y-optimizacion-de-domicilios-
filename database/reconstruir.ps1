<#
 Reconstruye la base desde cero aplicando database/migrations en orden.
 Uso:   .\database\reconstruir.ps1
        .\database\reconstruir.ps1 -ConPruebas                # + pruebas de restricciones
        .\database\reconstruir.ps1 -ConDatos                  # + datos semilla y su verificacion
        .\database\reconstruir.ps1 -ConPruebas -ConDatos      # todo
        .\database\reconstruir.ps1 -Db domicilios -User postgres -DbHost localhost
 Nota: la contrasena NO va en este archivo; usa  $env:PGPASSWORD = "..."  en tu sesion.
#>
param(
    [string]$Db   = "domicilios_test",
    [string]$User = "postgres",
    [string]$DbHost = "localhost",
    [int]$Port = 5432,
    [switch]$ConPruebas,
    [switch]$ConDatos
)
$ErrorActionPreference = "Stop"
$env:PGCLIENTENCODING = "UTF8"
$raiz = $PSScriptRoot

function Invoke-Sql([string]$archivo) {
    psql -h $DbHost -p $Port -U $User -d $Db -v ON_ERROR_STOP=1 -q -f $archivo
    if ($LASTEXITCODE -ne 0) { throw "Fallo $archivo" }
}

dropdb   -h $DbHost -p $Port -U $User --if-exists $Db
createdb -h $DbHost -p $Port -U $User $Db

Get-ChildItem (Join-Path $raiz "migrations\*.sql") | Sort-Object Name | ForEach-Object {
    Write-Host ">> Aplicando $($_.Name)" -ForegroundColor Cyan
    Invoke-Sql $_.FullName
}

if ($ConPruebas) {
    Write-Host ">> Pruebas de restricciones" -ForegroundColor Cyan
    Invoke-Sql (Join-Path $raiz "pruebas\prueba_restricciones.sql")
}

if ($ConDatos) {
    Get-ChildItem (Join-Path $raiz "seeds\*.sql") | Sort-Object Name | ForEach-Object {
        Write-Host ">> Cargando datos: $($_.Name)" -ForegroundColor Cyan
        Invoke-Sql $_.FullName
    }
    Write-Host ">> Verificando datos semilla" -ForegroundColor Cyan
    Invoke-Sql (Join-Path $raiz "pruebas\verificar_semilla.sql")
}
Write-Host "Esquema construido correctamente en '$Db'." -ForegroundColor Green
