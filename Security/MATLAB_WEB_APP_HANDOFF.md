# Instructivo de integración: Bearlytics en MATLAB Web App Server

Este documento prepara la integración del Sprint 2 para el agente que implemente la app MATLAB. Está basado en **MATLAB Web App Server R2026b**, con **Keycloak OIDC** como IdP y **HashiCorp Vault Transit** como gestor de claves y firma. Es una guía para el operador y el desarrollador; no contiene secretos ni declara que estos servicios estén ya desplegados.

## Estado y alcance

- El repositorio contiene utilidades MATLAB AES-256-GCM y autorización RBAC (`+bearlytics/+security/`).
- El helper `authorizePrincipal` solo autoriza una identidad que ya fue autenticada y cuyo rol provino de una fuente confiable. No valida tokens OIDC ni es un gateway HTTP.
- MATLAB Web App Server provee autenticación OIDC/LDAP, roles de servidor **Author/User** y control por política para acceso a apps/carpetas. No equivale a los roles de dominio de Bearlytics (`viewer`, `analyst`, etc.).
- Falta la app App Designer, su empaquetado `.ctf`, las instancias/configuración reales de Web App Server, Keycloak y Vault y el adaptador de servicios en MATLAB. Esos pasos requieren al agente que implementa la app y al administrador.

## Instrucciones para el agente que implementa la app

1. Crear la app exclusivamente con **App Designer**; las apps deben empaquetarse con Web App Compiler y desplegarse en MATLAB Web App Server. No reemplazarlo con una API casera en MATLAB.
2. No construir formularios de login ni aceptar `role`, `subject`, `authenticated`, claims o permisos enviados desde controles del navegador. La app no debe confiar en valores editables por el usuario.
3. Antes de habilitar una acción sensible, obtener la identidad/rol desde un contexto del servidor que MathWorks documente para la configuración desplegada. Si el contexto verificado no está disponible dentro de la app, aplicar los permisos a nivel servidor (Author/User y política de ejecución por app/carpeta) y no inventar custom claims.
4. Para aplicar permisos de dominio, llamar `bearlytics.security.authorizePrincipal(principal, action)` solo después de construir `principal` desde esa fuente autenticada. Acciones definidas: `predictions:read`, `predictions:run`, `models:publish`, `users:manage`, `policies:manage`. Los roles y matriz están en `isActionAllowed.m`; cualquier valor desconocido se deniega.
5. No escribir tokens, claves, secretos, datos de usuario ni contenido sensible en URLs, errores, telemetría, archivos del repo o logs de la app.
6. Cargar solo artefactos con esquema y versión esperados. Al cifrar/abrir un modelo, usar como datos autenticados adicionales (AAD) una serialización estable de su identidad y versión, por ejemplo `model-id:<id>;version:<version>`, y exigir el mismo contexto al abrirlo. La AAD no es secreta; la clave sí.
7. Pedir a Vault Transit una data key AES-256 envuelta; pasar la parte plaintext a `sealArtifact` solo en memoria y persistir únicamente la copia wrapped. Para abrir, verificar primero la firma, pedir a Vault la data key y luego invocar `openArtifact`.
8. Firmar el sobre persistido con una clave ECDSA P-256 administrada por Vault Transit (SHA-256). Verificar la firma antes de descifrar; usar permisos separados para firma del build, verificación y descifrado de la app.
9. Incluir pruebas de autorización denegada por defecto, usuario no autenticado, rol de solo lectura, usuario autorizado, cabecera/AAD incorrecta, firma inválida y artefacto alterado. No desplegar hasta que pasen pruebas en MATLAB R2026b y revisión humana.

## Preparación del servidor (operador / administrador)

Usar el producto standalone MATLAB Web App Server; las funciones de autenticación y control de acceso no están disponibles en el servidor de desarrollo incluido con MATLAB Compiler. Los pasos completos y ejemplos están en `Security/README.md`.

1. Registrar Bearlytics como cliente confidencial OIDC en Keycloak. Registrar el callback HTTPS exacto `https://<host>:<puerto>/webapps/extauth/callback` y limitar redirect/scopes/grupos a lo requerido.
2. Copiar `webapps_authn.json` al directorio `config/webapps_private` de la instalación, con permisos de lectura solo para la cuenta de servicio. El ejemplo de esquema se muestra debajo; reemplazar marcadores en el servidor, nunca en Git. No guardar el archivo operativo aquí.
3. Configurar `webapps_app_roles.json` en el mismo directorio y asignar el rol Author al mínimo de publicadores; el resto de usuarios autorizados serán User.
4. Configurar `webapps_acc_ctl.json` para restringir qué sujetos/grupos pueden ejecutar la app. Confirmar que los atributos de usuario/grupo coinciden exactamente con los claims/atributos que entrega el IdP. Probar con un usuario permitido y otro denegado.
5. Proteger el servidor con firewall/segmentación de red, TLS válido, actualizaciones y cuenta de servicio de privilegios mínimos. MATLAB Web App Server está pensado para intranet de confianza, no para publicar directamente en Internet.
6. Provisionar Vault Transit con claves distintas: AES-256 para envolver data keys y ECDSA P-256/SHA-256 para firma. Usar TLS y autenticación de workload de vida corta; limitar ACL de sign/decrypt/verificación y auditar rotación/revocación.
7. Generar el `.ctf` en un entorno de build confiable, firmar el sobre del modelo con Vault Transit, revisar contenidos y dependencias, desplegar por procedimiento del administrador y conservar versión/hash del artefacto y commit fuente.

Ubicación documentada de `webapps_private` en Windows: `%ProgramData%\MathWorks\webapps\R2026b\config\webapps_private`; en Linux: `/local/MathWorks/webapps/R2026b/config/webapps_private`.

### Esquema OIDC (plantilla, completar solo en el servidor)

La plantilla no es un archivo operativo. `clientSecret` debe insertarse únicamente en el `webapps_authn.json` protegido del servidor:

```json
{
  "version": "1.3.0",
  "type": "oidc",
  "authnConfig": {
    "issuer": "<issuer URI del IdP>",
    "clientId": "<client ID>",
    "clientSecret": "<secreto guardado solo en el servidor>",
    "redirectUrl": "https://<host>:<puerto>/webapps/extauth/callback",
    "scope": ["openid profile email"]
  },
  "appConfig": {
    "port": "<puerto OIDC configurado>",
    "displayName": "email",
    "tokenExpirationMin": "60",
    "userAttributeName": "email",
    "groupAttributeName": "groups",
    "prompt": false,
    "timeoutInSeconds": "30",
    "checkSSLCA": "true",
    "trustedSSLCA": "<ruta CA en Linux/macOS; ajustar según plataforma>"
  }
}
```

Los nombres de atributos, formato del issuer/redirect y opciones de certificados se deben contrastar con el IdP y la guía de la versión instalada. No usar `checkSSLCA=false` en producción.

### Política mínima de publicación y ejecución

Usar `webapps_app_roles.json` para que el grupo administrador de despliegue tenga `Author` y los usuarios finales tengan `User`. Usar `webapps_acc_ctl.json` para permitir `execute` sobre la app únicamente al grupo usuario autorizado. No conceder `modify` a usuarios finales. Los dos roles del servidor son únicamente `Author` y `User`; los roles internos de Bearlytics requieren contexto autenticado adicional dentro de la app si se necesitan controles más finos.

## Revisión STRIDE + CIA para el handoff

| Amenaza | Activo / impacto | Control que debe verificarse en la integración |
|---|---|---|
| Suplantación (S) | identidad de usuarios; autenticación OIDC por servidor, TLS, tokens con expiración; no aceptar claims del cliente |
| Manipulación (T) | modelo y datos; AES-GCM con AAD, validación de esquema, versión y hash del artefacto |
| Repudio (R) | cambios/publicación; auditoría de IdP/servidor y registro de actor, acción, resultado y versión sin secretos |
| Divulgación (I) | artefactos, secretos y logs; mínimo privilegio, cifrado, TLS, red privada y redacción de logs |
| Denegación de servicio (D) | disponibilidad; límites de tamaño/tiempo, concurrencia controlada, monitoreo y cuotas del servidor |
| Elevación de privilegios (E) | ejecución/publicación; separación Author/User, policy-based access, RBAC interno y denegación por defecto |

Verificar las propiedades CIA: **confidencialidad** (TLS, cifrado y secretos fuera de Git), **integridad** (GCM/AAD, hashes y revisión de artefactos), **disponibilidad** (capacidad, recuperación y monitoreo). Registrar también autenticidad y trazabilidad como propiedades adicionales.

## Checklist de cierre de integración

- [ ] App creada con App Designer y empaquetada en `.ctf` desde MATLAB Compiler.
- [ ] IdP OIDC elegido, cliente registrado, redirect verificado y secret puesto solo en el servidor.
- [ ] SSL válido; el servidor no queda publicado directamente a Internet.
- [ ] Roles Author/User y política de ejecución probados con casos permitidos y denegados.
- [ ] Si hay RBAC de dominio, principal/rol viene de una fuente autenticada y no del navegador.
- [ ] KMS elegido, permisos mínimos para la identidad de ejecución, rotación/revocación probadas.
- [ ] Pruebas de cifrado, AAD, manipulación, autorización y registros completadas.
- [ ] Revisión de seguridad, evidencia de ejecución y aprobación del owner antes de merge/despliegue.

## Referencias oficiales

- [Autenticación en MATLAB Web App Server](https://www.mathworks.com/help/webappserver/ug/authentication.html)
- [Role-Based Access](https://www.mathworks.com/help/webappserver/ug/role-based-access.html)
- [Policy-Based Access](https://www.mathworks.com/help/webappserver/ug/policy-based-access.html)
- [Web Apps: crear con App Designer, empaquetar y alojar](https://www.mathworks.com/help/compiler/web-apps.html)
