# SQL Server y Data Mart `BI_OLIST`

Esta guía describe los scripts SQL ejecutables. Responsabilidad: Castilla mantiene el esquema, controles y contratos; Poma implementa la ingesta SSIS; Cueva implementa la transformación SSIS y la política operativa de repetición por lote.

## Ejecución local

Windows PowerShell, instancia local y autenticación integrada:

```powershell
sqlcmd -S .\SQLEXPRESS -E -C -b -i database\00_crear_base.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -i database\01_auditoria.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -i database\02_staging.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -i database\03_dimensiones.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -i database\04_hechos.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -i database\05_controles.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -i database\06_pruebas.sql
```

El entorno observado fue SQL Server 2025 Express 17.0.1000.7. Se usó `-C` porque el certificado del motor local no está en la cadena de confianza del equipo; limita esa opción a un motor local administrado. No la uses para conexiones remotas sin validar TLS.

`00` crea la base solo si falta y desactiva `AUTO_CLOSE`; no borra/recrea bases. `01–05` crean objetos faltantes o aplican migraciones aditivas. `06` inserta solo fixtures SQL `TEST-*` en una transacción y revierte todo. Ejecutar 00–05 de nuevo comprueba idempotencia física. La carga no se realizó con estos scripts.

## Objetos y granos

- `audit.Batch`, `audit.Reject` y `audit.vw_BatchStatus`: estado, archivo/hash, versión de contrato, inicio/fin, conteos, error y rechazos trazables.
- Nueve tablas `stg`: columnas de origen más `row_id`, `batch_id`, `source_row_number` y `loaded_at`. Única clave física adicional: `(batch_id, source_row_number)`. Las claves crudas de negocio no tienen unicidad para conservar duplicados fuente.
- `dw.DimFecha`, `DimCliente`, `DimProducto`, `DimVendedor`, `DimGeografiaCliente` y `DimGeografiaVendedor`, cada una con miembro desconocido `-1`.
- `dw.FactPedidos`: una fila por `order_id`, incluye pedidos sin líneas.
- `dw.FactDetallePedido`: una fila por `(order_id, order_item_id)`. Ambas tablas tienen FK a sus dimensiones y no se relacionan directamente.

## Ciclo de lote para Poma

1. Calcular SHA-256 local y elegir versión de contrato. Consultar `audit.Batch` por fuente, archivo/hash y versión.
2. Si existe lote `COMPLETE` con esos mismos valores, omitir la ingesta sin crear otro lote.
3. Si no existe (archivo/hash diferente), insertar un nuevo lote `PENDING`. Nunca reutilizar el lote de otra versión/contenido.
4. Para lote `PENDING`, `RUNNING` incompleto o `FAILED`, iniciar una transacción; bloquear el registro del lote; mantener/poner `RUNNING`, establecer nuevo `started_at`, limpiar `finished_at`/error y reiniciar conteos; eliminar dentro de esa misma transacción las filas de ese `batch_id` de las nueve tablas y sus rechazos; cargar cada archivo con su ordinal físico estable como `source_row_number`. Un fallo revierte el reinicio y la recarga juntos; después se registra `FAILED` y `finished_at` en una transacción de auditoría separada.
5. Antes de confirmar, actualizar `rows_read`, `rows_accepted` y `rows_rejected`, con `rows_read >= accepted + rejected`. Clasificaciones pendientes pueden quedar en `PENDING`, `RUNNING` o `FAILED`. Cerrar `COMPLETE` solo cuando los tres conteos sean iguales; establecer `finished_at` en el mismo update. El trigger permite únicamente `PENDING→RUNNING/FAILED`, `RUNNING→COMPLETE/FAILED` y `FAILED→RUNNING`; un lote `COMPLETE` no se vuelve a ingerir.

La clave técnica evita reinsertar la misma fila ordinal del lote; diferentes filas fuente idénticas conservan ordinales distintos. No declarar `COMPLETE` mientras continúe una carga no clasificada. Esta es la interfaz para SSIS; los paquetes que la implementen aún no forman parte de este PR.

## Pruebas y estado observado

En la verificación local se ejecutaron los scripts 00–06 desde una base `BI_OLIST` inexistente, y luego se reejecutaron 00–05: ambos recorridos pasaron. `06` valida unicidad de staging en las nueve tablas, duplicados fuente conservados, duplicado de ordinal rechazado, transición y contadores de lotes, granos/FK de hechos, importes, fechas, casos negativos y rollback sintético. Los controles de 05 devolvieron cero filas porque no hay datos cargados en `stg` ni `dw`; eso no es evidencia de ETL.

Pendiente: carga SSIS real y conciliación de conteos, rechazos y agregados. SSAS Tabular, Power BI Live, capturas de integración y aprobación técnica del contrato permanecen pendientes. No se informan resultados de esos componentes.
