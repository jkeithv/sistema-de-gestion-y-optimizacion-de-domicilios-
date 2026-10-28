<#
 Reconstruye la base desde cero aplicando database/migrations en orden.
 Uso:   .\database\reconstruir.ps1
        .\database\reconstruir.ps1 -Db domicilios -User postgres -Host localhost
        .\database\reconstruir.ps1 -ConPruebas     # ademas corre pruebas/prueba_restricciones.sql
#>
param(
    [string]$Db   = "domicilios_test",
    [string]$User = "postgres",
    [string]$DbHost = "localhost",
    [int]$Port = 5432,
    [switch]$ConPruebas
)
$ErrorActionPreference = "Stop"
$env:PGCLIENTENCODING = "UTF8"
$raiz = $PSScriptRoot

dropdb   -h $DbHost -p $Port -U $User --if-exists $Db
createdb -h $DbHost -p $Port -U $User $Db

Get-ChildItem (Join-Path $raiz "migrations\*.sql") | Sort-Object Name | ForEach-Object {
    Write-Host ">> Aplicando $($_.Name)" -ForegroundColor Cyan
    psql -h $DbHost -p $Port -U $User -d $Db -v ON_ERROR_STOP=1 -q -f $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Fallo la migracion $($_.Name)" }
}

if ($ConPruebas) {
    Write-Host ">> Pruebas de restricciones" -ForegroundColor Cyan
    psql -h $DbHost -p $Port -U $User -d $Db -v ON_ERROR_STOP=1 -f (Join-Path $raiz "pruebas\prueba_restricciones.sql")
    if ($LASTEXITCODE -ne 0) { throw "Fallaron las pruebas" }
}
Write-Host "Esquema construido correctamente en '$Db'." -ForegroundColor Green
