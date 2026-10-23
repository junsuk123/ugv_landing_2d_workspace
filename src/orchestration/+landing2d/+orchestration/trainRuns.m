function runs = trainRuns(cfg,options)
% TRAINRUNS  Train (or reuse) every method x training seed of the comparison.
%   runs = landing2d.orchestration.trainRuns(cfg,struct('trainSeeds',1:5))
% options.methods     registry ids (default all three)
% options.trainSeeds  training seeds (default registry.trainSeeds.default)
% options.retrain     true retrains even when a compatible checkpoint exists
%                     (default false: a checkpoint is reused only when its
%                     training signature matches, otherwise it is retrained)
% options.trainMethods  methods that may be trained ('all' = default; {} = none).
%                     Every other method is never trained: its most recent
%                     validated checkpoint is loaded (landing2d.rl.loadLatestCheckpoint;
%                     an error when none is usable). run.m sets this list.
%                     Ignored in smoke runs (nothing is loaded or saved there).
% options.smoke       true: one bounded PPO iteration per run, nothing saved
%                     (integration check, not a performance result)
% options.concurrentRuns  K > 1 trains K runs at the same time on a pool of K
%                     workers, each run collecting its episodes serially
%                     (execution only: every episode and minibatch stream is
%                     seeded per run, rl.parallelEpisodes/parallelWorkers are
%                     outside the training signature; default 1)
% options.concurrentPool  'processes' (default) or 'threads'
% options.liveTraining    true opens landing2d.viz.TrainingMonitor, redrawn after
%                     every PPO update of every trained run (display only: the
%                     hook c.trainingMonitor is outside the training signature
%                     and is not stored in the returned runs; default false)
% Seeds are the outer loop, so every method of seed 1 finishes before seed 2.
% Methods with the same seed share the training-episode sequence.
registry = landing2d.config.methodRegistry();
defaults = struct('methods',{{registry.methods.id}}, ...
    'trainSeeds',registry.trainSeeds.default,'retrain',false,'smoke',false, ...
    'concurrentRuns',1,'concurrentPool','processes','liveTraining',false);
% trainMethods: 'all' (default) or a list; an empty list trains nothing.
trainMethods = 'all';
if nargin >= 2 && isfield(options,'trainMethods')
    trainMethods = options.trainMethods; options = rmfield(options,'trainMethods');
end
options = withDefaults(options,defaults);
if (ischar(trainMethods) && strcmp(trainMethods,'all')) || options.smoke
    trainMethods = options.methods;
end
options.trainMethods = cellstr(trainMethods);
unknown = setdiff(options.trainMethods,{registry.methods.id});
assert(isempty(unknown),'landing2d:UnknownMethod','Unknown method(s) to train: %s', ...
    strjoin(unknown,', '));
cfg.rl.retrain = logical(options.retrain);
monitor = [];
if options.liveTraining && ~isempty(intersect(options.methods,options.trainMethods))
    monitor = landing2d.viz.TrainingMonitor();
end
if options.concurrentRuns > 1 && ~options.smoke
    runs = trainConcurrently(cfg,options,monitor);
    return;
end
runs = [];
for seed = options.trainSeeds(:)'
    arms = landing2d.config.comparisonArms(cfg,struct('methods',{options.methods}, ...
        'trainSeed',seed));
    for i = 1:numel(arms)
        arm = arms(i);
        if ~ismember(arm.id,options.trainMethods)
            runs = [runs,loadValidated(arm)]; %#ok<AGROW>
            continue;
        end
        fprintf('[train] %-18s seed %d\n',arm.id,seed);
        file = '';
        trainConfig = arm.config;
        if ~isempty(monitor), trainConfig.trainingMonitor = @(message)monitor.update(message); end
        if options.smoke
            [agent,info] = landing2d.rl.trainAgent(trainConfig,@landing2d.rl.ppoTrain);
        else
            [agent,info,file] = landing2d.rl.loadOrTrainAgent(trainConfig,@landing2d.rl.ppoTrain);
        end
        runs = [runs,makeRun(arm,agent,info,file)]; %#ok<AGROW>
    end
end
end

function runs = trainConcurrently(cfg,options,monitor)
% One parfor iteration per run; inside a worker the episodes of an update
% are collected serially (rl.parallelEpisodes = false). With a live monitor
% the workers send their progress through a DataQueue drawn on the client.
arms = [];
for seed = options.trainSeeds(:)'
    arms = [arms,landing2d.config.comparisonArms(cfg,struct('methods',{options.methods}, ...
        'trainSeed',seed))]; %#ok<AGROW>
end
% Methods that are not trained are loaded on the client, in arm order.
frozen = ~ismember({arms.id},options.trainMethods);
loaded = cell(1,numel(arms));
for j = find(frozen), loaded{j} = loadValidated(arms(j)); end
allArms = arms; arms = arms(~frozen);
n = numel(arms);
if n == 0
    runs = [loaded{:}];
    return;
end
openPool(min(options.concurrentRuns,n),options.concurrentPool);
queue = [];
if ~isempty(monitor)
    queue = parallel.pool.DataQueue;
    afterEach(queue,@(message)monitor.update(message));
end
configs = cell(1,n);
for j = 1:n
    configs{j} = arms(j).config;
    configs{j}.rl.parallelEpisodes = false;
    if ~isempty(queue), configs{j}.trainingMonitor = queue; end
    fprintf('[train] %-18s seed %d (concurrent)\n',arms(j).id,arms(j).trainSeed);
end
agents = cell(1,n); infos = cell(1,n); files = cell(1,n);
parfor j = 1:n
    [agents{j},infos{j},files{j}] = landing2d.rl.loadOrTrainAgent(configs{j},@landing2d.rl.ppoTrain);
end
% Evaluation then runs on the usual episode pool (landing2d.rl.ensurePool),
% exactly as after serial training.
delete(gcp('nocreate'));
landing2d.rl.ensurePool(cfg.rl);
trained = find(~frozen);
for j = 1:n
    loaded{trained(j)} = makeRun(arms(j),agents{j},infos{j},files{j});
end
assert(numel(loaded) == numel(allArms));
runs = [loaded{:}];
end

function run = loadValidated(arm)
% Not trained in this run (run.m): the most recent validated checkpoint.
[agent,info,file,arm.config,note] = landing2d.rl.loadLatestCheckpoint(arm.config);
fprintf('[load]  %-18s seed %d  %s\n',arm.id,arm.trainSeed,file);
if ~isempty(note)
    warning('landing2d:FrozenCheckpointVersion', ['%s seed %d uses an older ' ...
        'validated model: %s. It is evaluated with its own graph features.'], ...
        arm.id,arm.trainSeed,note);
end
run = makeRun(arm,agent,info,file);
end

function openPool(workers,kind)
pool = gcp('nocreate');
wantThreads = strcmpi(kind,'threads');
if ~isempty(pool)
    isThreads = isa(pool,'parallel.ThreadPool');
    if pool.NumWorkers == workers && isThreads == wantThreads, return; end
    delete(pool);
end
% A thread pool cannot exceed the NumWorkers of the user's Threads profile
% (default 8); it then opens with the profile maximum. The Processes cap is
% raised on the in-memory cluster object only (saveProfile is not called).
if wantThreads
    try
        parpool('Threads',workers);
    catch
        parpool('Threads');
    end
else
    cluster = parcluster('Processes');
    if cluster.NumWorkers < workers, cluster.NumWorkers = workers; end
    parpool(cluster,workers);
end
end

function run = makeRun(arm,agent,info,file)
history = [];
if isfield(info,'history'), history = info.history; end
run = struct('id',arm.id,'label',arm.label,'trainSeed',arm.trainSeed, ...
    'graphSeed',arm.graphSeed,'color',arm.color,'lineStyle',arm.lineStyle, ...
    'marker',arm.marker,'config',arm.config,'agent',agent,'history',history, ...
    'file',string(file),'identity',landing2d.rl.runIdentity(agent,arm.config,char(file)));
end

function options = withDefaults(options,defaults)
if nargin < 1 || isempty(options), options = struct(); end
unknown = setdiff(fieldnames(options),fieldnames(defaults));
assert(isempty(unknown),'landing2d:UnknownOption','Unknown option: %s',strjoin(unknown,', '));
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(options,names{i}) || isempty(options.(names{i}))
        options.(names{i}) = defaults.(names{i});
    end
end
options.methods = cellstr(options.methods);
end
