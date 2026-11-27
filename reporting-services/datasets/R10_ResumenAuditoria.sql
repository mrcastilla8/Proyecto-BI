SELECT b.source_name,
       CASE
           WHEN b.source_name = 'DW.Transformacion' THEN 'Transformacion'
           ELSE 'Ingesta'
       END AS tipo_proceso,
       b.status,
       COUNT_BIG(*) AS lotes,
       MAX(b.started_at) AS ultima_ejecucion,
       MAX(CASE WHEN b.status = 'COMPLETE' THEN b.batch_id END) AS ultimo_lote_completo
FROM audit.Batch AS b
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
GROUP BY b.source_name,
         CASE WHEN b.source_name = 'DW.Transformacion' THEN 'Transformacion' ELSE 'Ingesta' END,
         b.status
ORDER BY tipo_proceso, b.source_name, b.status;
