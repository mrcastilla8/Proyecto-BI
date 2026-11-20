# Entrega local del Issue #1

**Entrega actual. Funcionalidad ETL: PASS. Integridad de datos: PASS. Edición visual: BLOCKED.** La revisión de integridad se hizo con una carga desde cero en `BI_OLIST_VALIDACION_TEXTO` de la misma LocalDB aislada. Los nueve lotes históricos y la base principal quedaron intactos. El editor de conversión de Visual Studio sigue sin verificación de estabilidad. La captura directa de DTExec queda pendiente y se conserva el registro auténtico.

## Corrección de integridad

`Publicacion.cs` ahora convierte a NULL únicamente el texto cuya `DATALENGTH` sea cero y conserva espacios en texto opcional y requerido. Un campo requerido realmente vacío se rechaza. Se conservan las reglas de prefijos postales, números, fechas, tamaños y representabilidad. El actualizador SSIS sustituyó solo las tareas de publicación, preparación del catálogo y comprobación del maestro. El Data Flow, los linajes, los parámetros, los IDs de tareas y la topología se comprobaron sin diferencias. [Procedimiento](anexo-f/REPRODUCCION.md).

La solución publicable compiló con un proyecto correcto y cero errores. El `.ispac` contiene diez paquetes. DTExec x64 devolvió 0 para la carga auténtica desde cero (69,19 s) y para su reejecución. Se obtuvieron 1.550.922 leídas y aceptadas, 0 rechazos y nueve lotes `COMPLETE`. La consulta inicial de conciliación requirió agregar la vista aprobada del DDL 05 en el laboratorio nuevo. Después, las salidas SQL anteriores y posteriores a la reejecución resultaron idénticas. [Compilación, DTExec y lotes nuevos](anexo-b/texto-carga.txt).

La comparación de cada fila por ordinal, longitud y SHA-256 verificó las nueve fuentes. En el histórico, únicamente Reviews tenía diferencias. El lote nuevo de Reviews, ID 4, restauró los 10 títulos y 27 comentarios que eran NULL en el lote 40014. Quedaron cero diferencias en 1.550.922 filas. Se verificaron los duplicados, los nulos legítimos y las fixtures de vacío, espacios, Unicode, comillas y saltos. El lote sintético 19 quedó `FAILED` tras la inyección y volvió a `COMPLETE` con el mismo ID, 9 leídas, 8 aceptadas y 1 rechazada. [Integridad global](anexo-b/texto-integridad.txt), [antes y después de Reviews](anexo-b/texto-reviews-antes-despues.txt) y [rollback y recuperación](anexo-b/texto-recuperacion.txt).

La última comparación manual sin automatización no fue posible desde esta sesión. La revisión anterior reprodujo el cierre mediante automatización al insertar un conversor nativo en una sonda mínima y al abrir el conversor de Customers. La edición por API sigue disponible. [Diagnóstico del editor](anexo-b/DIAGNOSTICO_EDITOR_REVIEWS.md).

Las secciones siguientes conservan la trazabilidad de la entrega inicial. Sus IDs de lote y capturas identifican el laboratorio histórico.

## A y B. Implementación y generación

Se conservó la solución existente y se respaldó el estado local antes de reconciliar el proyecto, los parámetros y el paquete Orders. El `Package.dtsx` local vacío quedó preservado junto con los inventarios y hashes en el directorio ignorado de ensayo. El generador C# usa ManagedDTS y Pipeline Wrapper con metadatos del contrato 1.0.0. Crea nueve Data Flow nativos y el maestro. Cada flujo tiene sus propios campos, tipos, reglas y destino. Los scripts compartidos parametrizan las conexiones, capturan ordinales, calculan SHA-256 y preparan la instantánea que lee Flat File Source. El destino OLE DB carga `#FilasIngesta` y las tareas SQL publican al destino contractual con auditoría.

## C. Compilación y ejecución

- `devenv.com /Build Development` devolvió 0, con un proyecto correcto y cero errores. Se inspeccionaron los diez paquetes, parámetros y manifiesto dentro del `.ispac`. [Compilación](anexo-f/compilacion.txt).
- Los nueve paquetes ejecutaron fixtures individualmente con código 0 y el maestro sintético ejecutó dos veces con código 0. La primera carga auténtica tardó 84,41 s y su repetición 7,42 s. Tras trasladar también la configuración de `CM_CSV` a ejecución, el maestro final repitió dos veces en 5,71 y 6,35 s con los lotes íntegros. Una copia recién compilada del proyecto publicable volvió a pasar en 6,84 y 6,64 s. [DTExec x64](anexo-b/ejecucion-dtexec.txt) y [tiempos por paquete con fixtures](anexo-b/tiempos-fixtures.txt).
- Desde Visual Studio se abrió la solución, se inspeccionaron flujos, se completó el maestro final sobre los nueve lotes ya cargados y se regresó al diseñador. La ejecución gráfica demuestra el recorrido de omisión de lotes completos. [Ejecución gráfica](6.1.3-ejecucion/CAP-10-maestro-exitoso.png) y [retorno](anexo-b/retorno-al-disenador.png).

## D. Resultados auténticos

Los paquetes individuales aprobaron las fixtures. Los conteos auténticos proceden de la conciliación SQL por hash y lote. El ordinal abarca de 1 al número de registros en las nueve fuentes. El tiempo SQL es la diferencia entre las marcas de inicio y cierre del lote a resolución de un segundo. La preparación del CSV y fases previas quedan fuera de ese intervalo.

| Fuente | Lote | Estado | Leídas | Aceptadas | Rechazadas | Tiempo SQL aprox. |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| Orders | 40011 | COMPLETE | 99.441 | 99.441 | 0 | 1 s |
| OrderItems | 40012 | COMPLETE | 112.650 | 112.650 | 0 | <1 s |
| OrderPayments | 40013 | COMPLETE | 103.886 | 103.886 | 0 | 1 s |
| OrderReviews | 40014 | COMPLETE | 99.224 | 99.224 | 0 | <1 s |
| Customers | 40015 | COMPLETE | 99.441 | 99.441 | 0 | <1 s |
| Sellers | 40016 | COMPLETE | 3.095 | 3.095 | 0 | <1 s |
| Products | 40017 | COMPLETE | 32.951 | 32.951 | 0 | <1 s |
| Geolocation | 40018 | COMPLETE | 1.000.163 | 1.000.163 | 0 | 5 s |
| CategoryTranslation | 40019 | COMPLETE | 71 | 71 | 0 | <1 s |
| **Total** | | | **1.550.922** | **1.550.922** | **0** | |

[Integridad SQL](anexo-b/integridad.txt), [huellas y perfil CSV](anexo-b/perfil-autentico.json) y [fechas SQL](anexo-b/primera-consulta.txt).

## E. Auditoría y recuperación

- Cada fuente sintética produjo un rechazo controlado con código, campo y ordinal. La variante corregida previa de Orders volvió a registrar 3 leídas, 2 aceptadas y 1 rechazada, con el mismo lote y ordinal de rechazo en las dos ejecuciones. [Fixtures](anexo-b/fixtures.txt).
- La falla inyectada después de escribir en Orders hizo fallar el maestro con código 1 y detuvo el recorrido antes de la carga posterior. El lote 40031 pasó a FAILED, error `PUBLICAR/51999`, sin filas persistidas. Tras reejecutar pasó a COMPLETE con 5 leídas, 4 aceptadas y 1 rechazada. [Rollback](anexo-b/rollback.txt) y [recuperación](anexo-b/recuperacion.txt).
- La segunda sesión retuvo el bloqueo de Orders. DTExec devolvió 1 y `BATCH_LOCK_TIMEOUT`. El lote auténtico 40011 conservó fechas y conteos. Las dos conciliaciones auténticas completas coincidieron en identidad, fechas, estado y conteos. [Contención](anexo-b/concurrencia.txt) y [segunda consulta](anexo-b/segunda-consulta.txt).

## F. Datos y rendimiento

Reviews preservó 3.852 registros multilínea y 814 repeticiones de `review_id`. Un comentario sintético de 4.000 unidades UTF-16, con Unicode, comillas, coma y CRLF, conservó su huella y el título NULL. Geolocation preservó 261.831 duplicados exactos adicionales y escribió 1.000.163 filas mediante Fast Load. Su fase Execute tomó unos 11,12 s, sin medición de memoria máxima. Orders conservó 160 aprobaciones, 1.783 fechas de transporte y 2.965 fechas de entrega final nulas. Customers conservó 23.995 prefijos con cero inicial. Los destinos publican mediante los tipos y escalas del contrato. [Integridad](anexo-b/integridad.txt) y [Geolocation](anexo-b/geolocation.txt).

## G. Evidencias y limitación del diseñador

El índice reúne 19 imágenes comprobadas y los registros de los anexos B y F. El editor de la conexión de origen reprodujo `0xc0000409` en la variante que usaba expresión en `CM_CSV.ConnectionString`. Se eliminó esa expresión y se verificó de nuevo la ejecución. Se abrió `ScriptMain.cs` de Orders en VSTA, se modificó un comentario, se guardó, se cerró y se reabrió el paquete. Se comprobó que el comentario quedó en la copia de ensayo y que el paquete publicable conservó su SHA-256. [Índice de evidencias](INDICE_EVIDENCIAS.md), [guardado VSTA](anexo-b/vsta-orders-guardado.png) y [reapertura](anexo-b/vsta-orders-reapertura.png).

La primera revisión del flujo Reviews registró `0xc0000005` y `0xc000041d` en `combase.dll`. En otro inicio se reprodujo el cierre al abrir el editor de `Decodificar UTF-8`. El volcado de esa ejecución confirmó `0xc0000409`, subcódigo `0xA`. SOS sitúa la detención en la limpieza de objetos COM de Visual Studio. Con los símbolos y el minivolcado disponibles no se identificó el objeto concreto ni una corrección verificada para ese editor. [Eventos del diseñador](anexo-b/visual-studio-eventos.txt) y [diagnóstico del volcado de Reviews](anexo-b/reviews-diagnostico.txt).

## H. Git, documentación y SQL principal

La entrega incluye los diez paquetes, proyecto y parámetros portables, fuentes del generador, scripts de validación y evidencias seleccionadas. La validación base usa el inventario de Git para seguir comprobando archivos versionados y nuevos publicables, con las copias ignoradas fuera del recorrido. Pasaron `python scripts/validar_base.py`, las 14 pruebas Python existentes y `git diff --check`.

Las pruebas con escrituras apuntaron a la LocalDB aislada `(localdb)\BI_OLIST_ISSUE1_PROTO`, SQL Server 17.0.4025.3. La base principal se consultó en modo de lectura y conservó los conteos iniciales de nueve tablas staging y dos tablas de auditoría. No recibió escrituras de la implementación ni de las pruebas. El Issue sigue abierto y no se hizo push, PR ni merge. [Verificación de la principal](anexo-b/principal-solo-lectura.txt) y [reproducción](anexo-f/REPRODUCCION.md).

## I. Informe académico

Google Docs no fue modificado. Las evidencias de Gabriel quedaron preparadas para su posterior incorporación.
