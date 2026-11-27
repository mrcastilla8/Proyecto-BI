WITH rechazos AS (
    SELECT batch_id, COUNT_BIG(*) AS registrados
    FROM audit.Reject
    GROUP BY batch_id
)
SELECT b.batch_id,
       b.source_name,
       b.contract_version,
       b.status,
       b.started_at,
       b.finished_at,
       b.rows_read,
       b.rows_accepted,
       b.rows_rejected,
       COALESCE(r.registrados, 0) AS rechazos_registrados,
       CASE
           WHEN b.status = 'COMPLETE' THEN
               CASE
                   WHEN b.rows_read = b.rows_accepted + b.rows_rejected
                        AND b.rows_rejected = COALESCE(r.registrados, 0) THEN 'CONCILIADO'
                   ELSE 'REVISAR'
               END
           ELSE 'NO_TERMINAL_O_FALLIDO'
       END AS control,
       CASE
           WHEN b.source_name = 'DW.Transformacion' THEN 'Transformacion'
           ELSE 'Ingesta'
       END AS tipo_proceso,
       ROW_NUMBER() OVER (PARTITION BY b.source_name ORDER BY b.started_at DESC, b.batch_id DESC) AS orden_recencia
FROM audit.Batch AS b
LEFT JOIN rechazos AS r ON r.batch_id = b.batch_id
WHERE CAST(b.started_at AS date) BETWEEN CAST(@DesdeEjecucion AS date) AND CAST(@HastaEjecucion AS date)
  AND CAST(@DesdeEjecucion AS date) <= CAST(@HastaEjecucion AS date)
  AND (
      @Fuente = '__TODOS__'
      OR (@Fuente = '__DESCONOCIDO__' AND b.source_name IS NULL)
      OR b.source_name = @Fuente
  )
  AND (
      @EstadoLote = '__TODOS__'
      OR (@EstadoLote = '__DESCONOCIDO__' AND b.status IS NULL)
      OR b.status = @EstadoLote
  )
ORDER BY b.started_at DESC, b.batch_id DESC;
