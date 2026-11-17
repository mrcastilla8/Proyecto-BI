# Instalación local por rol

Todos: Windows, Git, GitHub con escritura e identidad git configurada. Poma/Cueva: VS Community + extensión SSIS, SQL Server local, SSMS. Basualdo: VS + Analysis Services Projects, SSAS Tabular aparte, SQL Server Developer cuando necesite SSAS, SSMS. Ángel: Power BI Desktop y SSAS accesible para Live. Castilla: Git, SQL Server/SSMS y VS para integración. No todos instalan todo. Anotar versiones realmente instaladas; compatibilidad está pendiente de comprobación.

Usar `BI_OLIST` y esquemas aprobados. Servidor/instancia, puerto y autenticación se configuran localmente; `.env.example` ilustra nombres, no conecta automáticamente. No fijar rutas absolutas del perfil de usuario, equipo personal ni credenciales en fuentes. Developer es académica/no productiva; Express por sí sola no incluye SSAS.

Descargar manualmente desde Kaggle, aceptar condiciones y anotar fuente/fecha/versión; no subir archivos. Inspeccionar codificación, delimitador, decimal, fechas y quoting antes de configurar SSIS. Desarrollo distribuido usa SQL local y fixtures; bases no se comparten por Git. Integración y conexión Live requieren servicio SSAS real y acceso seguro acordado, jamás puertos abiertos a internet.
