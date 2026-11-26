SELECT (SELECT COUNT_BIG(*) FROM dw.FactPedidos) AS pedidos, (SELECT COUNT_BIG(*) FROM dw.FactDetallePedido) AS lineas, SYSUTCDATETIME() AS fecha_ejecucion_utc;
