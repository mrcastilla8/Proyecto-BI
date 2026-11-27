SELECT MIN(f.fecha) AS desde, MAX(f.fecha) AS hasta
FROM dw.FactPedidos AS p
JOIN dw.DimFecha AS f ON f.fecha_key = p.fecha_compra_key
WHERE f.fecha_key <> -1;
