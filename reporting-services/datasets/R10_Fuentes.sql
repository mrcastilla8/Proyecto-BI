SELECT fuentes.valor, fuentes.etiqueta
FROM (
    SELECT '__TODOS__' AS valor, N'Todas' AS etiqueta, 0 AS prioridad
    UNION ALL
    SELECT DISTINCT source_name, source_name, 1
    FROM audit.Batch
    WHERE source_name IS NOT NULL
    UNION ALL
    SELECT '__DESCONOCIDO__', N'Desconocida', 2
    WHERE EXISTS (
        SELECT 1 FROM audit.Batch WHERE source_name IS NULL
    )
) AS fuentes
ORDER BY fuentes.prioridad, fuentes.etiqueta;
