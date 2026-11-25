function allowed = authorizePrincipal(principal, action)
%AUTHORIZEPRINCIPAL Autoriza una acción para una identidad ya autenticada.
%   INPUTS: principal struct escalar con authenticated=true, subject no vacío
%   y role asignado por una capa confiable; action es una acción de la
%   política RBAC. OUTPUT: logical escalar; entradas ausentes/inválidas
%   deniegan. Esta función no valida tokens ni autentica la identidad.

allowed = false;
if ~isstruct(principal) || ~isscalar(principal) || ...
        ~all(isfield(principal, {'authenticated', 'subject', 'role'}))
    return
end
if ~islogical(principal.authenticated) || ~isscalar(principal.authenticated) || ...
        ~principal.authenticated || ~isValidText(principal.subject) || ...
        ~isValidText(principal.role)
    return
end
allowed = bearlytics.security.isActionAllowed(principal.role, action);
end

function valid = isValidText(value)
valid = (ischar(value) && isrow(value) && ~isempty(strtrim(value))) || ...
    (isstring(value) && isscalar(value) && ~ismissing(value) && strlength(strtrim(value)) > 0);
end
