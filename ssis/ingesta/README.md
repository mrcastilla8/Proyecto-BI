# Ingesta Olist de CSV a staging

La solución `ETL_Olist_Ingesta/ETL_Olist_Ingesta.slnx` contiene el maestro y nueve paquetes de origen. Su ámbito termina en `BI_OLIST.stg` y `audit`. Las cargas dimensionales pertenecen a `ssis/transformaciones`.

## Generación y ejecución

El generador C# lee las definiciones de las nueve fuentes del contrato 1.0.0 y crea los paquetes con ManagedDTS y Pipeline Wrapper. Cada origen tiene su cabecera, metadatos y reglas de publicación propios. Windows debe disponer de Visual Studio con SSIS Projects, runtime de Integration Services 2025 x64, proveedor MSOLEDBSQL y herramientas de .NET Framework/VSTA.

Los parámetros de proyecto son String. Configura `CSV_ROOT` con el directorio local de entradas, `SQL_SERVER` con la instancia autorizada y `SQL_DATABASE` con el nombre de la base. Los dos primeros se distribuyen vacíos. La base predeterminada es `BI_OLIST`. Se utiliza autenticación integrada.

El maestro verifica los nueve archivos y la conexión SQL. Ejecuta las fuentes en este orden: Orders, OrderItems, OrderPayments, OrderReviews, Customers, Sellers, Products, Geolocation y CategoryTranslation. Una rama de error detiene la secuencia. El contrato contiene los nombres de los archivos y los destinos de cada fuente.

## Procesamiento y garantías

La tarea `Preparar CSV` asigna las cadenas de conexión al comenzar la ejecución. Conserva el ajuste de la variante T para `CM_SQL` y lo extiende a `CM_CSV`. La tarea auxiliar valida cabeceras, calcula el SHA-256 de los bytes originales y prepara una instantánea UTF-8 con ordinal lógico. Reconoce BOM, comillas escapadas, campos multilínea y EOF sin terminador. El flujo nativo SSIS usa Flat File Source, Data Conversion, Row Count y OLE DB Destination Fast Load para cargar `#FilasIngesta`. Reviews usa transporte largo Unicode para los comentarios. Geolocation conserva duplicados y convierte coordenadas al decimal del contrato. Los códigos postales conservan sus ceros y Products conserva `product_name_lenght` y `product_description_lenght`.

Las tareas SQL comprueban la sesión retenida y usan un bloqueo por fuente, hash y versión. La publicación valida los tipos y límites de destino, guarda los rechazos con el ordinal y concilia auditoría con staging antes de confirmar. La transacción incluye staging, rechazos y estado `COMPLETE`. Un fallo revierte las filas de esa publicación. El siguiente intento recuperable conserva el ID de lote. Los lotes ya completos se omiten.

La publicación trata como vacío el texto de cero bytes y conserva los espacios, incluidos los finales. Los campos de texto requeridos realmente vacíos se rechazan y se mantienen las validaciones específicas del contrato. Las pruebas de regresión usan `BI_OLIST_VALIDACION_TEXTO` en LocalDB para volver a leer los mismos archivos sin intervenir lotes históricos confirmados.

## Verificación y reproducción

- [Resultados de entrega](evidencias/informe/INFORME_ENTREGA.md)
- [Entrega de staging para Axel](HANDOFF_AXEL.md)
- [Índice de evidencias](evidencias/informe/INDICE_EVIDENCIAS.md)
- [Procedimiento reproducible para Windows](evidencias/informe/anexo-f/REPRODUCCION.md)

La compilación y las ejecuciones x64 pasaron en laboratorio. El maestro también terminó correctamente desde Visual Studio. La edición gráfica de ciertos componentes presentó cierres posteriores, detallados en la evidencia del diseñador.
