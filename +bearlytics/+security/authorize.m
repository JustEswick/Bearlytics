function allowed = authorize(role, action)
%AUTHORIZE Evalúa una política RBAC mínima con denegación por defecto.
%   INPUTS: rol y acción ya verificados por una capa de autenticación
%   confiable. OUTPUT: logical escalar. Roles desconocidos, acciones
%   desconocidas y entradas no escalares se deniegan.
%   Esta función NO autentica identidades ni debe exponerse como gateway.

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
