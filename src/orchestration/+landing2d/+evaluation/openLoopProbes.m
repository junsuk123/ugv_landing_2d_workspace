function out = openLoopProbes(runs,c,probeSet)
% OPENLOOPPROBES  Policy responses to controlled observation contrasts at identical states.
%   out = landing2d.evaluation.openLoopProbes(runs,c)
%   out = landing2d.evaluation.openLoopProbes(runs,c,probeSet)   % reuse probe inputs
% Open loop: every policy receives exactly the same observations, so policy
% differences are not confounded by the different trajectories of closed-loop
% flights. Probe states come from the policy-independent reference driver
% (landing2d.probe.recordReference) on test-split episodes and are rebuilt by
% the environment's own sensing chain (landing2d.probe.replaySensing).
%   velocity  at a state with a fresh marker update, the UGV velocity estimate
%             is shifted by +/- dv (relative position unchanged; ugv_vx and
%             relative_vx change consistently). SensitivityX = (a_x(+dv) -
%             a_x(-dv)) / (2 dv) [1/s]: a UGV moving faster relative to the drone
%             calls for forward acceleration, so the expected sign is positive.
%             The reference driver's response is reported as a scale reference.
%   update    the same physical trajectory with the marker frames of the last
%             staleAge seconds dropped: the estimator predicts instead of
%             updating. DeltaAx/DeltaAz = response(stale) - response(fresh);
%             EstimateShift_m / EstimateShiftV_mps = change of the horizontal
%             UGV position / velocity estimate error. A response with no
%             estimate change reacts to the update flag/age itself.
%             Graph arms also report AttentionShift (mean |delta alpha| over the
%             edges leaving VisionQuality, first R-GAT layer, actor): how much
%             the input-dependent attention re-weights the quality messages.
%             Descriptive only; alpha is not a causal importance.
% No probe result selects a checkpoint or feeds back into a trajectory.
if nargin < 3 || isempty(probeSet), probeSet = landing2d.evaluation.buildProbeSet(c); end
velocityRows = {}; updateRows = {};
limits = landing2d.environment.actionLimits(c);
[velocityRows{end+1},updateRows{end+1}] = referenceRows(probeSet,c,limits);
for r = 1:numel(runs)
    fprintf('  open-loop probes %-18s seed %d: %d + %d probes\n',runs(r).id, ...
        runs(r).trainSeed,numel(probeSet.velocity),numel(probeSet.update));
    [velocityRows{end+1},updateRows{end+1}] = policyRows(runs(r),probeSet,limits); %#ok<AGROW>
end
velocity = vertcat(velocityRows{:});
update = vertcat(updateRows{:});
velocityMetrics = {'SensitivityX','SensitivityZ','PositiveSensitivity'};
updateMetrics = {'AbsDeltaAx','AbsDeltaAz','DeltaAx','DeltaAz','EstimateShift_m', ...
    'EstimateShiftV_mps','AttentionShift'};
learned = @(T)T(T.MethodId~="reference_driver",:);
VR = landing2d.evaluation.runMeans(velocity,{},velocityMetrics);
UR = landing2d.evaluation.runMeans(update,{},updateMetrics);
out = struct('velocity',velocity,'update',update,'velocityRuns',VR,'updateRuns',UR, ...
    'velocitySummary',landing2d.evaluation.seedSummary(VR,{},velocityMetrics), ...
    'updateSummary',landing2d.evaluation.seedSummary(UR,{},updateMetrics), ...
    'velocityContrasts',landing2d.evaluation.methodContrasts(learned(VR),{},velocityMetrics), ...
    'updateContrasts',landing2d.evaluation.methodContrasts(learned(UR),{},updateMetrics), ...
    'velocityMetrics',{velocityMetrics},'updateMetrics',{updateMetrics}, ...
    'meta',probeSet.meta);
end

function [V,U] = policyRows(run,P,limits)
act = @(O)requested(run,O,P.context,limits);
V = velocityTable(P,act,string(run.id),string(run.label),run.trainSeed);
U = updateTable(P,act,string(run.id),string(run.label),run.trainSeed);
end

function [V,U] = referenceRows(P,c,limits)
act = @(O)deal(limits(:).*landing2d.probe.referenceDriver(O,P.context,c,[],0),[]);
V = velocityTable(P,act,"reference_driver","Reference driver",0);
U = updateTable(P,act,"reference_driver","Reference driver",0);
end

function T = velocityTable(P,act,id,label,seed)
n = numel(P.velocity); dv = P.meta.velocityDelta;
sx = zeros(n,1); sz = zeros(n,1);
for i = 1:n
    [plus,~] = act(P.velocity(i).plus); [minus,~] = act(P.velocity(i).minus);
    sx(i) = (plus(1)-minus(1))/(2*dv); sz(i) = (plus(2)-minus(2))/(2*dv);
end
T = table(repmat(id,n,1),repmat(label,n,1),repmat(seed,n,1), ...
    [P.velocity.episode]',[P.velocity.decision]',[P.velocity.height]',sx,sz,double(sx>0), ...
    'VariableNames',{'MethodId','Method','TrainSeed','Episode','Decision','Height', ...
    'SensitivityX','SensitivityZ','PositiveSensitivity'});
end

function T = updateTable(P,act,id,label,seed)
n = numel(P.update); d = zeros(n,2); shift = nan(n,1);
for i = 1:n
    [stale,alphaStale] = act(P.update(i).stale);
    [fresh,alphaFresh] = act(P.update(i).fresh);
    d(i,:) = (stale-fresh)';
    if ~isempty(alphaFresh)
        quality = alphaFresh.qualityEdges;
        shift(i) = mean(abs(alphaStale.alpha(quality)-alphaFresh.alpha(quality)));
    end
end
T = table(repmat(id,n,1),repmat(label,n,1),repmat(seed,n,1), ...
    [P.update.episode]',[P.update.decision]',[P.update.height]', ...
    d(:,1),d(:,2),abs(d(:,1)),abs(d(:,2)), ...
    [P.update.estimateShift]',[P.update.estimateShiftV]',shift, ...
    'VariableNames',{'MethodId','Method','TrainSeed','Episode','Decision','Height', ...
    'DeltaAx','DeltaAz','AbsDeltaAx','AbsDeltaAz','EstimateShift_m','EstimateShiftV_mps', ...
    'AttentionShift'});
end

function [a,attention] = requested(run,O,G,limits)
% Deterministic requested acceleration (tanh of the actor mean x limits) and,
% for graph arms, the first-layer actor attention of every edge.
attention = [];
spec = run.agent.encoderSpec;
if strcmp(spec.mode,'baseline')
    state = landing2d.observation.toVector(O,G);
else
    state = landing2d.graphstate.observationGraph(O,G,run.config);
    [~,cache] = landing2d.graphstate.encoderForward(run.agent.policy.encoder, ...
        spec,state,'policy');
    quality = find(strcmp(spec.schema.nodeNames,'VisionQuality'));
    attention = struct('alpha',cache.cache1.alpha(:,1), ...
        'qualityEdges',spec.T.src(:)==quality & spec.T.dst(:)~=quality);
end
[~,~,mu] = landing2d.rl.policyAction(run.agent,state,[],true);
a = limits(:).*tanh(mu(:));
end
