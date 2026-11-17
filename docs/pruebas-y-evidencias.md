# Pruebas y evidencias

CI Ubuntu ejecuta solo `python3 scripts/validar_base.py` sin secrets/dataset. No ejecuta SQL, SSIS, SSAS ni Power BI. Primera corrida pendiente hasta publicar. Pruebas manuales Windows y capturas reales pendientes.

Evidencia académica requerida: (1) origen, condición, versión/fecha y archivos observados; (2) versiones de SQL/SSMS, creación BI_OLIST y consultas de conteo, unicidad, FK, sumas/nulos con resultados; (3) SSIS ingesta, parámetros, leídos/aceptados/rechazados y logs; (4) SSIS transformación, granos, idempotencia y controles SQL; (5) SSAS relaciones, jerarquías, procesamiento y cotejo DAX/SQL; (6) Power BI Live confirmado, cuatro páginas y filtros; (7) informe paso a paso y conclusiones solo de evidencia. Registrar equipo/versión/comando/resultado. Fixtures son sintéticas y no prueban hallazgos de Olist.
