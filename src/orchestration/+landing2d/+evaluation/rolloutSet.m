function [rows,results] = rolloutSet(run,envConfig,seeds,cases,identity,keep)
% ROLLOUTSET  Deterministic closed-loop rollouts of one trained run and their metrics.
%   [rows,results] = landing2d.evaluation.rolloutSet(run,envConfig,seeds,cases,identity,keep)
% RUN       one entry of landing2d.orchestration.trainRuns / loadRuns
% ENVCONFIG the run's configuration, optionally with a modified experiment
%           (generalization conditions change only experiment.scenario and
%           experiment.sensor.perturbation; policy settings stay the run's own)
% SEEDS     episode seeds (1 x N)
% CASES     [] (sample scenario and events from ENVCONFIG) or a struct array
%           (1 x N) with fields scenario, sensorEvents, eventWindow,
%           sensorNoiseScale (empty fields = sampled / nominal)
% IDENTITY  struct array (1 x N) of row-leading fields (MethodId etc. added here)
% KEEP      logical (1 x N): return a compact copy of these rollouts for figures
% Seeds run in parfor when a parallel pool is already open (same result).
n = numel(seeds);
if nargin < 4, cases = []; end
if nargin < 6 || isempty(keep), keep = false(1,n); end
rows = cell(1,n); kept = cell(1,n);
agent = run.agent;
runId = run.identity;
base = struct('MethodId',string(run.id),'Method',string(run.label), ...
    'TrainSeed',run.trainSeed);
if ~isempty(gcp('nocreate'))
    parfor i = 1:n
        [rows{i},kept{i}] = one(agent,envConfig,seeds(i),pick(cases,i), ...
            merge(base,identity(i)),runId,keep(i));
    end
else
    for i = 1:n
        [rows{i},kept{i}] = one(agent,envConfig,seeds(i),pick(cases,i), ...
            merge(base,identity(i)),runId,keep(i));
    end
end
rows = [rows{:}];
results = kept(keep);
end

function [row,compact] = one(agent,c,seed,spec,identity,runId,keep)
options = struct('deterministic',true,'run',runId);
eventWindow = [];
if ~isempty(spec)
    if ~isempty(spec.scenario), options.scenario = spec.scenario; end
    if ~isempty(spec.sensorEvents), options.sensorEvents = spec.sensorEvents; end
    if ~isempty(spec.sensorNoiseScale), options.sensorNoiseScale = spec.sensorNoiseScale; end
    eventWindow = spec.eventWindow;
end
[result,traj] = landing2d.rl.rolloutEpisodeV2(agent,c,seed,options);
identity.EpisodeSeed = seed;
row = landing2d.evaluation.episodeMetrics(result,traj,c,identity,eventWindow);
row.Cell = cellLabel(row);
compact = [];
if keep
    events = result.resetInfo.evaluatorMetadata.sensorEvents;
    compact = struct('time',result.time,'xDrone',result.xDrone,'zDrone',result.zDrone, ...
        'xPad',result.xPad,'vxDrone',result.vxDrone,'vxPad',result.vxPad, ...
        'vzDrone',result.vzDrone,'theta',result.theta, ...
        'visible',result.visible,'terminalReason',result.terminalReason, ...
        'scenario',result.scenario,'sensorEvents',events, ...
        'command',traj.requestedAcceleration);   % requested acceleration [m/s^2] (results.mat name)
end
end

function label = cellLabel(row)
% Motion x observation cell of the training family.
motion = ["CV","CA"]; observation = ["clean","dropout"];
label = motion(row.MotionFactor+1)+"-"+observation(row.ObservationFactor+1);
end

function s = pick(cases,i)
if isempty(cases), s = []; else, s = cases(i); end
end

function s = merge(a,b)
names = fieldnames(b);
for k = 1:numel(names), a.(names{k}) = b.(names{k}); end
s = a;
end
