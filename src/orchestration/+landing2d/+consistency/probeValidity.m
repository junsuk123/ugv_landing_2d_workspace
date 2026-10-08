function result = probeValidity(bank,actions,frozen,grid,c,options)
% PROBEVALIDITY  Validity of one policy's probe commands at every noise scale.
% ACTIONS from landing2d.rl.probeActions (requested commands before the
% supervisor), FROZEN from landing2d.consistency.calibrateValidity (validation),
% GRID from landing2d.consistency.validityGrid for the same bank. The judge,
% context and admissible set depend only on the probe (true state, reference
% context), never on the policy; the requested command is the only input that
% differs between methods, seeds and scales.
%   valid            P x nScale
%   applicable       1 x P (supervisor does not override; some safe command exists)
%   contextId        1 x P 'vision/height/decision' (reference observation)
%   exclusionReason  1 x P '' / 'supervisor_override' / 'no_safe_action'
%   margins          contact, braking [m], fov [rad], tracking, approach (P x nScale)
%   reasons          P x nScale violated constraints ('a;b')
if nargin < 6, options = struct(); end
assert(strcmp(frozen.schemaVersion,'validity_frozen_v1'),'landing2d:ValidityFrozen', ...
    'Unknown frozen validity configuration.');
assert(strcmp(grid.bankConfigHash,bank.meta.configHash),'landing2d:ValidityGrid', ...
    'The validity grid belongs to another probe bank.');
k = find(abs(grid.horizons-frozen.horizon) < 1e-9,1);
assert(~isempty(k) && grid.gridPoints == frozen.gridPoints,'landing2d:ValidityGrid', ...
    'The validity grid lacks the frozen horizon or grid size.');
config = struct('c',c,'horizon',frozen.horizon,'kappa',frozen.kappa, ...
    'gridPoints',frozen.gridPoints);
[A,P,nS] = size(actions.requestedAcceleration);
assert(P == bank.meta.probeCount && A == numel(bank.meta.actionLimits), ...
    'landing2d:ProbeActions','Probe actions do not match the bank.');
applicable = ~grid.override & grid.anySafe(k,:);
exclusion = repmat({''},1,P);
exclusion(grid.override) = {'supervisor_override'};
exclusion(~grid.override & ~grid.anySafe(k,:)) = {'no_safe_action'};
contextId = cell(1,P);
probes = cell(1,P);
for p = 1:P
    probe = landing2d.consistency.probeRecord(bank,p);
    probe.admissible = landing2d.consistency.probeAdmissible(grid,p);
    probes{p} = probe;
    contextId{p} = landing2d.metrics.validityContext(probe.context, ...
        probe.drone(2)-probe.pad(2),c);
end
requested = actions.requestedAcceleration;
cells = cell(1,P);
parallel = isfield(options,'parallel') && options.parallel && ~isempty(gcp('nocreate'));
if parallel
    parfor p = 1:P
        cells{p} = judgeProbe(probes{p},reshape(requested(:,p,:),A,nS),applicable(p),config);
    end
else
    for p = 1:P
        cells{p} = judgeProbe(probes{p},reshape(requested(:,p,:),A,nS),applicable(p),config);
    end
end
valid = false(P,nS); contact = NaN(P,nS); braking = NaN(P,nS); fov = NaN(P,nS);
tracking = NaN(P,nS); approach = NaN(P,nS);
reasons = repmat({''},P,nS);
for p = 1:P
    r = cells{p};
    valid(p,:) = r.valid; contact(p,:) = r.contact; braking(p,:) = r.braking;
    fov(p,:) = r.fov; tracking(p,:) = r.tracking; approach(p,:) = r.approach;
    reasons(p,:) = r.reasons;
end
result = struct('schemaVersion','probe_validity_v1','run',actions.run, ...
    'scales',bank.meta.scales,'horizon',frozen.horizon,'kappa',frozen.kappa, ...
    'frozenHash',frozen.hash, ...
    'valid',valid,'applicable',applicable,'contextId',{contextId}, ...
    'exclusionReason',{exclusion}, ...
    'margins',struct('contact',contact,'braking',braking,'fov',fov, ...
        'tracking',tracking,'approach',approach), ...
    'reasons',{reasons});
end

function r = judgeProbe(probe,requested,applicable,config)
nS = size(requested,2);
r = struct('valid',false(1,nS),'contact',NaN(1,nS),'braking',NaN(1,nS), ...
    'fov',NaN(1,nS),'tracking',NaN(1,nS),'approach',NaN(1,nS), ...
    'reasons',{repmat({''},1,nS)});
if ~applicable, return; end
for s = 1:nS
    if s > 1 && isequal(requested(:,s),requested(:,s-1))
        r.valid(s) = r.valid(s-1); r.contact(s) = r.contact(s-1);
        r.braking(s) = r.braking(s-1); r.fov(s) = r.fov(s-1); r.reasons(s) = r.reasons(s-1);
        r.tracking(s) = r.tracking(s-1); r.approach(s) = r.approach(s-1);
        continue;
    end
    out = landing2d.metrics.behaviorValidity(probe,requested(:,s),config);
    r.valid(s) = out.valid;
    r.contact(s) = out.constraint_margins.contact;
    r.braking(s) = out.constraint_margins.braking;
    r.fov(s) = out.constraint_margins.fov;
    r.tracking(s) = out.constraint_margins.tracking;
    r.approach(s) = out.constraint_margins.approach;
    r.reasons{s} = strjoin(out.reason_codes,';');
end
end
