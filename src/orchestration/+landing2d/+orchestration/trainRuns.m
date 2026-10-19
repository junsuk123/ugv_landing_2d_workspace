function runs = trainRuns(cfg,options)
% TRAINRUNS  Train (or reuse) every method x training seed of the comparison.
%   runs = landing2d.orchestration.trainRuns(cfg,struct('trainSeeds',1:5))
% options.methods     registry ids (default all three)
% options.trainSeeds  training seeds (default registry.trainSeeds.default)
% options.retrain     true retrains even when a compatible checkpoint exists
%                     (default false: a checkpoint is reused only when its
%                     training signature matches, otherwise it is retrained)
% options.smoke       true: one bounded PPO iteration per run, nothing saved
%                     (integration check, not a performance result)
% options.concurrentRuns  K > 1 trains K runs at the same time on a pool of K
%                     workers, each run collecting its episodes serially
%                     (execution only: every episode and minibatch stream is
%                     seeded per run, rl.parallelEpisodes/parallelWorkers are
%                     outside the training signature; default 1)
% options.concurrentPool  'processes' (default) or 'threads'
% Seeds are the outer loop, so every method of seed 1 finishes before seed 2.
% Methods with the same seed share the training-episode sequence.
registry = landing2d.config.methodRegistry();
defaults = struct('methods',{{registry.methods.id}}, ...
    'trainSeeds',registry.trainSeeds.default,'retrain',false,'smoke',false, ...
    'concurrentRuns',1,'concurrentPool','processes');
options = withDefaults(options,defaults);
cfg.rl.retrain = logical(options.retrain);
if options.concurrentRuns > 1 && ~options.smoke
    runs = trainConcurrently(cfg,options);
    return;
end
runs = [];
for seed = options.trainSeeds(:)'
    arms = landing2d.config.comparisonArms(cfg,struct('methods',{options.methods}, ...
        'trainSeed',seed));
    for i = 1:numel(arms)
        arm = arms(i);
        fprintf('[train] %-18s seed %d\n',arm.id,seed);
        file = '';
        if options.smoke
            [agent,info] = landing2d.rl.trainAgent(arm.config,@landing2d.rl.ppoTrain);
        else
            [agent,info,file] = landing2d.rl.loadOrTrainAgent(arm.config,@landing2d.rl.ppoTrain);
        end
        runs = [runs,makeRun(arm,agent,info,file)]; %#ok<AGROW>
    end
end
end

function runs = trainConcurrently(cfg,options)
% One parfor iteration per run; inside a worker the episodes of an update
% are collected serially (rl.parallelEpisodes = false).
arms = [];
for seed = options.trainSeeds(:)'
    arms = [arms,landing2d.config.comparisonArms(cfg,struct('methods',{options.methods}, ...
        'trainSeed',seed))]; %#ok<AGROW>
end
n = numel(arms);
configs = cell(1,n);
for j = 1:n
    configs{j} = arms(j).config;
    configs{j}.rl.parallelEpisodes = false;
    fprintf('[train] %-18s seed %d (concurrent)\n',arms(j).id,arms(j).trainSeed);
end
openPool(min(options.concurrentRuns,n),options.concurrentPool);
agents = cell(1,n); infos = cell(1,n); files = cell(1,n);
parfor j = 1:n
    [agents{j},infos{j},files{j}] = landing2d.rl.loadOrTrainAgent(configs{j},@landing2d.rl.ppoTrain);
end
% Evaluation then runs on the usual episode pool (landing2d.rl.ensurePool),
% exactly as after serial training.
delete(gcp('nocreate'));
landing2d.rl.ensurePool(cfg.rl);
runs = [];
for j = 1:n
    runs = [runs,makeRun(arms(j),agents{j},infos{j},files{j})]; %#ok<AGROW>
end
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
