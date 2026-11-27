SELECT MIN(CAST(b.started_at AS date)) AS desde,
       MAX(CAST(b.started_at AS date)) AS hasta
FROM audit.Batch AS b
WHERE b.started_at IS NOT NULL;
