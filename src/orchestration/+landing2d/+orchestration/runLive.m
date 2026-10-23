function output = runLive(caseId,options)
% RUNLIVE  Live overlay of sensor-noise replicates of one controlled case, every method.
%   output = landing2d.orchestration.runLive('S4')
%   output = landing2d.orchestration.runLive('S4',struct('replicates',20,'trainSeeds',1:3))
% Every replicate flies the same physical case of landing2d.evaluation.factorialCases
% (scenario, UGV motion, initial state, injected marker dropout). Replicate r
% uses the fixed-case seed + r - 1 (landing2d.evaluation.replicateSeeds), which
% changes only the time-indexed sensor-noise table: marker-corner, fused
% localization and tracker noise (landing2d.sensing.exogenousNoise). The
% deterministic policies fly in lockstep, one decision of every episode per
% frame, with the functions and order of landing2d.rl.rolloutEpisodeV2
% (policy input -> policyAction -> tanh -> environment.step), so all windows
% grow at the same time (landing2d.viz.ReplicateLiveView):
%   one window per method   approach in the pad frame, aim error, height and
%                           requested a_x/a_z of every replicate
%   comparison window       across-replicate spread over time of the requested
%                           acceleration and of the aim error, per method
% options
%   trainSeeds  trained checkpoints per method (default 1; one color per seed)
%   replicates  sensor-noise replicates (default 10)
%   methods     registry ids (default all three)
%   speed       simulated seconds per wall-clock second (default Inf = as computed)
%   drawEvery   decisions per redraw (default 1)
%   visible     show the windows (default true)
%   metrics     true (default): afterwards recompute the episodes with
%               landing2d.evaluation.rolloutSet (study metrics) and require the
%               live trajectories to match them bit for bit (landing2d:LiveReplay)
%   outputDir   results folder holding checkpoints/ (default results)
% A diagnostic look at behavioral consistency, not a study result: nothing here
% selects a checkpoint, case or threshold (the study numbers come from run).
% The spread is read together with the aim error and outcomes of the same runs.
if nargin < 1 || isempty(caseId), caseId = 'S4'; end
if nargin < 2, options = struct(); end
registry = landing2d.config.methodRegistry();
defaults = struct('trainSeeds',1,'replicates',10,'methods',{{registry.methods.id}}, ...
    'speed',Inf,'drawEvery',1,'visible',true,'metrics',true,'outputDir','');
options = parseOptions(options,defaults);
cfg = landing2d.config.primaryConfig(landing2d.orchestration.projectRoot());
if ~isempty(options.outputDir), cfg.outputDir = char(options.outputDir); end
specs = landing2d.evaluation.factorialCases(cfg);
caseId = upper(char(caseId));
spec = specs(strcmp({specs.id},caseId));
assert(isscalar(spec),'landing2d:ScenarioId','caseId must be S1, S2, S3 or S4.');
try
    runs = landing2d.orchestration.loadRuns(cfg,struct('methods',{options.methods}, ...
        'trainSeeds',options.trainSeeds));
catch err
    error('landing2d:LiveCheckpoint',['%s\nrun_live flies trained checkpoints of the ' ...
        'current configuration; train them first with run.m (runSettings.trainSeeds = %s).'], ...
        err.message,mat2str(options.trainSeeds));
end
seeds = landing2d.evaluation.replicateSeeds(cfg,spec.seed,options.replicates);
fprintf(['\nrun_live | %s %s | methods %s | training seeds %s | %d sensor-noise ' ...
    'replicates (episode seeds %d-%d, same scenario and dropout events)\n'],spec.id, ...
    spec.name,strjoin(options.methods,', '),mat2str(options.trainSeeds),numel(seeds), ...
    seeds(1),seeds(end));

episodes = [];
for r = 1:numel(runs)
    for j = 1:numel(seeds)
        episodes = [episodes,startEpisode(runs(r),r,j,seeds(j),spec)]; %#ok<AGROW>
    end
end
view = landing2d.viz.ReplicateLiveView(spec,cfg,runs,episodes,options.visible);
wall = tic; frame = 0; stopped = false;
while any([episodes.active])
    for i = find([episodes.active])
        episodes(i) = advance(episodes(i),runs(episodes(i).runIndex));
    end
    frame = frame+1;
    if mod(frame,options.drawEvery) == 0 || ~any([episodes.active])
        view.update(episodes);
        if options.visible && ~view.isOpen()
            stopped = true;
            fprintf('All run_live windows were closed: stopped at %.1f s.\n', ...
                frame*cfg.experiment.policyDt);
            break;
        end
        if isfinite(options.speed)
            while toc(wall) < frame*cfg.experiment.policyDt/options.speed
                pause(0.005);
            end
        end
    end
end
view.finish(episodes);
fprintf('live run: %d episodes, %d decisions, %.1f s wall time\n',numel(episodes), ...
    frame,toc(wall));

[spread,trajectories] = summarizeLive(episodes,runs,spec,cfg);
episodeTable = table();
if options.metrics && ~stopped
    episodeTable = studyMetrics(episodes,runs,seeds,spec);
    spread = join(spread,outcomeSummary(episodeTable),'Keys',{'MethodId','TrainSeed'});
end
disp(spread);
output = struct('case',spec,'seeds',seeds,'summary',spread,'episodes',episodeTable, ...
    'trajectories',trajectories,'figures',view.Figures,'stopped',stopped);
end

% ------------------------------------------------------------ lockstep engine
function e = startEpisode(run,runIndex,replicate,seed,spec)
% Same reset options and policy stream as landing2d.rl.rolloutEpisodeV2.
c = run.config;
[env,observation] = landing2d.environment.reset(c,seed, ...
    struct('scenario',spec.scenario,'sensorEvents',spec.sensorEvents));
capacity = ceil(env.scenario.deadline/c.experiment.policyDt)+1;
rs = RandStream('threefry','Seed',c.experiment.scenario.baseSeed+ ...
    c.experiment.randomStreams.policyOffset+double(seed));
blank = nan(1,capacity);
e = struct('runIndex',runIndex,'methodId',run.id,'label',run.label, ...
    'trainSeed',run.trainSeed,'replicate',replicate,'seed',seed,'env',env, ...
    'observation',observation,'rs',rs,'capacity',capacity,'count',0,'active',true, ...
    'terminalReason','','time',[env.time,blank],'xDrone',[env.physicalState.x,blank], ...
    'zDrone',[env.physicalState.z,blank],'xPad',[env.pad.x,blank], ...
    'requestedAcceleration',nan(2,capacity));
end

function e = advance(e,run)
% One decision, exactly as one iteration of the rolloutEpisodeV2 loop.
c = run.config; agent = run.agent;
if strcmp(agent.encoderSpec.mode,'baseline')
    policyInput = e.observation;
else
    policyInput = landing2d.graphstate.environmentGraph(e.env,c,e.observation);
end
preTanhAction = landing2d.rl.policyAction(agent,policyInput,e.rs,true);
[e.env,e.observation,~,~,~,stepInfo] = landing2d.environment.step(e.env,tanh(preTanhAction));
k = e.count+1; e.count = k;
e.requestedAcceleration(:,k) = stepInfo.requestedAcceleration;
e.time(k+1) = e.env.time; e.xDrone(k+1) = e.env.physicalState.x;
e.zDrone(k+1) = e.env.physicalState.z; e.xPad(k+1) = e.env.pad.x;
if e.env.episodeStatus.terminated || k >= e.capacity
    e.active = false;
    e.terminalReason = e.env.episodeStatus.terminalReason;
    if ~e.env.episodeStatus.terminated, e.terminalReason = 'DECISION_LIMIT'; end
end
end

% ------------------------------------------------------------------ summaries
function [spread,trajectories] = summarizeLive(episodes,runs,spec,cfg)
% Across-replicate spread per run (landing2d.viz.ReplicateLiveView.spread):
% time means over every decision with >= 2 replicates still flying and over
% the case's evaluation window [T1, T1+T2).
rows = cell(numel(runs),1);
for r = 1:numel(runs)
    members = find([episodes.runIndex] == r);
    [actionSpread,aimSpread,time] = landing2d.viz.ReplicateLiveView.spread( ...
        episodes(members),cfg);
    inWindow = time >= spec.eventWindow(1) & time < spec.eventWindow(2);
    rows{r} = table(string(runs(r).id),runs(r).trainSeed,numel(members), ...
        meanOf(actionSpread),meanOf(actionSpread(inWindow)),meanOf(aimSpread), ...
        meanOf(aimSpread(inWindow)),'VariableNames',{'MethodId','TrainSeed','Replicates', ...
        'ActionSpread_mps2','WindowActionSpread_mps2','AimErrorSpread_m', ...
        'WindowAimErrorSpread_m'});
end
spread = vertcat(rows{:});
trajectories = rmfield(episodes,{'env','observation','rs','active','capacity'});
end

function value = meanOf(x)
value = mean(x(isfinite(x)));
if isempty(value), value = NaN; end
end

function episodes = studyMetrics(live,runs,seeds,spec)
% Study metrics of the same episodes (landing2d.evaluation.rolloutSet) and the
% check that the live lockstep loop reproduced rolloutEpisodeV2 bit for bit.
case1 = struct('scenario',spec.scenario,'sensorEvents',spec.sensorEvents, ...
    'eventWindow',spec.eventWindow,'sensorNoiseScale',[]);
rows = cell(1,numel(runs));
for r = 1:numel(runs)
    identity = struct('Case',string(spec.id),'Replicate',num2cell(1:numel(seeds)));
    [rows{r},kept] = landing2d.evaluation.rolloutSet(runs(r),runs(r).config,seeds, ...
        repmat(case1,1,numel(seeds)),identity,true(1,numel(seeds)));
    for j = 1:numel(seeds)
        e = live([live.runIndex] == r & [live.replicate] == j);
        n = e.count;
        same = isequal(e.xDrone(1:n+1),kept{j}.xDrone) && isequal(e.zDrone(1:n+1),kept{j}.zDrone) ...
            && isequal(e.requestedAcceleration(:,1:n),kept{j}.command);
        assert(same,'landing2d:LiveReplay', ...
            'Live episode %s seed %d replicate %d differs from rolloutEpisodeV2.', ...
            runs(r).id,runs(r).trainSeed,j);
    end
end
episodes = struct2table([rows{:}]);
fprintf('study metrics recomputed; live trajectories identical to rolloutEpisodeV2.\n');
end

function out = outcomeSummary(episodes)
groups = unique(episodes(:,{'MethodId','TrainSeed'}),'rows','stable');
n = height(groups);
Landed = zeros(n,1); Outcomes = strings(n,1); WindowAimErrorRMS_m = nan(n,1);
LandingTimeStd_s = nan(n,1);
for g = 1:n
    rows = episodes(episodes.MethodId == groups.MethodId(g) ...
        & episodes.TrainSeed == groups.TrainSeed(g),:);
    Landed(g) = sum(rows.Success);
    [classes,~,k] = unique(string(rows.FailureClass));
    Outcomes(g) = strjoin(compose('%s %d',classes,accumarray(k,1)),', ');
    WindowAimErrorRMS_m(g) = mean(rows.WindowAimErrorRMS_m,'omitnan');
    LandingTimeStd_s(g) = std(rows.LandingTime_s(isfinite(rows.LandingTime_s)));
end
out = [groups,table(Landed,Outcomes,WindowAimErrorRMS_m,LandingTimeStd_s)];
end

function options = parseOptions(options,defaults)
assert(isstruct(options) && isscalar(options),'landing2d:InvalidOptions', ...
    'options must be a scalar struct.');
unknown = setdiff(fieldnames(options),fieldnames(defaults));
assert(isempty(unknown),'landing2d:UnknownOption','Unknown run_live option: %s', ...
    strjoin(unknown,', '));
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(options,names{i}), options.(names{i}) = defaults.(names{i}); end
end
options.methods = cellstr(options.methods);
validateattributes(options.replicates,{'numeric'},{'scalar','integer','>=',2});
validateattributes(options.drawEvery,{'numeric'},{'scalar','integer','positive'});
validateattributes(options.speed,{'numeric'},{'scalar','positive'});
options.visible = logical(options.visible); options.metrics = logical(options.metrics);
end
