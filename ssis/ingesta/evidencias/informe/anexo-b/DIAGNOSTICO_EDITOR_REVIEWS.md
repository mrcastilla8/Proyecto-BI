# Diagnóstico del editor de conversión SSIS

**Aceptación del diseñador: BLOCKED.** El proyecto original compila y ejecuta. En este Windows, el editor de conversión provoca el cierre de Visual Studio 2026 18.10.3 con SSIS Projects 2.2. Hay una vía de mantenimiento verificada mediante las API de SSIS.

## Aislamiento del cierre

| Caso | Condición | Resultado observado |
| --- | --- | --- |
| Reviews final | Doble clic en `Decodificar UTF-8` | Evento 86413, `0xc0000409`, subcódigo `0xA`. |
| Sonda de dos columnas, apertura directa | Solo Flat File Source. Intento de insertar Conversión de datos desde el cuadro de herramientas | Evento 86420, `0xc0000409/0xA`. |
| La misma sonda dentro de una solución SSIS | Solo Flat File Source. Intento de inserción desde el diseñador nativo | Evento 86422, `0xc0000409/0xA`. |
| Reviews en otra instancia | Clic derecho sobre el conversor para buscar el editor avanzado | Eventos 86426 y 86428, `0xc0000005` y `0xc000041d`. |
| Customers, sin texto largo | Doble clic en `Decodificar UTF-8` | Evento 86432, `0xc0000409/0xA`. |

Para repetir el control mínimo, abre una copia de ensayo. Prepara un solo Data Flow con Flat File Source delimitado, calificador de texto con comillas, código de página 65001 y dos columnas sintéticas. En el ensayo la entrada fue `codigo` como `DT_STR` y `texto` como `DT_TEXT`. Elige **Conversión de datos** en el cuadro de herramientas e intenta agregarlo al flujo. La sonda carece de conexión a SQL, Script Task y conversor previo. El IDE cerró antes de que pudiera guardarse el control nativo equivalente. El guardado de un paquete Reviews existente desde Visual Studio sí permitió cotejar su serialización con el original.

`.exr -1` y SOS confirmaron `FAST_FAIL_GUARD_ICALL_CHECK_FAILURE`. La pila administrada de ambas sondas contiene `Marshal.CleanupUnusedObjectsInCurrentContext` y `VsRcwCleanupPrivate.CleanUpUnReachableRCWs`. En Customers contiene `AccessibleObject.WrapIAccessible` y `IAccessible.get_accParent`. El fallo se observó en las rutas COM y de accesibilidad del IDE durante las pruebas automatizadas. La conversión generada, la escritura en SQL y el texto largo de Reviews quedan descartados como requisitos para el cierre. El objeto COM o destino de la llamada indirecta siguió sin identificarse y queda por confirmar el comportamiento con interacción manual sin la automatización de escritorio. [Volcado inicial de Reviews](reviews-diagnostico.txt).

## Metadatos y mantenimiento verificado

Se cargó Reviews con ManagedDTS y Pipeline Wrapper. Cada salida resuelve su `SourceInputColumnLineageID` a la entrada y columna de origen correspondientes. Las siete salidas se mapean a las columnas esperadas de OLE DB. El mensaje usa `DT_TEXT` (65001) → `DT_NTEXT`. El título y las otras cinco columnas usan `DT_STR` (65001) → `DT_WSTR`. El modelo entregó los mismos resultados al leer el paquete original, su guardado desde Visual Studio y la copia guardada por API. No se cambió el generador ni se regeneraron los paquetes entregados.

La vía de mantenimiento probada abre el objeto `IDTSComponentMetaData100`, modifica una descripción en una copia, guarda mediante `Application.SaveToXml`, vuelve a cargar y verifica las siete conversiones. El proyecto de ensayo compiló, DTExec ejecutó dos veces con salida 0 y el lote sintético 40033 terminó con 6 leídas, 5 aceptadas y 1 rechazada. SQL verificó por SHA-256 un mensaje de 4.000 unidades UTF-16 con comillas y CRLF, el título NULL y una fila adicional con Unicode. Para ajustes de tipos debe repetirse la validación de las salidas y sus mapeos con el contrato. [Procedimiento](../anexo-f/REPRODUCCION.md#inspeccionar-y-mantener-la-conversión-de-reviews) y [salida comprobada](reviews-metadatos-y-fixture.txt).

## Revisión gráfica y regresión

Se abrieron los diez paquetes en una copia de la solución y se comprobó el guardado de Master, Customers y Reviews tras usar sus editores de tareas Script. Orders ya tenía verificación de edición y persistencia en VSTA. En los otros seis se comprobó la apertura, sin acreditar una edición de sus conversores. En Reviews se abrió el Data Flow, se guardó desde el flujo de control, se cerró y reabrió. La ejecución individual desde Visual Studio terminó por la ruta de lote ya completo y volvió al diseñador. Los editores de conversión de Reviews y Customers siguen sin aprobar. [Ejecución](reviews-ejecucion.png) y [regreso](reviews-regreso.png).

La copia de los paquetes entregados compiló con cero errores. Dos ejecuciones del maestro y dos directas de Reviews devolvieron 0 con DTExec x64. SQL confirmó 1.550.922 filas, los nueve lotes originales y 99.224 filas en Reviews con 3.852 registros multilínea. La comparación de lotes conservó fechas y conteos. Solo se usó la LocalDB aislada. [Resultados](reviews-regresion.txt).

La comparación de huellas SHA-256 UTF-16LE por ordinal abarcó ambos campos de texto de las 99.224 reseñas. Coincidieron 198.411 de 198.448 campos con equivalencia entre cadena vacía del CSV y NULL de SQL. Las 37 diferencias restantes fueron 10 títulos y 27 comentarios cuyo valor no vacío fue publicado como NULL. Una consulta con la misma intercalación confirmó los 37 casos al aplicar el `NULLIF(valor,N'')` que usa la publicación existente. Once eran un solo espacio ASCII. Este comportamiento ya estaba presente en el lote auténtico 40014. El lote y la regla compartida se conservaron durante el diagnóstico. [Comparación agregada](reviews-texto-autentico.txt).

En la entrega de integridad posterior, la publicación cambió a longitud exacta y los 37 valores se recuperaron byte por byte en el lote 4 de `BI_OLIST_VALIDACION_TEXTO`. La sonda y la incidencia del editor siguen abiertas. La interacción manual sin automatización no se pudo ejecutar desde esta sesión. [Resultado corregido](texto-reviews-antes-despues.txt) y [verificación de las nueve fuentes](texto-integridad.txt).

El registro auténtico de DTExec queda disponible como sustituto documental de CAP-11. La herramienta de escritorio disponible no permite automatizar la terminal. Google Docs quedó intacto.
