# Desarrollo paralelo y colaboración remota

## Requisitos mínimos por rol

Todos: Windows, Git, cuenta GitHub con acceso al repositorio e identidad Git configurada. Castilla: Git, Python 3 estándar para validaciones; SQL Server/SSMS y Visual Studio para DDL e integración. Poma y Cueva: Visual Studio Community con extensión SSIS, SQL Server local y SSMS. Basualdo: Visual Studio con Analysis Services Projects, instancia de SSAS Tabular instalada y alcanzable localmente; Developer de SQL Server solo si el entorno requiere motor relacional. Ángel: Power BI Desktop; para probar conexión necesita SSAS Tabular real. Anotar versiones de Visual Studio, extensiones, SQL Server, SSAS, SSMS y Power BI realmente instaladas; compatibilidad entre equipos aún por validar.

## Entorno local y reconstrucción

Cada integrante clona el repositorio y crea la rama estable asignada derivada de `master`. No se comparte SQL Server del PC de otro miembro ni se añaden bases, CSV reales, backups o credenciales a Git. Cada quien instala servicios/componentes necesarios en su equipo; para base local usa nombre `BI_OLIST`, esquemas y DDL versionados. Host/instancia/puerto/auth y rutas CSV son parámetros locales (por `.env`/parámetros SSIS locales ignorados por Git); `.env.example` solo muestra nombres, no es configuración lista. Nunca abrir SQL Server o SSAS a Internet; para revisar el servicio de integración, usar red privada autorizada, VPN institucional o sesión local controlada.

Fixtures sintéticas de nueve fuentes están en `data/fixtures/`, pequeñas y estructurales. Se pueden reconstruir desde cero siguiendo documentación/DDL aprobado y cargándolas manualmente o por la herramienta del rol; no simulan perfiles estadísticos ni reemplazan la prueba con CSV real. Python se limita a contratos/documentación/fixtures, no implementa ETL ni sustituye SQL Server.

## Contratos y cambios

Contratos versionados se comparten por Git. Castilla mantiene contratos/ADR y DDL; Poma/Cueva pueden revisar columnas, tipos, rechazos, claves, agregados y reejecución; Basualdo puede revisar granos, claves, roles de fecha y medidas; Ángel puede revisar filtros y páginas. La aprobación técnica de un contrato requiere evidencia del dataset y trazabilidad del responsable, issue, PR y versión. Ningún revisor externo es requisito de merge; CODEOWNERS solo sugiere responsables.

Cambio compatible aditivo: issue, actualizar versión menor y documentar compatibilidad; solicitar review de consumidores tocados cuando ayude a validar impacto. Cambio incompatible de columna/tipo/grano/clave/métrica: issue + ADR + versión mayor + plan de migración; comunicarlo a los afectados antes de integrar. Cada PR identifica versión consumida. Correcciones editoriales sin cambio semántico incrementan parche. No actualizar el estado contractual por sí solo.

## Integración y evidencias

Orden: (1) acordar versión aprobada y compatibilidad Windows; (2) Castilla publica DDL y controles; (3) Poma carga CSV a staging; (4) Cueva transforma a dimensiones/hechos y prueba reejecución; (5) equipo reconstruye BI_OLIST limpia, ejecuta ETL y concilia SQL; (6) Basualdo procesa SSAS y concilia medidas; (7) Ángel conecta Power BI Live y valida visuales; (8) Castilla consolida informe. En cada paso adjuntar en PR comandos, versión/software, fecha, resultado real, conteos, mensajes/logs sin credenciales ni filas sensibles; capturas reales opcionales si no exponen datos personales. No marcar trabajo completo con pantallas o mocks.

Mientras faltan dependencias, se puede preparar de forma paralela el entorno y revisar contratos/issues. Basualdo puede crear/validar su proyecto Tabular real en una instancia local con esquema de desarrollo autorizado o metadatos de trabajo documentados, y definir relaciones/medidas contra contrato marcado como provisional; no afirmar procesamiento ni congelar modelo. Ángel puede acordar las cuatro páginas, disposición y filtros sin PBIX de importación ni datos inventados; el reporte Live funcional comienza cuando un SSAS procesado está disponible. Tests de conexión/Live requieren SSAS real alcanzable de forma segura y datos del DW reconstruido, más aprobación de definiciones. No bloquear diseño preliminar por ausencia del servicio, y no presentar ese diseño como componente terminado.

En fallo: preservar logs/lote y filas rechazadas en entorno local, compartir causa/reproducción sin datos reales, corregir mediante PR y demostrar reejecución. La segunda ejecución sin duplicados solo se reporta cuando exista una carga SQL/SSIS y se haya observado en Windows.
