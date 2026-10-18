function [active,audit] = relationalPathActive(agent,tolerance)
% RELATIONALPATHACTIVE  Audit that a graph arm's readout reaches its outputs.
% For context_rgat the Actor and Critic readouts (Wc, Wn) must be nonzero;
% plain PPO has no relational path and is reported as not required.
if nargin < 2 || isempty(tolerance), tolerance = 1e-10; end
required = strcmp(agent.encoderSpec.mode,'context_rgat');
policyReadout = NaN; valueReadout = NaN; active = true;
if required
    policyReadout = norm(agent.policy.encoder.Wc,'fro')+norm(agent.policy.encoder.Wn,'fro');
    valueReadout = norm(agent.value.encoder.Wc,'fro')+norm(agent.value.encoder.Wn,'fro');
    active = policyReadout>tolerance && valueReadout>tolerance;
end
audit = struct('required',required,'active',active,'tolerance',tolerance, ...
    'policyReadoutNorm',policyReadout,'valueReadoutNorm',valueReadout);
end
