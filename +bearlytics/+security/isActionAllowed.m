function allowed = isActionAllowed(role, action)
%ISACTIONALLOWED Evalúa si un rol autenticado puede realizar una acción.
%   INPUTS: role y action ya verificados por una capa de autenticación
%   confiable. Se aceptan strings escalares y vectores fila char.
%   OUTPUT: logical escalar. Roles o acciones desconocidos se
%   deniegan. Esta función solo aplica autorización RBAC: no inicia sesión,
%   valida identidad ni debe exponerse como gateway.

if ischar(role) && isrow(role)
    role = string(role);
end
if ischar(action) && isrow(action)
    action = string(action);
end
if ~isstring(role) || ~isscalar(role) || ismissing(role) || ...
        ~isstring(action) || ~isscalar(action) || ismissing(action)
    allowed = false;
    return
end
policy = struct( ...
    'viewer', ["predictions:read"], ...
    'analyst', ["predictions:read", "predictions:run"], ...
    'model_maintainer', ["predictions:read", "predictions:run", "models:publish"], ...
    'security_admin', ["users:manage", "policies:manage"]);
if ~isfield(policy, char(role))
    allowed = false;
    return
end
allowed = any(policy.(char(role)) == action);
end
