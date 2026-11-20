# SSIS: staging a Data Mart
Responsable Cueva (`@AXL031`), rama `cueva/ssis-transformaciones`, [issue #2](https://github.com/mrcastilla8/Proyecto-BI/issues/2). El [proyecto SSIS independiente](ETL_Olist_Transformacion/ETL_Olist_Transformacion.slnx) ejecuta `dw.usp_CargarOlist` mediante una tarea Ejecutar SQL. El procedimiento valida staging, carga dimensiones y hechos y cierra la auditoría dentro de una transacción de SQL Server.

## Preparación y ejecución

1. En Windows, usa Visual Studio 2026 con SSIS Projects, DTExec x64 17.x, el proveedor OLE DB MSOLEDBSQL19 y SQL Server 2025. Confirma la instancia y el catálogo con autenticación Windows. En una base nueva, aplica primero el [DDL aprobado](../../database/README.md). En una base con staging cargado, revisa los lotes con la consulta de la [entrega de ingesta](../ingesta/HANDOFF_AXEL.md).
2. Instala el procedimiento con una cuenta con permisos de DDL. La cuenta que ejecuta el paquete necesita acceso al catálogo, permiso `EXECUTE` sobre `dw.usp_CargarOlist` y los permisos sobre objetos que requiera la configuración local de propietarios.

   ```powershell
   sqlcmd -S $instancia -d BI_OLIST -E -b -f 65001 -i ssis/transformaciones/sql/cargar.sql
   ```

3. Abre la solución en una copia local ignorada por Git y configura `Project.params`. En `SQL_CONNECTION` usa `Provider=MSOLEDBSQL19;Data Source=<instancia>;Initial Catalog=BI_OLIST;Integrated Security=SSPI;Use Encryption for Data=Mandatory;`. En un laboratorio local con certificado autofirmado, agrega `Trust Server Certificate=True` solo para la instancia verificada. En `LOTS_JSON` indica un objeto compacto de hasta 400 caracteres con un ID numérico por fuente. Obtén los IDs de un único conjunto de archivos verificado antes de publicar.

   ```json
   {"Orders":7,"OrderItems":8,"OrderPayments":9,"OrderReviews":10,"Customers":11,"Sellers":12,"Products":13,"Geolocation":14,"ProductCategoryTranslation":15}
   ```

   Estos IDs corresponden al entorno documentado por Poma. Consulta `audit.vw_BatchStatus` para localizar los IDs en otra instancia.

4. Compila `Development` y ejecuta `ETL_Transformar.dtsx` desde Visual Studio o con DTExec. Desde la carpeta que contiene el `.ispac`, ejecuta `DTExec /Project ETL_Olist_Transformacion.ispac /Package ETL_Transformar.dtsx /Reporting EWI`. Conserva el código de retorno y el registro de ejecución.

## Política de carga y recuperación

- Cada ejecución recibe un conjunto completo de nueve lotes `COMPLETE` de la versión 1.0.0 y coteja sus conteos. La publicación sincroniza ambos hechos con ese conjunto. Actualiza por clave natural, inserta claves nuevas y retira de los hechos las claves ausentes. Las dimensiones conservan claves sustitutas y miembros existentes. Los atributos de producto se actualizan con los valores del conjunto publicado.
- `FactPedidos` conserva todos los pedidos y las fechas nulas. `FactDetallePedido` conserva una fila por `(order_id, order_item_id)`. Los pagos se suman y las reseñas válidas se promedian por `order_id` por separado. Se conservan las reseñas con `review_id` repetido. Las referencias dimensionales ausentes usan `-1`. La geografía usa ciudad y estado de clientes y vendedores. El lote de `Geolocation` se concilia sin unirlo al DW. [Contrato dimensional](../../contracts/modelo-dimensional.v1.json) · [Contrato de métricas](../../contracts/metricas.v1.json)
- Las claves inválidas o duplicadas, las líneas, pagos o reseñas sin pedido y las diferencias de lote o conteo abortan la publicación. Una puntuación no nula fuera de 1 a 5 se registra y se excluye del promedio. La transacción usa un bloqueo de aplicación para serializar publicaciones.
- `audit.Batch` registra cada intento con `source_name = 'DW.Transformacion'` y los IDs en `execution_context`. Los conteos de un intento confirmado clasifican las filas de staging conciliadas. `audit.Reject` conserva causa, fuente y ordinal cuando corresponde. Si SQL Server detecta un error durante la publicación, revierte la transacción y registra el intento como `FAILED`. Una interrupción abrupta puede dejar un intento `RUNNING`. Revisa la conexión y el último intento `COMPLETE` antes de reintentar. Cada reintento tiene su propio registro de auditoría.

## Verificación en Windows

1. **Laboratorio sintético.** Crea una instancia LocalDB dedicada con un `BI_OLIST` nuevo, aplica el DDL y el procedimiento y ejecuta `sqlcmd -S $instancia -d BI_OLIST -E -b -f 65001 -i ssis/transformaciones/sql/fixtures.sql`. Guarda los dos JSON que devuelve el script.
2. **Primera carga y reejecución.** Usa `lotes_validos`, ejecuta el paquete y corre `sqlcmd -S $instancia -d BI_OLIST -E -b -f 65001 -i ssis/transformaciones/sql/conciliar.sql`. Repite con los mismos parámetros. Ambos intentos deben quedar `COMPLETE`, con 3 pedidos, 3 líneas, pagos de 14,5000, precio de 35,0000, flete de 6,0000 y una calificación media de 3,0000 entre 2 pedidos con reseña. Se espera un rechazo de puntaje por intento y las mismas ocho huellas de datos en ambas ejecuciones.
3. **Fallo y recuperación.** Configura `lotes_con_huerfano` y vuelve a compilar si usas DTExec. Ejecuta y espera un fallo con código SQL 52006, un intento `FAILED` y un rechazo `LINEA_INVALIDA`. Vuelve a conciliar el DW y compara las huellas con las de la carga válida. Repite con `lotes_validos` y comprueba que vuelve a registrar `COMPLETE`.
4. **Datos auténticos.** Ejecuta dos veces el conjunto de lotes aprobado para el destino y repite la conciliación. Guarda versiones, códigos de retorno, conteos y huellas sin publicar filas fuente ni cadenas de conexión. Ejecuta también `python scripts/validar_base.py`.

## Evidencia de esta entrega

- Windows con Python 3.14.8. `python scripts/validar_base.py` pasó y `python -m unittest discover -s scripts -p 'test_*.py' -v` pasó las 14 pruebas.
- El analizador T-SQL de Microsoft ScriptDom 170.191.0, con `TSql170Parser`, aceptó `cargar.sql`, `conciliar.sql` y `fixtures.sql`. Se comprobó la coherencia de referencias y parámetros del XML del proyecto.
- `Get-Command sqlcmd,dtexec,sqllocaldb` no devolvió ejecutables. La consulta de servicios no encontró SQL Server o SSIS y `vswhere.exe` no estaba en la ruta del instalador. Quedan pendientes compilar la solución en Visual Studio y ejecutar las pruebas sintética y auténtica.
