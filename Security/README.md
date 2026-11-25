# Sprint 2 — Seguridad de Bearlytics

## Alcance observado

El repositorio actual es un proyecto MATLAB de análisis y modelado sobre FEMTO/PRONOSTIA. No contiene una aplicación web, API HTTP, gateway, sistema de usuarios ni servicio de despliegue. Por eso este sprint define controles verificables para el código y los artefactos actuales, y una arquitectura de entrada para un gateway futuro. No presenta funciones MATLAB como si fueran una frontera de autenticación de red.

### Activos y límites de confianza

| Activo | Ubicación / límite | Requisito principal |
|---|---|---|
| Dataset FEMTO | `10. FEMTO Bearing/`, local y fuera de Git | Integridad, solo lectura, procedencia registrada |
| Código MATLAB | Repositorio GitHub | Integridad, revisión y trazabilidad de cambios |
| CSV, resultados y modelos derivados | `results/` y almacenamiento futuro | Integridad, acceso mínimo y clasificación antes de compartir |
| Credenciales y claves | No deben estar en Git ni en resultados | Confidencialidad, rotación y revocación |
| Gateway/API | No existe en este repo | Requiere diseño y revisión antes de implementación |

Los datos fuente son públicos, pero los resultados, credenciales y cualquier futuro conjunto de datos aportado por usuarios no se deben tratar automáticamente como públicos.

## Criptografía

- **En tránsito:** TLS 1.3 para cualquier futuro cliente/API; TLS 1.2 solo por compatibilidad documentada. Rechazar certificados inválidos. No inventar cifrado a nivel de aplicación en los scripts MATLAB.
- **En reposo:** cifrado administrado por el sistema de almacenamiento. Para artefactos que deban cifrarse antes de almacenarse, usar AES-256-GCM con nonce único por operación y etiqueta de autenticación; nunca diseñar un modo propio.
- **Claves:** fuera del repositorio, de los CSV, MAT, logs y argumentos de línea de comandos. Usar un gestor de secretos/KMS en despliegue, limitar lectores, registrar rotaciones y definir revocación y recuperación. No derivar una clave maestra de una contraseña fija en el código.
- **Contraseñas:** si se agrega autenticación propia, almacenar hashes Argon2id con sal aleatoria y parámetros versionados; preferir un proveedor OIDC institucional para la aplicación desplegada. Nunca cifrar contraseñas de forma reversible.
- **Integridad de artefactos:** conservar hash criptográfico y metadatos de versión del código, configuración y modelo. Verificar firma/hash antes de cargar un modelo descargado; un hash sin firma no autentica al productor.
- **Uso actual:** el repositorio no gestiona claves ni cifra archivos. No versionar secretos, datos descargados ni `.mat` de parámetros; mantener el dataset fuera de Git.

## Autenticación y RBAC

La autenticación pertenece al futuro gateway, no a funciones MATLAB que se ejecutan localmente. El gateway debe validar identidad mediante OIDC/OAuth 2.1, validar emisor, audiencia, expiración y firma de tokens, y denegar por defecto tokens ausentes o inválidos. Los tokens deben tener vida corta y no aparecer en URLs o logs.

Matriz inicial de permisos para una futura aplicación:

| Rol | Consultar predicciones | Ejecutar inferencia | Administrar modelos | Gestionar usuarios/políticas |
|---|---:|---:|---:|---:|
| Viewer | Sí | No | No | No |
| Analyst | Sí | Sí | No | No |
| Model Maintainer | Sí | Sí | Sí, con aprobación y trazabilidad | No |
| Security Admin | No por defecto | No por defecto | No | Sí |

Reglas: mínimo privilegio, separación de funciones, autorización en cada operación y recurso, denegación por defecto, cuentas de servicio no interactivas y permisos explícitos para datos/condiciones. No conceder privilegios por nombre de usuario ni por estar en una red interna. Registrar actor, acción, recurso, resultado y correlación; nunca registrar tokens, contraseñas, claves ni señales completas.

## Seguridad del gateway futuro

No hay gateway que pueda endurecerse en el código actual. Antes de desplegar una API para predicción, la capa de entrada debe aplicar:

1. TLS, identidad OIDC y autorización RBAC en cada ruta.
2. Validación estricta de esquema, tipos, rangos, tamaños y tipos MIME; rechazar campos desconocidos y entradas no finitas.
3. Límites de tamaño, concurrencia, tiempo y tasa; cuotas por identidad; protección contra abuso y agotamiento de recursos.
4. Separación entre plano de control (usuarios, modelos, políticas) y plano de inferencia.
5. Carga de modelos solo desde almacenamiento aprobado; verificación de firma/hash, versión y compatibilidad antes de ejecutar.
6. Errores sin stack traces, rutas, secretos ni detalles internos; logs de auditoría protegidos contra modificación.
7. Encabezados y configuración seguros, CORS con allowlist si aplica, sin endpoints administrativos públicos y sin confianza implícita por IP.
8. Pruebas de autorización negativa, abuso de límites, replay y entradas malformadas en CI antes del despliegue.

## Threat model — STRIDE + CIA+

Escala cualitativa inicial: alto/medio/bajo. Debe revisarse al definir usuarios, despliegue y flujos reales; no es una certificación.

| STRIDE | Escenario | Activo / impacto CIA+ | Control y evidencia esperada | Riesgo residual |
|---|---|---|---|---|
| Spoofing | Robo o falsificación de identidad para invocar o administrar modelos | Confidencialidad, integridad, autenticidad | OIDC, validación de issuer/audience/firma, expiración corta, MFA para administración; pruebas de token inválido/expirado | Medio: robo de sesión en el cliente |
| Tampering | Alterar código, CSV, configuración o modelo | Integridad, autenticidad, responsabilidad | PR aprobado, CI, hash firmado de artefactos y verificación al cargar; evidencia de procedencia | Medio: compromiso de cuenta con permiso de aprobación |
| Repudiation | Negar una modificación o inferencia privilegiada | Responsabilidad, integridad | Auditoría append-only con identidad, acción, hora sincronizada y correlación; retención definida | Medio: falla del sistema de logging |
| Information disclosure | Exponer credenciales, datos, predicciones o resultados | Confidencialidad, privacidad | Secretos fuera de Git, TLS, permisos mínimos, logs redactados, clasificación de outputs | Medio: copias locales no administradas |
| Denial of service | Inferencias costosas, archivos enormes o automatización abusiva | Disponibilidad, integridad del servicio | Límites de payload, cuotas, timeout, concurrencia acotada y circuit breaker en gateway | Medio: abuso distribuido supera la cuota |
| Elevation of privilege | Analyst obtiene funciones de administración o modifica modelos | Integridad, autenticidad, responsabilidad | RBAC por recurso/acción, separación de funciones, reautenticación para cambios críticos y pruebas negativas | Bajo/medio: error de política |

**CIA+ usado aquí:** confidencialidad, integridad y disponibilidad, más autenticidad y responsabilidad/trazabilidad. La disponibilidad del pipeline local también depende de copias reproducibles y versiones controladas; no se debe prometer disponibilidad de un servicio que aún no existe.

## Aceptación del sprint

- Este documento identifica explícitamente controles actuales y futuros; no afirma que haya gateway o autenticación implementados.
- Cero secretos, claves o tokens en commits, CSV, MAT y logs.
- Los cambios a código, políticas o modelos siguen PR, revisión humana y CI.
- Antes de implementar el gateway: elegir proveedor OIDC/KMS, definir rutas y esquema, clasificar datos, acordar retención de logs y probar la matriz RBAC con casos positivos y negativos.
- La siguiente entrega de implementación debe ser un servicio/gateway separado con tecnología y entorno definidos; no simular seguridad de red desde MATLAB.
