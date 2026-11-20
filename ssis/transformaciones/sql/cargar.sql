CREATE OR ALTER PROCEDURE dw.usp_CargarOlist
    @Lotes nvarchar(400)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT <> 0 OR (@@OPTIONS & 2) = 2
        THROW 52000, N'Usa una conexión sin transacción externa ni transacciones implícitas.', 1;

    DECLARE @Ejecucion bigint, @Bloqueo int, @Leidas bigint = 0, @Rechazadas bigint = 0;
    DECLARE @Rechazos table (
        fuente nvarchar(260) NOT NULL, ordinal bigint NULL, campo sysname NULL,
        codigo varchar(64) NOT NULL, motivo nvarchar(1000) NOT NULL
    );
    DECLARE @Entrada table (
        fuente sysname PRIMARY KEY, lote bigint NULL, filas bigint NULL
    );

    INSERT audit.Batch(source_name, contract_version, status, execution_context)
    VALUES (N'DW.Transformacion', '1.0.0', 'RUNNING', @Lotes);
    SET @Ejecucion = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC @Bloqueo = sys.sp_getapplock @Resource=N'BIOLIST:dw:transformacion',
            @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=10000;
        IF @Bloqueo < 0 THROW 52001, N'No se pudo obtener el bloqueo de publicación del DW.', 1;

        IF ISNULL(ISJSON(@Lotes, OBJECT), 0) <> 1
            THROW 52002, N'LOTS_JSON debe ser un objeto JSON con los nueve IDs de lote.', 1;

        INSERT @Entrada(fuente)
        VALUES (N'Orders'), (N'OrderItems'), (N'OrderPayments'), (N'OrderReviews'), (N'Customers'),
               (N'Sellers'), (N'Products'), (N'Geolocation'), (N'ProductCategoryTranslation');

        IF (SELECT COUNT(*) FROM OPENJSON(@Lotes)) <> 9 OR EXISTS (
            SELECT e.fuente FROM @Entrada AS e
            LEFT JOIN OPENJSON(@Lotes) AS j
                ON e.fuente COLLATE Latin1_General_100_BIN2 = j.[key] AND DATALENGTH(e.fuente) = DATALENGTH(j.[key])
            GROUP BY e.fuente
            HAVING COUNT(j.[key]) <> 1
                OR MIN(CASE WHEN j.[type] = 2 AND TRY_CONVERT(bigint, j.[value]) > 0 THEN 1 ELSE 0 END) <> 1
        )
            THROW 52002, N'Indica exactamente un ID entero positivo por fuente, con el nombre contractual.', 1;

        UPDATE e SET lote = TRY_CONVERT(bigint, j.[value])
        FROM @Entrada AS e JOIN OPENJSON(@Lotes) AS j
            ON e.fuente COLLATE Latin1_General_100_BIN2 = j.[key];

        UPDATE e SET filas = b.rows_accepted
        FROM @Entrada AS e JOIN audit.Batch AS b WITH (HOLDLOCK)
            ON b.batch_id = e.lote AND b.source_name = e.fuente
        WHERE b.status = 'COMPLETE' AND b.contract_version = '1.0.0';

        INSERT @Rechazos
        SELECT fuente, NULL, N'batch_id', 'LOTE_NO_DISPONIBLE',
               CONCAT(N'El lote ', lote, N' no está COMPLETE para esta fuente y versión.')
        FROM @Entrada WHERE filas IS NULL;
        IF @@ROWCOUNT > 0 THROW 52003, N'Hay lotes ausentes, de otra fuente o versión, o sin confirmar.', 1;

        DECLARE @Orders bigint = (SELECT lote FROM @Entrada WHERE fuente = N'Orders'),
                @Items bigint = (SELECT lote FROM @Entrada WHERE fuente = N'OrderItems'),
                @Payments bigint = (SELECT lote FROM @Entrada WHERE fuente = N'OrderPayments'),
                @Reviews bigint = (SELECT lote FROM @Entrada WHERE fuente = N'OrderReviews'),
                @Customers bigint = (SELECT lote FROM @Entrada WHERE fuente = N'Customers'),
                @Sellers bigint = (SELECT lote FROM @Entrada WHERE fuente = N'Sellers'),
                @Products bigint = (SELECT lote FROM @Entrada WHERE fuente = N'Products'),
                @Geolocation bigint = (SELECT lote FROM @Entrada WHERE fuente = N'Geolocation'),
                @Translation bigint = (SELECT lote FROM @Entrada WHERE fuente = N'ProductCategoryTranslation');

        SELECT source_row_number, order_id, customer_id, order_status, order_purchase_timestamp,
               order_estimated_delivery_date, order_delivered_customer_date,
               COUNT_BIG(*) OVER (PARTITION BY order_id) AS multiplicidad
        INTO #Pedidos FROM stg.Orders WITH (HOLDLOCK) WHERE batch_id = @Orders;

        SELECT source_row_number, order_id, order_item_id, product_id, seller_id, price, freight_value,
               COUNT_BIG(*) OVER (PARTITION BY order_id, order_item_id) AS multiplicidad
        INTO #Lineas FROM stg.OrderItems WITH (HOLDLOCK) WHERE batch_id = @Items;

        SELECT source_row_number, order_id, payment_sequential, payment_value,
               COUNT_BIG(*) OVER (PARTITION BY order_id, payment_sequential) AS multiplicidad
        INTO #Pagos FROM stg.OrderPayments WITH (HOLDLOCK) WHERE batch_id = @Payments;

        SELECT source_row_number, order_id, review_score
        INTO #Resenas FROM stg.OrderReviews WITH (HOLDLOCK) WHERE batch_id = @Reviews;

        SELECT source_row_number, customer_id, customer_unique_id, customer_city, customer_state,
               COUNT_BIG(*) OVER (PARTITION BY customer_id) AS multiplicidad
        INTO #Clientes FROM stg.Customers WITH (HOLDLOCK) WHERE batch_id = @Customers;

        SELECT source_row_number, seller_id, seller_city, seller_state,
               COUNT_BIG(*) OVER (PARTITION BY seller_id) AS multiplicidad
        INTO #Vendedores FROM stg.Sellers WITH (HOLDLOCK) WHERE batch_id = @Sellers;

        SELECT source_row_number, product_id, product_category_name, product_name_lenght,
               product_description_lenght, product_photos_qty, product_weight_g, product_length_cm,
               product_height_cm, product_width_cm, COUNT_BIG(*) OVER (PARTITION BY product_id) AS multiplicidad
        INTO #Productos FROM stg.Products WITH (HOLDLOCK) WHERE batch_id = @Products;

        SELECT source_row_number, product_category_name, product_category_name_english,
               COUNT_BIG(*) OVER (PARTITION BY product_category_name) AS multiplicidad
        INTO #Categorias FROM stg.ProductCategoryTranslation WITH (HOLDLOCK) WHERE batch_id = @Translation;

        DECLARE @Conteos table(fuente sysname PRIMARY KEY, filas bigint NOT NULL);
        INSERT @Conteos
        SELECT N'Orders', COUNT_BIG(*) FROM #Pedidos UNION ALL
        SELECT N'OrderItems', COUNT_BIG(*) FROM #Lineas UNION ALL
        SELECT N'OrderPayments', COUNT_BIG(*) FROM #Pagos UNION ALL
        SELECT N'OrderReviews', COUNT_BIG(*) FROM #Resenas UNION ALL
        SELECT N'Customers', COUNT_BIG(*) FROM #Clientes UNION ALL
        SELECT N'Sellers', COUNT_BIG(*) FROM #Vendedores UNION ALL
        SELECT N'Products', COUNT_BIG(*) FROM #Productos UNION ALL
        SELECT N'Geolocation', COUNT_BIG(*) FROM stg.Geolocation WITH (HOLDLOCK) WHERE batch_id = @Geolocation UNION ALL
        SELECT N'ProductCategoryTranslation', COUNT_BIG(*) FROM #Categorias;

        SELECT @Leidas = SUM(filas) FROM @Conteos;
        INSERT @Rechazos
        SELECT e.fuente, NULL, N'batch_id', 'CONTEO_LOTE',
               CONCAT(N'Lote ', e.lote, N', filas publicadas ', c.filas, N', esperadas ', e.filas, N'.')
        FROM @Entrada AS e JOIN @Conteos AS c ON c.fuente = e.fuente WHERE c.filas <> e.filas;
        IF @@ROWCOUNT > 0 THROW 52004, N'Los conteos de staging no concilian con auditoría.', 1;
        IF NOT EXISTS (SELECT 1 FROM #Pedidos)
            THROW 52005, N'El snapshot no contiene pedidos.', 1;

        CREATE INDEX IX_Pedidos ON #Pedidos(order_id);
        INSERT @Rechazos
        SELECT N'Orders', source_row_number, N'order_id', 'PEDIDO_INVALIDO', N'Clave o estado vacío, o clave duplicada.'
        FROM #Pedidos WHERE NULLIF(TRIM(order_id), '') IS NULL OR NULLIF(TRIM(order_status), '') IS NULL OR multiplicidad > 1
        UNION ALL
        SELECT N'OrderItems', source_row_number, N'order_id', 'LINEA_INVALIDA', N'Pedido ausente, ítem inválido, importe nulo o clave duplicada.'
        FROM #Lineas AS l
        WHERE order_item_id IS NULL OR order_item_id <= 0 OR price IS NULL OR freight_value IS NULL
           OR multiplicidad > 1 OR NOT EXISTS (SELECT 1 FROM #Pedidos AS p WHERE p.order_id = l.order_id)
        UNION ALL
        SELECT N'OrderPayments', source_row_number, N'order_id', 'PAGO_INVALIDO', N'Pedido ausente, secuencia o importe nulo, o clave duplicada.'
        FROM #Pagos AS a
        WHERE payment_sequential IS NULL OR payment_value IS NULL OR multiplicidad > 1
           OR NOT EXISTS (SELECT 1 FROM #Pedidos AS p WHERE p.order_id = a.order_id)
        UNION ALL
        SELECT N'OrderReviews', source_row_number, N'order_id', 'RESENA_HUERFANA', N'El pedido de la reseña no está en el lote seleccionado.'
        FROM #Resenas AS r WHERE NOT EXISTS (SELECT 1 FROM #Pedidos AS p WHERE p.order_id = r.order_id)
        UNION ALL
        SELECT N'Customers', source_row_number, N'customer_id', 'CLIENTE_INVALIDO', N'Clave de registro vacía o duplicada.'
        FROM #Clientes WHERE NULLIF(TRIM(customer_id), '') IS NULL OR multiplicidad > 1
        UNION ALL
        SELECT N'Sellers', source_row_number, N'seller_id', 'VENDEDOR_INVALIDO', N'Clave vacía o duplicada.'
        FROM #Vendedores WHERE NULLIF(TRIM(seller_id), '') IS NULL OR multiplicidad > 1
        UNION ALL
        SELECT N'Products', source_row_number, N'product_id', 'PRODUCTO_INVALIDO', N'Clave vacía o duplicada.'
        FROM #Productos WHERE NULLIF(TRIM(product_id), '') IS NULL OR multiplicidad > 1
        UNION ALL
        SELECT N'ProductCategoryTranslation', source_row_number, N'product_category_name',
               'CATEGORIA_INVALIDA', N'Clave de categoría vacía o duplicada.'
        FROM #Categorias WHERE NULLIF(TRIM(product_category_name), N'') IS NULL OR multiplicidad > 1;
        IF @@ROWCOUNT > 0 THROW 52006, N'Snapshot rechazado por claves, referencias o importes inválidos.', 1;

        INSERT @Rechazos
        SELECT N'OrderReviews', source_row_number, N'review_score', 'PUNTAJE_FUERA_DE_RANGO',
               N'Puntuación excluida del promedio por estar fuera de 1 a 5.'
        FROM #Resenas WHERE review_score NOT BETWEEN 1 AND 5;

        DECLARE @Primera date, @Ultima date;
        SELECT @Primera = MIN(f.fecha), @Ultima = MAX(f.fecha)
        FROM #Pedidos AS p
        CROSS APPLY (VALUES (CONVERT(date, p.order_purchase_timestamp)),
                            (CONVERT(date, p.order_estimated_delivery_date)),
                            (CONVERT(date, p.order_delivered_customer_date))) AS f(fecha);

        ;WITH Calendario AS (
            SELECT @Primera AS fecha WHERE @Primera IS NOT NULL
            UNION ALL SELECT DATEADD(day, 1, fecha) FROM Calendario WHERE fecha < @Ultima
        )
        INSERT dw.DimFecha(fecha_key, fecha, anio, trimestre, mes, nombre_mes, dia, dia_semana)
        SELECT k.fecha_key, c.fecha, YEAR(c.fecha), DATEPART(quarter, c.fecha), MONTH(c.fecha),
               CHOOSE(MONTH(c.fecha), N'enero',N'febrero',N'marzo',N'abril',N'mayo',N'junio',
                                     N'julio',N'agosto',N'septiembre',N'octubre',N'noviembre',N'diciembre'),
               DAY(c.fecha), (DATEDIFF(day, CONVERT(date, '19000101', 112), c.fecha) % 7 + 7) % 7 + 1
        FROM Calendario AS c
        CROSS APPLY (VALUES (CONVERT(int, CONVERT(char(8), c.fecha, 112)))) AS k(fecha_key)
        WHERE NOT EXISTS (SELECT 1 FROM dw.DimFecha AS d WHERE d.fecha_key = k.fecha_key)
        OPTION (MAXRECURSION 0);

        INSERT dw.DimCliente(customer_unique_id)
        SELECT DISTINCT c.customer_unique_id FROM #Clientes AS c
        WHERE NULLIF(TRIM(c.customer_unique_id), '') IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM dw.DimCliente AS d WHERE d.customer_unique_id = c.customer_unique_id);

        INSERT dw.DimVendedor(seller_id)
        SELECT s.seller_id FROM #Vendedores AS s
        WHERE NOT EXISTS (SELECT 1 FROM dw.DimVendedor AS d WHERE d.seller_id = s.seller_id);

        INSERT dw.DimGeografiaCliente(customer_city, customer_state)
        SELECT DISTINCT c.customer_city, c.customer_state FROM #Clientes AS c
        WHERE NULLIF(TRIM(c.customer_city), N'') IS NOT NULL AND NULLIF(TRIM(c.customer_state), '') IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM dw.DimGeografiaCliente AS d
                          WHERE d.customer_city = c.customer_city AND d.customer_state = c.customer_state);

        INSERT dw.DimGeografiaVendedor(seller_city, seller_state)
        SELECT DISTINCT s.seller_city, s.seller_state FROM #Vendedores AS s
        WHERE NULLIF(TRIM(s.seller_city), N'') IS NOT NULL AND NULLIF(TRIM(s.seller_state), '') IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM dw.DimGeografiaVendedor AS d
                          WHERE d.seller_city = s.seller_city AND d.seller_state = s.seller_state);

        MERGE dw.DimProducto AS d
        USING (
            SELECT p.*, t.product_category_name_english FROM #Productos AS p LEFT JOIN #Categorias AS t
                ON t.product_category_name = p.product_category_name
        ) AS s ON s.product_id = d.product_id
        WHEN MATCHED THEN UPDATE SET
            product_category_name=s.product_category_name, product_category_name_english=s.product_category_name_english,
            product_name_lenght=s.product_name_lenght, product_description_lenght=s.product_description_lenght,
            product_photos_qty=s.product_photos_qty, product_weight_g=s.product_weight_g,
            product_length_cm=s.product_length_cm, product_height_cm=s.product_height_cm, product_width_cm=s.product_width_cm
        WHEN NOT MATCHED BY TARGET THEN INSERT (product_id, product_category_name, product_category_name_english,
            product_name_lenght, product_description_lenght, product_photos_qty, product_weight_g,
            product_length_cm, product_height_cm, product_width_cm)
        VALUES (s.product_id, s.product_category_name, s.product_category_name_english,
            s.product_name_lenght, s.product_description_lenght, s.product_photos_qty, s.product_weight_g,
            s.product_length_cm, s.product_height_cm, s.product_width_cm);

        ;WITH Pagos AS (
            SELECT order_id, CONVERT(decimal(19,4), SUM(payment_value)) AS total FROM #Pagos GROUP BY order_id
        ), Resenas AS (
            SELECT order_id, CONVERT(decimal(9,4), AVG(CONVERT(decimal(9,4), review_score))) AS promedio
            FROM #Resenas WHERE review_score BETWEEN 1 AND 5 GROUP BY order_id
        )
        SELECT p.order_id, COALESCE(dc.cliente_key, -1) AS cliente_key,
               COALESCE(g.geografia_cliente_key, -1) AS geografia_cliente_key,
               COALESCE(CONVERT(int, CONVERT(char(8), p.order_purchase_timestamp, 112)), -1) AS fecha_compra_key,
               COALESCE(CONVERT(int, CONVERT(char(8), p.order_estimated_delivery_date, 112)), -1) AS fecha_entrega_estimada_key,
               COALESCE(CONVERT(int, CONVERT(char(8), p.order_delivered_customer_date, 112)), -1) AS fecha_entrega_real_key,
               p.order_status, p.order_purchase_timestamp, p.order_estimated_delivery_date, p.order_delivered_customer_date,
               a.total AS payment_value_total, r.promedio AS review_score
        INTO #FactPedidos
        FROM #Pedidos AS p
        LEFT JOIN #Clientes AS c ON c.customer_id = p.customer_id
        LEFT JOIN dw.DimCliente AS dc
            ON dc.customer_unique_id = c.customer_unique_id AND NULLIF(TRIM(c.customer_unique_id), '') IS NOT NULL
        LEFT JOIN dw.DimGeografiaCliente AS g
            ON g.customer_city = c.customer_city AND g.customer_state = c.customer_state
               AND NULLIF(TRIM(c.customer_city), N'') IS NOT NULL AND NULLIF(TRIM(c.customer_state), '') IS NOT NULL
        LEFT JOIN Pagos AS a ON a.order_id = p.order_id
        LEFT JOIN Resenas AS r ON r.order_id = p.order_id;
        CREATE UNIQUE CLUSTERED INDEX UX_FactPedidos ON #FactPedidos(order_id);

        SELECT l.order_id, l.order_item_id, COALESCE(dp.producto_key, -1) AS producto_key,
               COALESCE(dv.vendedor_key, -1) AS vendedor_key, p.cliente_key, p.geografia_cliente_key,
               COALESCE(g.geografia_vendedor_key, -1) AS geografia_vendedor_key, p.fecha_compra_key,
               p.order_status, l.price, l.freight_value
        INTO #FactDetalle
        FROM #Lineas AS l JOIN #FactPedidos AS p ON p.order_id = l.order_id
        LEFT JOIN #Productos AS ps ON ps.product_id = l.product_id
        LEFT JOIN dw.DimProducto AS dp ON dp.product_id = ps.product_id
        LEFT JOIN #Vendedores AS vs ON vs.seller_id = l.seller_id
        LEFT JOIN dw.DimVendedor AS dv ON dv.seller_id = vs.seller_id
        LEFT JOIN dw.DimGeografiaVendedor AS g
            ON g.seller_city = vs.seller_city AND g.seller_state = vs.seller_state
               AND NULLIF(TRIM(vs.seller_city), N'') IS NOT NULL AND NULLIF(TRIM(vs.seller_state), '') IS NOT NULL;
        CREATE UNIQUE CLUSTERED INDEX UX_FactDetalle ON #FactDetalle(order_id, order_item_id);

        DELETE d FROM dw.FactDetallePedido AS d WHERE NOT EXISTS (
            SELECT 1 FROM #FactDetalle AS s WHERE s.order_id = d.order_id AND s.order_item_id = d.order_item_id);
        DELETE d FROM dw.FactPedidos AS d WHERE NOT EXISTS (SELECT 1 FROM #FactPedidos AS s WHERE s.order_id = d.order_id);

        MERGE dw.FactPedidos AS d USING #FactPedidos AS s ON s.order_id = d.order_id
        WHEN MATCHED THEN UPDATE SET
            cliente_key=s.cliente_key, geografia_cliente_key=s.geografia_cliente_key, fecha_compra_key=s.fecha_compra_key,
            fecha_entrega_estimada_key=s.fecha_entrega_estimada_key, fecha_entrega_real_key=s.fecha_entrega_real_key,
            order_status=s.order_status, order_purchase_timestamp=s.order_purchase_timestamp,
            order_estimated_delivery_date=s.order_estimated_delivery_date, order_delivered_customer_date=s.order_delivered_customer_date,
            payment_value_total=s.payment_value_total, review_score=s.review_score
        WHEN NOT MATCHED BY TARGET THEN INSERT (order_id, cliente_key, geografia_cliente_key, fecha_compra_key,
            fecha_entrega_estimada_key, fecha_entrega_real_key, order_status, order_purchase_timestamp,
            order_estimated_delivery_date, order_delivered_customer_date, payment_value_total, review_score)
        VALUES (s.order_id, s.cliente_key, s.geografia_cliente_key, s.fecha_compra_key,
            s.fecha_entrega_estimada_key, s.fecha_entrega_real_key, s.order_status, s.order_purchase_timestamp,
            s.order_estimated_delivery_date, s.order_delivered_customer_date, s.payment_value_total, s.review_score);

        MERGE dw.FactDetallePedido AS d USING #FactDetalle AS s
            ON s.order_id = d.order_id AND s.order_item_id = d.order_item_id
        WHEN MATCHED THEN UPDATE SET
            producto_key=s.producto_key, vendedor_key=s.vendedor_key, cliente_key=s.cliente_key,
            geografia_cliente_key=s.geografia_cliente_key, geografia_vendedor_key=s.geografia_vendedor_key,
            fecha_compra_key=s.fecha_compra_key, order_status=s.order_status, price=s.price, freight_value=s.freight_value
        WHEN NOT MATCHED BY TARGET THEN INSERT (order_id, order_item_id, producto_key, vendedor_key, cliente_key,
            geografia_cliente_key, geografia_vendedor_key, fecha_compra_key, order_status, price, freight_value)
        VALUES (s.order_id, s.order_item_id, s.producto_key, s.vendedor_key, s.cliente_key,
            s.geografia_cliente_key, s.geografia_vendedor_key, s.fecha_compra_key, s.order_status, s.price, s.freight_value);

        IF (SELECT COUNT_BIG(*) FROM dw.FactPedidos) <> (SELECT filas FROM @Conteos WHERE fuente=N'Orders')
           OR (SELECT COUNT_BIG(*) FROM dw.FactDetallePedido) <> (SELECT filas FROM @Conteos WHERE fuente=N'OrderItems')
            THROW 52007, N'Los conteos de los hechos no concilian con el snapshot.', 1;

        INSERT audit.Reject(batch_id, source_name, source_row_number, field_name, reason_code, reason)
        SELECT @Ejecucion, fuente, ordinal, campo, codigo, motivo FROM @Rechazos;
        SET @Rechazadas = ROWCOUNT_BIG();
        UPDATE audit.Batch SET status='COMPLETE', finished_at=SYSDATETIME(), rows_read=@Leidas,
            rows_accepted=@Leidas-@Rechazadas, rows_rejected=@Rechazadas
        WHERE batch_id=@Ejecucion;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

        -- La variable de tabla conserva el diagnóstico tras revertir la publicación.
        BEGIN TRANSACTION;
        INSERT audit.Reject(batch_id, source_name, source_row_number, field_name, reason_code, reason)
        SELECT @Ejecucion, fuente, ordinal, campo, codigo, motivo FROM @Rechazos;
        SELECT @Rechazadas = COUNT_BIG(*) FROM @Rechazos WHERE ordinal IS NOT NULL;
        UPDATE audit.Batch SET status='FAILED', finished_at=SYSDATETIME(), rows_read=@Leidas,
            rows_rejected=@Rechazadas, error_message=LEFT(CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE()), 2000)
        WHERE batch_id=@Ejecucion;
        COMMIT TRANSACTION;
        THROW;
    END CATCH;
END;
GO
