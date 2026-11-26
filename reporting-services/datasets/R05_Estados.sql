WITH estados AS (
    SELECT '__TODOS__' AS valor, N'Todos' AS etiqueta, 0 AS orden
    UNION ALL
    SELECT DISTINCT CONVERT(varchar(2), customer_state), CONVERT(nvarchar(2), customer_state), 1
    FROM dw.DimGeografiaCliente
    WHERE customer_state IS NOT NULL
    UNION ALL
    SELECT '__DESCONOCIDO__', N'Desconocido', 2
    WHERE EXISTS (SELECT 1 FROM dw.DimGeografiaCliente WHERE customer_state IS NULL)
)
SELECT valor, etiqueta
FROM estados
ORDER BY orden, etiqueta;
