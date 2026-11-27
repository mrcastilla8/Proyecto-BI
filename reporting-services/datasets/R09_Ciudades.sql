SELECT ciudades.valor, ciudades.etiqueta
FROM (
    SELECT CONVERT(nvarchar(200), '__TODOS__') AS valor, N'Todas' AS etiqueta, 0 AS prioridad
    UNION ALL
    SELECT DISTINCT g.customer_city, g.customer_city, 1
    FROM dw.DimGeografiaCliente AS g
    WHERE g.customer_city IS NOT NULL
      AND (@EstadoCliente = '__TODOS__'
           OR g.customer_state = @EstadoCliente
           OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL))
    UNION ALL
    SELECT '__DESCONOCIDO__', N'Desconocida', 2
    WHERE EXISTS (
        SELECT 1 FROM dw.DimGeografiaCliente AS g
        WHERE g.customer_city IS NULL
          AND (@EstadoCliente = '__TODOS__'
               OR g.customer_state = @EstadoCliente
               OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL))
    )
) AS ciudades
ORDER BY ciudades.prioridad, ciudades.etiqueta;
