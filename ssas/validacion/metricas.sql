SET NOCOUNT ON;

-- Usar la misma publicación del Data Mart que procesó SSAS.
DECLARE @lotes nvarchar(400);
SELECT TOP (1) @lotes = execution_context
FROM audit.Batch
WHERE source_name = N'DW.Transformacion' AND status = 'COMPLETE'
ORDER BY finished_at DESC, batch_id DESC;

IF @lotes IS NULL
    THROW 52100, N'Falta una publicación COMPLETE de DW.Transformacion.', 1;

IF (SELECT COUNT(*) FROM OPENJSON(@lotes)) <> 9 OR EXISTS (
    SELECT 1
    FROM OPENJSON(@lotes) AS lote
    LEFT JOIN audit.Batch AS origen
        ON origen.batch_id = TRY_CONVERT(bigint, lote.value)
        AND origen.source_name = lote.[key] COLLATE DATABASE_DEFAULT
        AND origen.status = 'COMPLETE'
        AND origen.contract_version = '1.0.0'
    WHERE origen.batch_id IS NULL
)
    THROW 52101, N'No se pudieron verificar los nueve lotes de origen.', 1;

WITH Escenarios AS (
    SELECT escenario, rol_fecha, estado_cliente, categoria, estado_vendedor, estado_pedido
    FROM (VALUES
        ('total',                  NULL,       NULL, NULL,              NULL, NULL),
        ('compra_2017',            'compra',   NULL, NULL,              NULL, NULL),
        ('cliente_sp',             NULL,       'SP', NULL,              NULL, NULL),
        ('producto_y_vendedor_sp', NULL,       NULL, 'cama_mesa_banho', 'SP', NULL),
        ('entrega_real_2017',      'real',     NULL, NULL,              NULL, NULL),
        ('entrega_estimada_2017',  'estimada', NULL, NULL,              NULL, NULL),
        ('cancelados',             NULL,       NULL, NULL,              NULL, 'canceled')
    ) AS casos(escenario, rol_fecha, estado_cliente, categoria, estado_vendedor, estado_pedido)
)
SELECT
    e.escenario,
    d.ventas AS ventas_productos_entregados,
    d.pedidos AS pedidos_entregados_con_items,
    p.pedidos AS pedidos_totales,
    CONVERT(decimal(24,4), d.ventas) / NULLIF(d.pedidos, 0) AS ticket_promedio_productos_entregados,
    d.flete AS flete_pedidos_entregados,
    p.puntualidad AS porcentaje_entregas_a_tiempo,
    p.dias AS dias_promedio_entrega,
    p.calificacion AS calificacion_promedio
FROM Escenarios AS e
OUTER APPLY (
    SELECT SUM(d.price) AS ventas,
           NULLIF(COUNT(DISTINCT d.order_id), 0) AS pedidos,
           SUM(d.freight_value) AS flete
    FROM dw.FactDetallePedido AS d
    JOIN dw.DimGeografiaCliente AS gc ON gc.geografia_cliente_key = d.geografia_cliente_key
    JOIN dw.DimGeografiaVendedor AS gv ON gv.geografia_vendedor_key = d.geografia_vendedor_key
    JOIN dw.DimProducto AS prod ON prod.producto_key = d.producto_key
    JOIN dw.DimFecha AS f ON f.fecha_key = d.fecha_compra_key
    WHERE (e.rol_fecha IS NULL OR (e.rol_fecha = 'compra' AND f.anio = 2017))
      AND (e.estado_cliente IS NULL OR gc.customer_state = e.estado_cliente)
      AND (e.estado_vendedor IS NULL OR gv.seller_state = e.estado_vendedor)
      AND (e.categoria IS NULL OR prod.product_category_name = e.categoria)
      AND (e.estado_pedido IS NULL OR d.order_status = e.estado_pedido)
      AND d.order_status = 'delivered'
) AS d
OUTER APPLY (
    SELECT NULLIF(COUNT(DISTINCT p.order_id), 0) AS pedidos,
           AVG(CASE WHEN p.order_status = 'delivered'
                        AND p.order_delivered_customer_date IS NOT NULL
                        AND p.order_estimated_delivery_date IS NOT NULL
                    THEN CONVERT(decimal(19,10), CASE
                        WHEN CONVERT(date, p.order_delivered_customer_date)
                             <= CONVERT(date, p.order_estimated_delivery_date) THEN 1
                        ELSE 0 END)
               END) AS puntualidad,
           AVG(CASE WHEN p.order_status = 'delivered'
                        AND p.order_purchase_timestamp IS NOT NULL
                        AND p.order_delivered_customer_date IS NOT NULL
                    THEN CONVERT(decimal(24,10), DATEDIFF_BIG(
                        SECOND, p.order_purchase_timestamp, p.order_delivered_customer_date
                    )) / 86400
               END) AS dias,
           AVG(CONVERT(decimal(19,10), p.review_score)) AS calificacion
    FROM dw.FactPedidos AS p
    JOIN dw.DimGeografiaCliente AS gc ON gc.geografia_cliente_key = p.geografia_cliente_key
    JOIN dw.DimFecha AS f ON f.fecha_key = CASE e.rol_fecha
        WHEN 'real' THEN p.fecha_entrega_real_key
        WHEN 'estimada' THEN p.fecha_entrega_estimada_key
        ELSE p.fecha_compra_key END
    WHERE e.categoria IS NULL
      AND (e.rol_fecha IS NULL OR f.anio = 2017)
      AND (e.estado_cliente IS NULL OR gc.customer_state = e.estado_cliente)
      AND (e.estado_pedido IS NULL OR p.order_status = e.estado_pedido)
) AS p
ORDER BY e.escenario;
