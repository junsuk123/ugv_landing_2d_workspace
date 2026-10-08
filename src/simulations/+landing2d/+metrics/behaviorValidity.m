function out = behaviorValidity(probe,requestedAction,config)
% BEHAVIORVALIDITY  Independent physical validity of one requested command (evaluation only).
%   out = landing2d.metrics.behaviorValidity(probe,requestedAction,config)
% PROBE (fixed-probe bank, landing2d.probe.buildBank):
%   drone    true state [x;z;vx;vz;theta;pitchRate;collectiveThrust]
%   pad      true pad [x;z;vx;ax]
%   context  reference-observation flags (visionUpdated, estimateInitialized,
%            visionAge, landingInhibited, abortRequested, finalDescentActive)
%   admissible  optional precomputed landing2d.metrics.admissibleActions result
% REQUESTEDACTION  [a_x; a_z] after tanh and axis limits, before the supervisor.
% CONFIG  c (configuration), horizon [s] and kappa (frozen on validation), gridPoints.
% The judge uses relative position/velocity, control and braking margins and
% the camera projection through a short fixed-command prediction with the
% existing dynamics on a copied state; ontology nodes, attention, rewards and
% the supervisor mode are not used, and the supervisor never corrects the
% command here. Valid means the command lies in the admissible set
% (landing2d.metrics.admissibleActions), not that it equals one command.
%   valid              requested command satisfies every active constraint
%   applicable         false when the supervisor overrides the policy (backup
%                      recovery) or no grid command is safe; reason recorded
%   context_id         'vision/height/decision' from the reference observation
%   constraint_margins contact, braking [m], fov [rad], tracking, approach
%                      (threshold minus quantity, >= 0 holds; NaN if inactive)
%   reason_codes       violated constraints or the reason for non-applicability
c = config.c;
ctx = probe.context;
h = probe.drone(2)-probe.pad(2);
out = struct('valid',false,'applicable',false, ...
    'context_id',landing2d.metrics.validityContext(ctx,h,c), ...
    'constraint_margins',struct('contact',NaN,'braking',NaN,'fov',NaN, ...
        'fovActive',false,'tracking',NaN,'approach',NaN),'reason_codes',{{}});
if ctx.abortRequested
    out.reason_codes = {'supervisor_override'};
    return;
end
if isfield(probe,'admissible') && ~isempty(probe.admissible)
    adm = probe.admissible;
else
    adm = landing2d.metrics.admissibleActions(probe,config,config.horizon,config.kappa);
end
k = find(abs(adm.horizons-config.horizon) < 1e-9,1);
assert(~isempty(k),'landing2d:ValidityHorizon', ...
    'The admissible set lacks horizon %g s.',config.horizon);
if ~adm.anySafe(k)
    out.reason_codes = {'no_safe_action'};
    return;
end
out.applicable = true;
steps = max(1,round(config.horizon/c.experiment.physicsDt));
trace = landing2d.metrics.predictFixedCommand(landing2d.metrics.probeState(probe), ...
    landing2d.metrics.probePad(probe),requestedAction(:),steps, ...
    landing2d.metrics.probeStatus(probe),c);
m = landing2d.metrics.commandMargins(trace,steps,c);
rules = adm.rules;
tracking = NaN; approach = NaN;
if rules.horizontalActive && isfinite(adm.horizontalBest(k))
    tracking = adm.horizontalBest(k)+config.kappa*adm.horizontalSpread(k)+1e-9 ...
        -m.(rules.horizontalMetric);
end
if rules.verticalActive && isfinite(adm.verticalBest(k))
    approach = adm.verticalBest(k)+config.kappa*adm.verticalSpread(k)+1e-9-m.height;
end
reasons = {};
if m.contact < 0, reasons{end+1} = m.reason; end
if m.braking < 0 && m.contact >= 0, reasons{end+1} = 'braking_margin'; end
if adm.fovActive(k) && m.fov < 0, reasons{end+1} = 'fov_loss'; end
if tracking < 0, reasons{end+1} = 'tracking_regression'; end
if approach < 0, reasons{end+1} = 'approach_regression'; end
out.constraint_margins = struct('contact',m.contact,'braking',m.braking, ...
    'fov',m.fov,'fovActive',adm.fovActive(k),'tracking',tracking,'approach',approach);
out.reason_codes = reasons;
out.valid = isempty(reasons);
end
