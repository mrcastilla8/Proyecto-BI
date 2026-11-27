SELECT categorias.valor, categorias.etiqueta
FROM (
    SELECT '__TODOS__' AS valor, N'Todas' AS etiqueta, 0 AS prioridad
    UNION ALL
    SELECT DISTINCT product_category_name_english, product_category_name_english, 1
    FROM dw.DimProducto
    WHERE product_category_name_english IS NOT NULL
    UNION ALL
    SELECT '__DESCONOCIDO__', N'Desconocida', 2
    WHERE EXISTS (
        SELECT 1 FROM dw.DimProducto WHERE product_category_name_english IS NULL
    )
) AS categorias
ORDER BY categorias.prioridad, categorias.etiqueta;
