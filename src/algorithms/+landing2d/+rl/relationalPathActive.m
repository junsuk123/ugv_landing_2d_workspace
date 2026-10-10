function [active,audit] = relationalPathActive(agent,tolerance)
% RELATIONALPATHACTIVE  Audit whether the typed relation path reaches outputs.
if nargin < 2 || isempty(tolerance), tolerance = 1e-10; end
validateattributes(tolerance,{'numeric'},{'scalar','real','finite','nonnegative'});
direct = isfield(agent,'encoderSpec') ...
    && ismember(agent.encoderSpec.mode,{'context_gat','context_rgat'}) ...
    && ismember(agent.encoderSpec.readout,{'grouped','grouped_factorized','observation_plus_groups'});
required = isfield(agent,'encoderSpec') ...
    && ismember(agent.encoderSpec.mode,{'context_gat','context_rgat'}) ...
    && strcmp(agent.encoderSpec.readout,'raw_plus_groups');
policyReadout = parameterNorm(agent.policy.encoder,'Wg');
valueReadout = parameterNorm(agent.value.encoder,'Wg');
if direct && strcmp(agent.encoderSpec.readout,'grouped_factorized')
    policyReadout = parameterNorm(agent.policy.encoder,'Wc') ...
        +parameterNorm(agent.policy.encoder,'Wn');
    valueReadout = parameterNorm(agent.value.encoder,'Wc') ...
        +parameterNorm(agent.value.encoder,'Wn');
end
policyHead = relationNorm(agent.policy);
valueHead = relationNorm(agent.value);
active = direct && policyReadout>tolerance && valueReadout>tolerance;
if direct && strcmp(agent.encoderSpec.readout,'observation_plus_groups')
    active = active && policyHead>tolerance && valueHead>tolerance;
end
if ~direct
    active = ~required || (policyReadout>tolerance && valueReadout>tolerance ...
    && policyHead>tolerance && valueHead>tolerance);
end
audit = struct('required',required,'active',active,'tolerance',tolerance, ...
    'policyReadoutNorm',policyReadout,'valueReadoutNorm',valueReadout, ...
    'policyRelationHeadNorm',policyHead,'valueRelationHeadNorm',valueHead);
end

function value=parameterNorm(parameters,name)
if isfield(parameters,name), value=norm(parameters.(name),'fro'); else, value=NaN; end
end

function value=relationNorm(head)
if isfield(head,'relation') && isfield(head.relation,'W')
    value=norm(head.relation.W,'fro');
else
    value=NaN;
end
end
