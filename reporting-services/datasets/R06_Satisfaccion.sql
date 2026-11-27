WITH Limites AS (
    SELECT MIN(f.fecha) AS fecha_minima, MAX(f.fecha) AS fecha_maxima
    FROM dw.FactPedidos AS p
    JOIN dw.DimFecha AS f ON f.fecha_key = p.fecha_compra_key
    WHERE f.fecha_key <> -1
),
Notas AS (
    SELECT f.anio, f.mes, g.customer_state,
           CONVERT(float, p.review_score) AS nota,
           CONVERT(int, FLOOR(p.review_score)) AS rango
    FROM dw.FactPedidos AS p
    JOIN dw.DimFecha AS f ON f.fecha_key = p.fecha_compra_key
    JOIN dw.DimGeografiaCliente AS g ON g.geografia_cliente_key = p.geografia_cliente_key
    CROSS JOIN Limites AS l
    WHERE f.fecha_key <> -1
      AND CAST(@Desde AS date) >= l.fecha_minima
      AND CAST(@Hasta AS date) <= l.fecha_maxima
      AND CAST(@Desde AS date) <= CAST(@Hasta AS date)
      AND f.fecha BETWEEN CAST(@Desde AS date) AND CAST(@Hasta AS date)
      AND (
          @EstadoCliente = '__TODOS__'
          OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL)
          OR g.customer_state = @EstadoCliente
      )
      AND @NotaMin >= 1 AND @NotaMax <= 5 AND @NotaMin <= @NotaMax
      AND CONVERT(float, p.review_score) BETWEEN @NotaMin AND @NotaMax
)
SELECT GROUPING_ID(anio, mes, customer_state, rango) AS nivel,
       anio, mes, customer_state, rango,
       COUNT_BIG(*) AS notas_validas, AVG(nota) AS nota
FROM Notas
GROUP BY GROUPING SETS ((anio, mes), (customer_state), (rango), ())
HAVING COUNT_BIG(*) > 0
ORDER BY nivel, anio, mes, customer_state, rango;
