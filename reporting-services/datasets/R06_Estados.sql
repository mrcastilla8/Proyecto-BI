SELECT estados.valor, estados.etiqueta
FROM (
    SELECT '__TODOS__' AS valor, N'Todos' AS etiqueta, 0 AS prioridad
    UNION ALL
    SELECT DISTINCT customer_state, customer_state, 1
    FROM dw.DimGeografiaCliente
    WHERE customer_state IS NOT NULL
    UNION ALL
    SELECT '__DESCONOCIDO__', N'Desconocido', 2
    WHERE EXISTS (
        SELECT 1 FROM dw.DimGeografiaCliente WHERE customer_state IS NULL
    )
) AS estados
ORDER BY estados.prioridad, estados.etiqueta;
