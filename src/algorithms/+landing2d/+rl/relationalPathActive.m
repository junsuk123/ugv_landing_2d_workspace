function [active,audit] = relationalPathActive(agent,tolerance)
% RELATIONALPATHACTIVE  Audit that a graph arm's readout reaches its outputs.
% Legacy readout matrices must be nonzero. The compact encoder has fixed
% selection and checks nonzero message banks. This structural check does not
% establish input sensitivity or causal importance. Plain PPO needs no path.
if nargin < 2 || isempty(tolerance), tolerance = 1e-10; end
required = strcmp(agent.encoderSpec.mode,'context_rgat');
policyReadout = NaN; valueReadout = NaN; active = true;
if required
    if ismember(agent.encoderSpec.encoderVersion,{'rgat_minimal_v1','rgat_minimal_v2','rgat_minimal_v3'})
        % Fixed node selection has unit norm. This is a structural audit only;
        % nonzero message weights do not establish causal importance.
        policyReadout = 1; valueReadout = 1;
        pw = agent.policy.encoder.W(:,:,1:2); vw = agent.value.encoder.W(:,:,1:2);
        active = norm(pw(:))>tolerance && norm(vw(:))>tolerance;
    else
    policyReadout = norm(agent.policy.encoder.Wc,'fro')+norm(agent.policy.encoder.Wn,'fro');
    valueReadout = norm(agent.value.encoder.Wc,'fro')+norm(agent.value.encoder.Wn,'fro');
    active = policyReadout>tolerance && valueReadout>tolerance;
    end
end
audit = struct('required',required,'active',active,'tolerance',tolerance, ...
    'policyReadoutNorm',policyReadout,'valueReadoutNorm',valueReadout);
end
