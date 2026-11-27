SELECT MIN(f.fecha) AS Desde, MAX(f.fecha) AS Hasta FROM dw.FactPedidos AS p JOIN dw.DimFecha AS f ON f.fecha_key = p.fecha_compra_key WHERE p.fecha_compra_key <> -1 AND f.fecha IS NOT NULL;
