# 04 — Implementación de SSRS 2022

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## Plataforma y preflight (Poma)
SSRS 2022 Developer, modo nativo, Windows, SQL Server 2025 Developer para catálogo y DW. Instalar Report Builder; opcional Report Server Projects en Visual Studio si la extensión soporta la versión instalada; si no, autoría en Report Builder y publicación manual reproducible. No sustituir por PBIRS sin aprobación. Microsoft mantiene SSRS 2022 y admite motor posterior para catálogo ([FAQ](https://learn.microsoft.com/en-us/sql/reporting-services/reporting-services-consolidation-faq?view=sql-server-ver16)). Verificar edición exacta y actualizaciones del instalador, no asumir Express/LocalDB como host de catálogo. [Instalación](https://learn.microsoft.com/en-us/sql/reporting-services/install-windows/install-reporting-services?view=sql-server-ver17), [catálogo](https://learn.microsoft.com/en-us/sql/reporting-services/install-windows/ssrs-report-server-create-a-report-server-database?view=sql-server-ver17).

### Pasos obligatorios
1. Registrar Windows, SQL (`SELECT @@VERSION`), edición, SSAS, Power BI Desktop, Report Builder y SSRS. Comprobar DW y SSAS procesados, usuario local y espacio disponible. No instalar sobre servidor ajeno.
2. Descargar SSRS 2022 desde Microsoft, elegir Developer (solo desarrollo/pruebas), instalar y abrir Configuration Manager.
3. Conectar a instancia SSRS, configurar cuenta de servicio soportada. Crear catálogo ReportServer y ReportServerTempDB mediante asistente en instancia SQL Developer; no modificar tablas internas manualmente.
4. Configurar Web Service URL y Web Portal URL sin colisiones de puertos. Registrar URLs reales; limitar red al equipo demo o LAN privada autorizada, firewall sin exposición pública. En local usar loopback, HTTP solo en laboratorio local; TLS si acceso remoto autorizado.
5. Configurar Windows authentication y roles: cuenta administradora de publicación; usuario Browser para lectura. Verificar acceso de ambos, usuario sin permisos rechazado. Back up encryption key fuera de Git con protección local si procede.
6. Configurar origen compartido `BI_OLIST_DW` y otro `BI_OLIST_AUDIT` si se separan credenciales; ambos SQL BI_OLIST. Credenciales de Windows dedicadas almacenadas solo en servidor o mecanismo integrado validado. En local evitar doble salto; no elevar a sysadmin/db_owner. Conceder SELECT por objeto necesario (o schema dw; auditoría exclusivamente columnas necesarias mediante permisos acordados), no DML. Para R10 nunca seleccionar error_message, source_file, execution_context ni datos de rechazo individuales.
7. Publicar RDL de humo con SELECT de conteo, probar portal, PDF y EXCELOPENXML. Eliminar prueba de humo después de capturar evidencia.

## Estructura objetivo
```text
reporting-services/
  AGENTS.md
  README.md
  proyecto/          # .sln/.rptproj si herramienta compatible
  reports/           # R01..R10 .rdl; único archivo por informe
  datasets/          # SQL de referencia versionado, no scripts de mutación
  datasources/       # plantilla sin credenciales ni servidor personal
  diseno/            # plantilla visual
  scripts/           # publicación/verificación PowerShell, si se implementa
  validacion/        # manifiesto, resultados y exportaciones agregadas seguras
  evidencias/        # capturas redactadas, no claves ni datos sensibles
```
Los SQL deben existir como fuente de revisión y coincidir con CommandText embebido en RDL; si hay diferencias, fallo. Si se utiliza .rptproj, Poma controla el archivo compartido y registra los informes. Report Builder permite publicar directamente al portal; documentar pasos reproducibles y manifiesto de carpetas/nombres.

## Portal
Raíz `/OLIST360`; carpetas `01_Gerencia`, `02_Comercial`, `03_Operaciones`, `04_Auditoria`, `DataSources`. Nombres exactos de rutas en 07. No publicar `.pbix` aquí. RDL usa fuente compartida y parámetros tipados; comprobar origen resuelto tras despliegue. Configurar timeout de dataset 60 s como protección, no objetivo de desempeño. Sin programación de correo, suscripciones o exposición cloud obligatoria.

## Publicación y reproducción
Registrar hash SHA-256 de RDL local y descargado si API/portal lo permite; registrar versión en manifiesto, URL, resultado de prueba, fecha y equipo. No almacenar contraseña ni auth header. Para publicación manual, abrir RDL en Report Builder, Save As al servidor/carpeta, asociar data source y probar parámetros. Si se automatiza, usar API/servicio soportado y credencial integrada, nunca modificar directamente catálogo. Un solo publicador (Poma) en entorno demo; rollback republicando última versión validada de RDL, sin tocar DW.

## Evidencia mínima
Los identificadores de evidencia documental (`EVD-SSRS-*`) son independientes de los casos de certificación (`SSRS-01` a `SSRS-14` en `08_PRUEBAS_CERTIFICACION.md`):

- `EVD-SSRS-01`: versiones (Windows, SQL `SELECT @@VERSION`, edición, SSAS, Power BI Desktop, Report Builder y SSRS). Relacionado con preflight `G0` y `SSRS-01`.
- `EVD-SSRS-02`: catálogo y servicio (`ReportServer`/`ReportServerTempDB` y servicio nativo activo). Relacionado con preflight `G0` y `SSRS-01`.
- `EVD-SSRS-03`: portal (Web Portal URL y Web Service URL en laboratorio local). Relacionado con preflight `G0` y `SSRS-01`.
- `EVD-SSRS-04`: permisos `Browser` y acceso rechazado a usuario no autorizado. Relacionado con preflight `G0` y `SSRS-02`.
- `EVD-SSRS-05`: conexión compartida (`BI_OLIST_DW` y `BI_OLIST_AUDIT` si aplica, solo lectura sin DML). Relacionado con preflight `G0` y `SSRS-02`.
- `EVD-SSRS-06`: árbol de diez informes definitivos publicados en `/OLIST360` (`G3`). Relacionado con `SSRS-01` e `INT-01`.
- `EVD-SSRS-07`: matriz de ejecución de los diez RDL (`G3`/`G4`). Relacionado con `SSRS-03` a `SSRS-13`.
- `EVD-SSRS-08`: exportaciones verificables (humo PDF/XLSX en `G0`; 10 PDF y 10 XLSX definitivos en `G3`/`G4`). Relacionado con `SSRS-14`.

Los pasos son especificación, no instalación acreditada. No exigir los diez informes definitivos para superar el preflight `G0`.
