# Contrato de datos v1

`contracts/modelo-dimensional.v1.json` es un **contrato preliminar**; el estado de ambos contratos sigue `PROPUESTA_PENDIENTE_VALIDACION`. El repositorio no contiene los nueve CSV auténticos. Por ello, encabezados basados en el esquema esperado, tipos, longitudes, nulabilidad, conversiones y reglas que dependen de los datos no están confirmados. No fijar parseo SSIS ni DDL definitivo antes de inspeccionar los archivos autorizados. Fixtures sintéticas prueban solo la estructura de este borrador.

## Fuentes, staging y tipos propuestos

| Archivo | Tabla propuesta | Columnas y tipos SQL propuestos |
|---|---|---|
| `olist_orders_dataset.csv` | `stg.Orders` | `order_id VARCHAR(64)`, `customer_id VARCHAR(64)`, `order_status VARCHAR(32)`, `order_purchase_timestamp DATETIME2(0)`, `order_approved_at DATETIME2(0) NULL`, `order_delivered_carrier_date DATETIME2(0) NULL`, `order_delivered_customer_date DATETIME2(0) NULL`, `order_estimated_delivery_date DATETIME2(0)` |
| `olist_order_items_dataset.csv` | `stg.OrderItems` | `order_id VARCHAR(64)`, `order_item_id INT`, `product_id VARCHAR(64)`, `seller_id VARCHAR(64)`, `shipping_limit_date DATETIME2(0)`, `price DECIMAL(19,4)`, `freight_value DECIMAL(19,4)` |
| `olist_order_payments_dataset.csv` | `stg.OrderPayments` | `order_id VARCHAR(64)`, `payment_sequential INT`, `payment_type VARCHAR(32)`, `payment_installments INT`, `payment_value DECIMAL(19,4)` |
| `olist_order_reviews_dataset.csv` | `stg.OrderReviews` | `review_id VARCHAR(64)`, `order_id VARCHAR(64)`, `review_score TINYINT NULL`, `review_comment_title NVARCHAR(1000) NULL`, `review_comment_message NVARCHAR(4000) NULL`, `review_creation_date DATETIME2(0) NULL`, `review_answer_timestamp DATETIME2(0) NULL` |
| `olist_customers_dataset.csv` | `stg.Customers` | `customer_id VARCHAR(64)`, `customer_unique_id VARCHAR(64)`, `customer_zip_code_prefix CHAR(5)`, `customer_city NVARCHAR(200)`, `customer_state CHAR(2)` |
| `olist_sellers_dataset.csv` | `stg.Sellers` | `seller_id VARCHAR(64)`, `seller_zip_code_prefix CHAR(5)`, `seller_city NVARCHAR(200)`, `seller_state CHAR(2)` |
| `olist_products_dataset.csv` | `stg.Products` | `product_id VARCHAR(64)`, `product_category_name NVARCHAR(200) NULL`, `product_name_length INT NULL`, `product_description_length INT NULL`, `product_photos_qty INT NULL`, `product_weight_g DECIMAL(12,3) NULL`, `product_length_cm DECIMAL(12,3) NULL`, `product_height_cm DECIMAL(12,3) NULL`, `product_width_cm DECIMAL(12,3) NULL` |
| `olist_geolocation_dataset.csv` | `stg.Geolocation` | `geolocation_zip_code_prefix CHAR(5)`, `geolocation_lat DECIMAL(12,8)`, `geolocation_lng DECIMAL(12,8)`, `geolocation_city NVARCHAR(200)`, `geolocation_state CHAR(2)` |
| `product_category_name_translation.csv` | `stg.ProductCategoryTranslation` | `product_category_name NVARCHAR(200)`, `product_category_name_english NVARCHAR(200)` |

La lista también está en `staging_sources` del JSON. Validar encabezados y cobertura contra cada archivo real; ajustar longitudes/escala/nulabilidad mediante PR y revisión de los afectados antes de congelar. CSV de reseñas contiene texto: conservarlo solo si la privacidad, codificación y alcance académico lo justifican; de otro modo proponer exclusión documentada, nunca truncarlo silenciosamente.

## Claves y granos propuestos

- Staging preserva las columnas fuente, añade identificador/fecha de lote y metadatos de auditoría fuera del contenido fuente. Claves candidatas: `order_id`; `(order_id, order_item_id)`; `(order_id, payment_sequential)`; `review_id`; `customer_id`; `seller_id`; `product_id`; traducción por `product_category_name`. La geolocalización no tiene clave natural confirmada en este borrador.
- `dw.FactPedidos`: una fila por `order_id`, incluidos pedidos sin líneas. `order_id` es clave de negocio/degenarada; las dimensiones referenciadas usan claves sustitutas. `payment_value` y reviews se reducen primero a una fila por pedido; no unir detalles crudos al hecho.
- `dw.FactDetallePedido`: una fila por `(order_id, order_item_id)`, con clave sustituta y restricción única de negocio. Claves foráneas a pedido/cliente/producto/vendedor/roles geográficos/fecha según modelo aprobado. No se relacionan directamente los hechos.
- `DimCliente` se identifica analíticamente por `customer_unique_id`, mientras `customer_id` relaciona el pedido de origen con la fila de cliente por pedido. Confirmar cardinalidad con los CSV. Geografía cliente y vendedor son roles separados.

## Reglas de calidad y agregación propuestas

- Distinguir campo vacío, NULL y valor inválido. Mantener nulos de origen cuando sean legítimos; valores no parseables o referencias huérfanas se registran con lote, archivo/fila/campo/motivo y se rechazan a cuarentena sin coerción silenciosa.
- Duplicados exactos de archivo y duplicados de clave se cuentan y reportan. No elegir arbitrariamente entre filas conflictivas: rechazo para revisión. Claves foráneas faltantes usan miembro desconocido explícito solo para atributos dimensionales opcionales, con auditoría; una referencia obligatoria a pedido/línea inválida se rechaza.
- Pagos: sumar `payment_value` por `order_id` solo para la medida total de pagos del hecho de pedidos; conservar método/cuotas/secuencias en staging y no presentar ese total como venta de producto. Confirmar si pagos duplicados o cancelaciones requieren otra semántica.
- Reseñas: proponer promedio de `review_score` válido por pedido, una observación por pedido. Definir rango y regla de múltiples `review_id` después de inspección; no ponderar por líneas.
- `customer_id` identifica registro ligado a pedido; `customer_unique_id` identifica cliente analítico recurrente. No sustituir uno por el otro en cargas ni joins.
- Geolocalización: múltiples filas por prefijo son posibles y están ilustradas sintéticamente. No hacer join directo que multiplique clientes/pedidos. Hasta aprobar regla reproducible (por ejemplo, una coordenada determinista por prefijo y estado con trazabilidad), geolocation solo queda en staging y no alimenta hechos/dimensiones.
- Importe `DECIMAL`, fechas `DATETIME2`; nunca float para dinero. Las escalas y rangos son provisionales hasta perfilado local de CSV auténticos.

## Carga repetible e interfaz SSIS → DW

Propuesta de ejecución: asignar `batch_id` persistido en `audit`; registrar inicio/fin, fuente, hash/fecha de archivo, filas leídas, aceptadas/rechazadas, error y estado. Cargar staging por lote; una repetición del mismo lote debe reemplazar atómicamente ese lote o borrar/reinsertar por claves bajo transacción, con política elegida y probada antes de implementar. DW usa claves únicas de negocio y upsert/transacción idempotente; no insertar de nuevo por reintento. Registrar fallos y permitir reanudar desde último paso confirmado. Estos son requisitos, no comportamiento implementado.

Interfaz mínima: Poma entrega las nueve tablas `stg` tipadas, con claves candidatas, `batch_id`, conteos y rechazos consultables; Cueva consume únicamente lotes completos/validados, agrega pagos y reviews al grano pedido, informa claves huérfanas/filas descartadas y mantiene los dos granos. Castilla aprueba DDL/controles; cambios incompatibles requieren issue, versión mayor del contrato, ADR y revisión de Poma/Cueva/Basualdo/Ángel según impacto. Cambios aditivos compatibles requieren versión menor; correcciones editoriales/metadatos sin semántica, parche. Registrar versión consumida por cada componente.

## Congelación y aprobación

Hasta inspeccionar los nueve CSV, registrar encabezados observados, codificación, delimitador, quoting, formato decimal/fechas, nulos, rangos, claves/duplicados y multiplicidades, **no congelar tipos ni columnas**. Cualquier perfil se ejecuta localmente y se comparte como evidencia redactada, sin adjuntar datos reales. Para mover ambos JSON a `APROBADO`, abrir issue/PR con versión y evidencia de validación, obtener aprobación humana en PR de Castilla y de al menos dos revisores de los equipos afectados, y completar los campos `approval` de ambos contratos (fecha, issue, PR y revisores). Una edición de estado sola no aprueba el contrato. `python scripts/validar_base.py` verifica que estados sean permitidos y coherentes.
