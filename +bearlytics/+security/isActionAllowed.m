function allowed = isActionAllowed(role, action)
%ISACTIONALLOWED Evalúa si un rol autenticado puede realizar una acción.
%   INPUTS: role y action ya verificados por una capa de autenticación
%   confiable. OUTPUT: logical escalar. Roles o acciones desconocidos se
%   deniegan. Esta función solo aplica autorización RBAC: no inicia sesión,
%   valida identidad ni debe exponerse como gateway.

if ~isscalar(role) || ~isscalar(action) || ismissing(string(role)) || ...
        ismissing(string(action))
    allowed = false;
    return
end
role = string(role);
action = string(action);
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
