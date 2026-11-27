# Resultados M01–M05 — ejecución local SSRS

- Fecha: 2026-11-26
- Rama: poma/nivel-2-reporting
- SHA probado de los RDL y del validador: feff597f3d066b5f25c82d76eadd29d83c0d9b96
- Entorno: Windows 11 Home 25H2; SQL Server Developer 17.0.1000.7; SSRS Developer Native Mode 16.0.1122.6; Microsoft Report Builder 15.1.30001.02.
- URL del portal para el navegador: http://localhost/Reports. El verificador también confirmó HTTP 200 en localhost para el portal y el servicio SOAP.
- Los seis PDF/XLSX locales están en reporting-services/validacion/salidas/, ignorado por Git. No se versionan exportaciones ni filas del pedido de prueba.

## Infraestructura

| Componente | Resultado observado | Estado |
|---|---|---|
| SQL Server | MSSQLSERVER activo; BI_OLIST accesible en localhost | PASS |
| SSRS | Developer 16.0.1122.6; SQLServerReportingServices en ejecución e inicio automático | PASS |
| Catálogo | ReportServer y ReportServerTempDB ONLINE en localhost | PASS |
| Web Service y Web Portal | http://localhost/ReportServer y http://localhost/Reports responden HTTP 200 sin redirecciones | PASS |
| Report Builder | Producto registrado en Windows, versión 15.1.30001.02 | PASS |
| Origen compartido | /OLIST360/DataSources/BI_OLIST_DW; proveedor SQL, BI_OLIST y credencial integrada habilitada. Sin contraseña guardada en el catálogo | PASS |

Se crearon las carpetas OLIST360, Pruebas, 02_Comercial, 03_Operaciones y DataSources. No se crearon cuentas especiales ni se alteraron roles. La conexión integrada local quedó comprobada por las ejecuciones reales de los tres informes.

Brave mostró un diálogo de credenciales al entrar mediante 127.0.0.1. El mismo portal y SOAP se verificaron HTTP 200 con localhost; usa esa URL en el navegador y no introduzcas credenciales en el diálogo de la IP.

## RDL, publicación y datos reales

| Prueba | Resultado real | Estado |
|---|---|---|
| XSD SSRS 2016 | Plantilla, PRE_G0_Humo, R07 y R08 validaron contra el XSD servido por esta instalación | PASS |
| PRE_G0_Humo | Publicado y renderizado; 99.441 pedidos y 112.650 líneas | PASS |
| R07, 04/09/2016–17/10/2018, todos los estados | 162 agregados; 99.441 pedidos, 99.440 con pago, 1 sin pago; total observado 16.008.872,1200 | PASS |
| R08, pedido existente de varias líneas | 1 cabecera, 2 líneas y pago agregado presente; el identificador de prueba no se guardó en Git | PASS |
| R08, identificador inexistente | Las consultas locales devolvieron 0 cabeceras y 0 líneas | PASS |
| CommandText R07/R08 frente a datasets SQL | Las cinco consultas embebidas coinciden exactamente con los cinco SQL versionados | PASS |

Los RDL publicados coinciden byte a byte con los archivos probados en el commit feff597f3d066b5f25c82d76eadd29d83c0d9b96. R07 está en /OLIST360/02_Comercial/R07_ImportesPagados y R08 en /OLIST360/03_Operaciones/R08_FichaPedido. PRE_G0_Humo permanece publicado temporalmente en /OLIST360/Pruebas/PRE_G0_Humo para la revisión local.

## Exportaciones verificadas

Cada exportación devolvió HTTP 200. Se comprobaron firma PDF y partes Open XML mínimas del XLSX (incluidos xl/workbook.xml y [Content_Types].xml). Los archivos no se abrieron todavía en Excel ni en un visor PDF.

| Informe | Formato | Bytes | SHA-256 |
|---|---:|---:|---|
| PRE_G0_Humo | PDF | 158880 | 167584B8FE074282F167BFFE9CE8848367D0D02BAF22B2BEB71D6897A1DEC795 |
| PRE_G0_Humo | XLSX | 5154 | 52CD3CD47165A34C5F33A95DE5A5176D9A54C626D987913F73EF2AA5D1C0A6CB |
| R07_ImportesPagados | PDF | 276611 | 6EF62180235A87D039FC3D786A1E99B0A69E6FC494768173EA236F6BB96354AC |
| R07_ImportesPagados | XLSX | 22290 | AFDAF1FC6F43D09C0587DDDA30CC9038078BD5A97156BF9842A9100E97CDB399 |
| R08_FichaPedido | PDF | 262880 | B5BD035EAB6C29C391E6835DE9B0FE6ABE1BECC0A41A8E6929D6C403E1E1D28F |
| R08_FichaPedido | XLSX | 7752 | 3FF252DF052068D4D3746F790BA906A77FCAD4BF6C00FC5827067986E4A81993 |

Hashes SHA-256 de los RDL versionados:

| Archivo | SHA-256 |
|---|---|
| Plantilla_OLIST360.rdl | 1BEBA8AC30DFF22686A6E376514C386A81E9C648261D859B4829A68224F37031 |
| PRE_G0_Humo.rdl | 5D07352A3631A2D16B893DDD06F1E3B69FEB062515C7B35BBF7D56EDB6E9F910 |
| R07_ImportesPagados.rdl | D6F309E3E75345A1E8A0DE74FF0DF22D5E3837F18A3A28E4A142EBF1E8052EA9 |
| R08_FichaPedido.rdl | 05923CE1C31A68C214F3FFE817AB0EF48C92BB5764E3AF229496AE1E0210B68D |

## Validaciones locales

- `Verificar-CatalogoSSRS.ps1 -SqlServerInstance localhost -PortalUrl http://localhost/Reports -ReportServerUrl http://localhost/ReportServer -TrustServerCertificate`: PASS en portal, SOAP, ambos catálogos y servicio. La primera ejecución sin el switch quedó bloqueada por el certificado SQL local autofirmado; el switch solo aplica a la conexión local del verificador.
- Validar-RDLHumo.ps1: PASS en RDL-01 a RDL-06.
- Validar-Scripts.ps1: PASS; siete archivos PowerShell parsean.
- python scripts/validar_base.py: PASS.
- python -m unittest discover -s scripts -p 'test_*.py': PASS, 14 pruebas.
- R07/R08: cinco CommandText iguales a los SQL versionados.
- git diff --check: PASS antes de documentar esta evidencia.

## Pendiente visual y alcance

- La captura [ssrs-humo-portal.png](../evidencias/ssrs-humo-portal.png) documenta la página renderizada por SSRS mediante `localhost`, con ambos conteos reales visibles. Se recortó para no mostrar el usuario de Windows ni información de pedidos. SHA-256: `B7932E6DC7E43CD3DD31FFB1B4561BEC70E09DBF65DE844A24033F5F1F735540`.
- No se abrieron todavía los PDF en un visor de escritorio ni los XLSX en Excel. El HTTP 200, la firma PDF y la estructura Open XML están comprobados; la revisión visual de los seis archivos queda pendiente.
- Brave mostró un diálogo de autenticación al usar `127.0.0.1`; la misma página carga por `http://localhost/Reports` en el navegador de Codex con autenticación Windows integrada.
- PRE_G0_Humo permanece temporalmente publicado en `/OLIST360/Pruebas/PRE_G0_Humo` para la revisión local; retirarlo al cerrar esa revisión.
- Publicar los ocho RDL restantes y los diez informes juntos cuando los compañeros los entreguen.
- Roles avanzados, cuenta dedicada, SSAS y PBIX Live quedan fuera de la prioridad simplificada vigente.

No se modificaron database/, contracts/, SSIS, SSAS, DAX ni el PBIX maestro.
