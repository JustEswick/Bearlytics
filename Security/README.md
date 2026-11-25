# Seguridad — Sprint 2

## Decisiones de despliegue

- **Aplicación/entrada:** MATLAB Web App Server R2026b standalone; es el punto de entrada y control de acceso de la app. No hay un gateway HTTP personalizado en el repositorio.
- **Proveedor OIDC:** Keycloak, con Bearlytics registrado como cliente confidencial OIDC. Se elige por ser autogestionable y no atar la identidad a un proveedor cloud; Web App Server se integra directamente con OIDC.
- **Gestor de claves y firma:** HashiCorp Vault Transit, accesible solo desde la red de servidor por HTTPS. Se usa para generar claves de datos envueltas (AES-256-GCM), descifrarlas según política y firmar/verificar artefactos. La clave de datos en claro solo vive durante la operación de cifrado/descifrado.
- **Firma del modelo:** ECDSA P-256 con SHA-256, clave privada no exportable administrada por Vault Transit. El consumidor verifica la firma antes de abrir el artefacto; el hash por sí solo no prueba quién lo produjo. La firma cubre los bytes exactos del sobre persistido (cabecera, nonce y ciphertext/tag) con serialización canónica documentada por el productor.

La decisión de Vault presupone que el responsable del despliegue puede proporcionar un servicio Vault Transit disponible. Si la institución ya opera otro KMS, debe sustituir esta decisión mediante cambio revisado, no mezclar proveedores ni guardar claves en MATLAB.

## Activos y límites de confianza

| Activo | Ubicación / límite | Requisito principal |
|---|---|---|
| Dataset FEMTO | `10. FEMTO Bearing/`, local, fuera de Git | Integridad, solo lectura, procedencia registrada |
| Código MATLAB | Repositorio GitHub | Integridad, revisión y trazabilidad |
| App y predicciones | MATLAB Web App Server y sus usuarios | Autenticación OIDC, autorización mínima, TLS y auditoría |
| Modelo exportado | Artefacto firmado y cifrado en almacenamiento aprobado | Confidencialidad, integridad, autenticidad y versión |
| Secretos/credenciales | `webapps_private` del servidor o Vault | Acceso restringido, rotación y revocación; nunca Git ni cliente |
| KMS/IdP | Servicios de infraestructura separados de la app | TLS validado, cuenta de servicio y permisos mínimos |

Los datos fuente públicos no hacen públicos los resultados ni los datos operativos futuros.

## Criptografía y artefactos

- `+bearlytics/+security/sealArtifact.m` y `openArtifact.m` usan AES-256-GCM con nonce aleatorio de 96 bits y etiqueta de 128 bits. La API exige `headerBytes` UTF-8 no vacío como AAD; `openArtifact` también exige la cabecera esperada y rechaza diferencias antes de devolver plaintext. El productor debe usar exactamente los bytes `header` devueltos por `[payload, header] = bearlytics.model.encodeModelArtifact(artifact)`.
- La cabecera contiene `schemaVersion`, `modelId`, `modelVersion` y `modelType`. Al abrir, el consumidor obtiene la cabecera esperada de una allowlist/configuración aprobada (incluidos `modelId` y `modelVersion`), la serializa en el mismo formato UTF-8/canónico y nunca usa `sealed.headerBytes` como fuente de confianza. Después de `decodeModelArtifact`, debe comprobar que la cabecera decodificada coincide con esos mismos bytes AAD.
- El sobre v2 es incompatible con sobres v1. Los modelos existentes deben volver a sellarse con cabecera AAD antes de ser aceptados por la app.
- Vault Transit genera una data key de 256 bits y devuelve su copia envuelta. El struct v2 de `sealArtifact` contiene solo `version`, `algorithm`, `nonce`, `headerBytes` y `ciphertextAndTag`; no contiene la data key envuelta, metadata KMS ni firma. El adaptador Vault pendiente debe guardarlos en un contenedor exterior versionado junto con el struct cifrado y la firma. Nunca persistir la clave en claro; borrar referencias temporales y denegar si Vault no responde.
- El productor firma el sobre persistido con una clave `ecdsa-p256` de Vault Transit y `sha2-256`. La verificación usa el endpoint/operación pública de Vault Transit o la clave pública fijada en configuración confiable. Verificar firma antes de pedir descifrado; comparar modelo, versión y clave de firma permitidas.
- Secretos OIDC y tokens de Vault se provisionan fuera de Git y con rotación. No pasarlos en argumentos de proceso, URLs, artefactos o logs.

## Autenticación, autorización y puerta de entrada

Web App Server se configura con OIDC ante Keycloak. Sus roles integrados son **Author** y **User**: Author puede administrar/subir apps; User solo ejecutarlas. Las políticas por app/carpeta restringen quién puede ejecutar Bearlytics. El producto requiere SSL habilitado para autenticación y control de acceso.

Los roles de servidor no son los roles del dominio. La matriz de Bearlytics (`isActionAllowed.m`) separa `viewer`, `analyst`, `model_maintainer` y `security_admin`; `authorizePrincipal.m` permite actuar solo si el principal ya tiene identidad autenticada y rol de fuente confiable. No valida tokens ni debe aceptar datos de identidad o rol enviados desde el navegador. Si la app no puede recibir claims verificados a través de una interfaz documentada y soportada, usar en producción únicamente las restricciones de acceso de Web App Server; no inventar un puente de claims.

| Rol Bearlytics | Leer predicciones | Ejecutar inferencia | Publicar modelos | Gestionar seguridad |
|---|---:|---:|---:|---:|
| `viewer` | Sí | No | No | No |
| `analyst` | Sí | Sí | No | No |
| `model_maintainer` | Sí | Sí | Sí | No |
| `security_admin` | No | No | No | Sí |

Aplicar mínimo privilegio, separación de funciones, denegación por defecto y auditoría de actor/acción/recurso/resultado, sin guardar tokens, claves ni señales completas.

## STRIDE + CIA+ para MATLAB Web App Server

Escala cualitativa inicial; revisar al contar con una instancia real, configuración del IdP y flujos de datos.

| STRIDE | Escenario en el despliegue elegido | Propiedades afectadas | Control/evidencia | Residual |
|---|---|---|---|---|
| Spoofing | Robo de cuenta/sesión OIDC o suplantación del IdP | Confidencialidad, autenticidad | Keycloak OIDC, TLS validado, sesiones/token con expiración, MFA para Author/admin; prueba de login inválido | Medio: compromiso del endpoint |
| Tampering | Modificación del JSON/ciphertext o sustitución por modelo distinto | Integridad, autenticidad | AES-GCM con cabecera AAD, firma ECDSA verificada antes de descifrar, allowlist de `modelId/version`; prueba de alteración y replay de versión | Bajo/medio: abuso de llave de firma |
| Repudiation | Negar despliegue, publicación o uso administrativo | Responsabilidad/trazabilidad | Auditoría de Web App Server, Keycloak y Vault con hora sincronizada; correlacionar actor, versión y resultado; revisar retención | Medio: pérdida/alteración del colector |
| Information disclosure | Exposición de modelo, predicciones, OIDC secret o data key | Confidencialidad | TLS en servidor/IdP/Vault, AES-GCM en almacenamiento, secreto en `webapps_private`/Vault, logs redactados | Medio: captura en proceso mientras se descifra |
| Denial of service | Cargas demasiado grandes, concurrencia o Vault no disponible | Disponibilidad | Límites y timeouts de servidor/proxy, cuotas, concurrencia acotada, health checks y fail-closed al no poder verificar/descifrar | Medio: caída de infraestructura compartida |
| Elevation of privilege | User obtiene Author o un analista publica modelo | Integridad, autenticidad, responsabilidad | `webapps_app_roles.json`, política app-specific, RBAC interno con principal confiable, permisos Vault separados (sign vs decrypt), pruebas negativas | Bajo/medio: error de asignación de grupo |

**CIA+:** confidencialidad, integridad, disponibilidad, autenticidad y responsabilidad/trazabilidad. La disponibilidad aún depende del SLA/capacidad de Web App Server, Keycloak y Vault; no se afirma que exista despliegue operativo.

## Configurar el servidor R2026b

Usar MATLAB Web App Server standalone (no el servidor de desarrollo de MATLAB Compiler). Los archivos operativos se colocan en el directorio `config/webapps_private`, legible solo por la cuenta del servicio:

- Windows: `%ProgramData%\MathWorks\webapps\R2026b\config\webapps_private`
- Linux: `/local/MathWorks/webapps/R2026b/config/webapps_private`

### TLS del servidor

1. Obtener de una CA un certificado PEM para el hostname DNS público/interno y su llave privada PEM de al menos 2048 bits. El certificado puede incluir la cadena intermedia concatenada; la llave no puede estar cifrada con contraseña.
2. Guardarlos bajo `webapps_private` con lectura solo para la cuenta del servicio.
3. Desde el directorio `script` de MATLAB Web App Server, configurar y reiniciar:

```text
webapps-config set ssl_certificate_file <ruta-certificado.pem>
webapps-config set ssl_private_key_file <ruta-llave-privada.pem>
webapps-config set ssl_enabled true
```

4. Verificar por HTTPS que el hostname coincide, la cadena es válida y los clientes rechazan certificados inválidos. Si se usa un reverse proxy, mantener HTTPS entre proxy y Web App Server y no exponer su puerto directo.

### Keycloak OIDC

1. Crear un realm institucional y cliente confidencial Bearlytics. Configurar redirect exacto `https://<host>:<puerto>/webapps/extauth/callback`, scopes `openid profile email`, flujo Authorization Code y grupos/atributos de roles. No habilitar wildcard redirects.
2. Con TLS activo, crear `webapps_authn.json` en `webapps_private` con esquema R2026b. El client secret se inserta solo en el servidor:

```json
{
  "version": "1.3.0",
  "type": "oidc",
  "authnConfig": {
    "issuer": "https://<keycloak-host>/realms/<realm>",
    "clientId": "bearlytics-webapp",
    "clientSecret": "<secret provisionado fuera de Git>",
    "redirectUrl": "https://<webapp-host>:<puerto>/webapps/extauth/callback",
    "scope": ["openid profile email"]
  },
  "appConfig": {
    "displayName": "email",
    "tokenExpirationMin": "30",
    "userAttributeName": "email",
    "groupAttributeName": "groups",
    "prompt": false,
    "timeoutInSeconds": "30",
    "checkSSLCA": "true",
    "trustedSSLCA": "<ruta CA si aplica en Linux/macOS>"
  }
}
```

4. Crear `webapps_app_roles.json`: asignar `Author` solo al grupo mínimo de despliegue y `User` a usuarios que ejecutan la app. Crear `webapps_acc_ctl.json` para permitir `execute` de la app solo al grupo de usuarios. Los nombres/casing deben coincidir exactamente con claims de Keycloak. No conceder `modify` al grupo usuario.
5. Reiniciar el servicio según el procedimiento de R2026b. Probar login con usuario permitido, usuario sin grupo, sesión expirada, redirect incorrecto y pérdida de Keycloak. La autenticación debe fallar cerrada.

### Vault Transit

El admin provisiona Vault Transit sobre HTTPS, crea una clave simétrica AES-256 para envolver data keys y una clave ECDSA P-256 separada para firmar. La app obtiene identidad de workload/servicio de corta duración; no se reutiliza el token OIDC del usuario para KMS. Política mínima: el proceso de build puede firmar; la app puede verificar y desencriptar data keys; usuarios web no pueden invocar Transit.

Para sellar: pedir data key plaintext+wrapped a Transit, obtener `[payload, headerBytes]` de `bearlytics.model.encodeModelArtifact(artifact)` y usar esos bytes exactos con `sealArtifact(payload, keyBytes, headerBytes)`. El struct v2 devuelto solo contiene `version`, `algorithm`, `nonce`, `headerBytes` y `ciphertextAndTag`; el adaptador Vault debe guardar la data key envuelta, metadata KMS y firma en un contenedor exterior versionado. Firmar el sobre persistido exacto y limpiar el buffer local. Para abrir: validar modelo/versión contra una allowlist confiable, verificar firma ECDSA, derivar `expectedHeaderBytes` de esa configuración (nunca de `sealed.headerBytes`), pedir `decrypt` de wrapped data key y abrir con `openArtifact`. Después de `decodeModelArtifact`, comprobar que la cabecera coincide byte a byte con la AAD. Fallar cerrado ante cualquier error. Rotar versión de claves y conservar capacidad de descifrar versiones activas durante migración.

## Referencias oficiales

- [MathWorks: autenticación OIDC/LDAP](https://www.mathworks.com/help/webappserver/ug/authentication.html)
- [MathWorks: roles de servidor](https://www.mathworks.com/help/webappserver/ug/role-based-access.html)
- [MathWorks: políticas por app/carpeta](https://www.mathworks.com/help/webappserver/ug/policy-based-access.html)
- [MathWorks: habilitar SSL](https://www.mathworks.com/help/webappserver/ug/enable-ssl.html)
- [MathWorks: webapps-config](https://www.mathworks.com/help/webappserver/ref/webappsconfig.html)
- [HashiCorp: Vault Transit API](https://developer.hashicorp.com/vault/api-docs/secret/transit)
- [Keycloak: documentación de servidores](https://www.keycloak.org/documentation)
