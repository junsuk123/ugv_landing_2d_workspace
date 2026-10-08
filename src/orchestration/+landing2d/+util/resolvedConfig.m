function [json,hash] = resolvedConfig(c)
% RESOLVEDCONFIG  JSON text and SHA-256 hash of the configuration actually run.
% Function handles are written as text, the per-episode current scenario is
% dropped, and non-finite numbers are written as strings so the hash keeps
% Inf, -Inf and NaN apart. Used for run identity in logs and for
% resolved_config.json.
if isfield(c,'experiment') && isfield(c.experiment,'currentScenario')
    c.experiment = rmfield(c.experiment,'currentScenario');
end
json = jsonencode(sanitize(c),'PrettyPrint',true);
hash = landing2d.util.sha256(json);
end

function value = sanitize(value)
if isstruct(value)
    names = fieldnames(value);
    for k = 1:numel(value)
        for i = 1:numel(names)
            value(k).(names{i}) = sanitize(value(k).(names{i}));
        end
    end
elseif iscell(value)
    for i = 1:numel(value), value{i} = sanitize(value{i}); end
elseif isa(value,'function_handle')
    value = func2str(value);
elseif isnumeric(value) && ~all(isfinite(value(:)))
    value = arrayfun(@num2str,value,'UniformOutput',false);
end
end
