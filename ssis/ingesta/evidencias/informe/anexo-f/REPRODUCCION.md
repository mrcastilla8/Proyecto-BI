# Reproducir la ingesta en Windows

Consulta las [versiones observadas](versiones.txt) y la [compilación](compilacion.txt). Ejecuta PowerShell 7 desde la raíz del repositorio con Visual Studio 2026, la extensión SSIS Projects, Integration Services 2025 x64, MSOLEDBSQL y SQLCMD instalados. Los parámetros usan autenticación Windows.

## Regeneración

```powershell
$proyecto = (Resolve-Path 'ssis/ingesta/ETL_Olist_Ingesta').Path
$lab = (Resolve-Path 'ssis/ingesta/obj/issue1-prototipo').Path
$gen = 'ssis/ingesta/generador'
& "$gen/generar.ps1" -Salida "$lab/regenerado"
```

La carpeta de salida debe ser nueva. El script compila el generador y Script Task, genera los paquetes a partir del contrato y comprueba que SSIS puede volver a cargarlos. `-FalloEn Orders` genera una variante de ensayo que inyecta un fallo en la publicación de Orders. Mantén esa variante en una carpeta ignorada.

## Compilar y probar

Para establecer un laboratorio nuevo, crea una instancia LocalDB con nombre exclusivo y la base `BI_OLIST` dentro de un directorio local de ensayos. Aplica en esa instancia los scripts aprobados de `database/` en su orden documentado. Los scripts de pruebas verifican que el servidor sea LocalDB, que la base corresponda al laboratorio y que sus archivos físicos estén en el directorio autorizado. Prepara directorios de evidencias distintos para cada ejecución.

```powershell
$instancia = '(localdb)\BI_OLIST_ISSUE1_PROTO'
$archivosSql = "$lab/sql"
$csvRoot = Read-Host 'Carpeta autorizada con los nueve CSV'
& "$gen/probar.ps1" -Proyecto $proyecto -Evidencia "$lab/fixtures-nuevas" `
   -ArchivosLocalDb $archivosSql -Instancia $instancia -FixturesLf -PorPaquete
& "$gen/probar.ps1" -Proyecto $proyecto -Evidencia "$lab/autenticos-nuevos" `
   -ArchivosLocalDb $archivosSql -Instancia $instancia -CsvRoot $csvRoot
& "$gen/probar-recuperacion.ps1" -Proyecto $proyecto -Fixtures "$lab/fixtures-nuevas/fixtures" `
   -ArchivosLocalDb $archivosSql -Instancia $instancia -Evidencia "$lab/recuperacion-nueva"
& "$gen/probar-concurrencia.ps1" -Instancia $instancia -ArchivosLocalDb $archivosSql `
   -Ispac "$lab/autenticos-nuevos/proyecto/bin/Development/ETL_Olist_Ingesta.ispac" `
   -Hashes "$lab/autenticos-nuevos/hashes.csv" -Evidencia "$lab/concurrencia-nueva"
python scripts/validar_base.py
python -m unittest discover -s scripts -p 'test*.py'
```

`probar.ps1` copia el proyecto, configura los tres parámetros de laboratorio, invoca `devenv.com <solución> /Build Development /Out <registro>` y ejecuta el `DTExec.exe` x64 17.x de `%ProgramFiles%\Microsoft SQL Server\170\DTS\Binn` con `/Project <ispac> /Package ETL_Master.dtsx /Reporting EWI`. Usa `-SoloPreparar` para compilar una copia de ensayo y abrir su solución desde Visual Studio. Ejecuta el maestro o inspecciona un paquete desde esa copia.

El maestro valida las entradas y ejecuta Orders, OrderItems, OrderPayments, OrderReviews, Customers, Sellers, Products, Geolocation y CategoryTranslation. Comprueba código de salida 0 en ejecuciones correctas, conciliación de los nueve lotes y conservación de IDs, fechas y conteos en la reejecución. El ensayo con fallo exige código 1, registro `PUBLICAR/51999` y cero filas persistidas del lote fallido. La recuperación exige `COMPLETE` con su mismo ID. La prueba de concurrencia exige `BATCH_LOCK_TIMEOUT` y un lote completo intacto.

`probar.ps1` escribe `conciliar.sql` con cada hash real o sintético. [La consulta de evidencia](../../../generador/sql/consultas-evidencia.sql) reproduce las cuadrículas de esta ejecución concreta y usa los IDs observados en este laboratorio. Para una ejecución nueva usa los IDs de `conciliar-1.log` y `conciliar-2.log`.
