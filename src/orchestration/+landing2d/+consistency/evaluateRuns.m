function out = evaluateRuns(c,probes,options)
% EVALUATERUNS  Fixed-probe consistency of trained runs (C_valid, D_obs, D_seed).
%   out = landing2d.consistency.evaluateRuns(c,probes,struct('trainSeeds',1:5))
% PROBES from landing2d.consistency.prepareProbes (frozen judge from validation).
% For every registered method, training seed and graph seed whose checkpoint
% exists and matches its training signature (<outputDir>/checkpoints/...):
%   perRun     one row per run and noise scale (C_valid, D_obs, validity counts)
%   contexts   C_valid per context, run and scale
%   seeds      D_seed per method (per graph seed for the perturbed method) and scale
%   progress   C_valid/D_obs of the saved training snapshots against cumulative
%              environment steps (OPTIONS.progress, nominal scale)
%   missing    runs without a compatible checkpoint (not trained or stale)
% The test split is the default; no choice is made from its results here.
if nargin < 3, options = struct(); end
registry = landing2d.config.methodRegistry();
known = [registry.methods,registry.ablations]; % ablations only when requested
defaults = struct('split','test','methods',{{registry.methods.id}},'trainSeeds',1, ...
    'graphSeeds',1,'progress',true,'parallel',false);
names = fieldnames(options);
for i = 1:numel(names)
    assert(isfield(defaults,names{i}),'landing2d:EvaluateRunsOption','Unknown option %s.',names{i});
    defaults.(names{i}) = options.(names{i});
end
options = defaults;
switch options.split
    case 'test', bank = probes.test; grid = probes.testGrid;
    case 'validation', bank = probes.validation; grid = probes.validationGrid;
    otherwise, error('landing2d:ProbeSplit','Unknown split %s.',options.split);
end
frozen = probes.frozen;
nominal = find(bank.meta.scales == bank.meta.nominalScale,1);
perRun = table(); contexts = table(); progress = table();
missing = strings(0,1);
actionsByGroup = containers.Map();
for m = 1:numel(options.methods)
    index = find(strcmp({known.id},options.methods{m}),1);
    method = known(index);
    graphSeeds = NaN;
    if ~strcmp(method.graphPerturbation,'none'), graphSeeds = options.graphSeeds; end
    for g = graphSeeds(:)'
        group = sprintf('%s|%g',method.id,g);
        actionsByGroup(group) = {};
        for s = options.trainSeeds(:)'
            arm = landing2d.config.applyMethod(c,method.id,s,g);
            [agent,info,file,ok] = landing2d.consistency.loadRun(arm);
            if ~ok
                missing(end+1,1) = string(arm.rl.policyFile); %#ok<AGROW>
                continue;
            end
            run = landing2d.rl.runIdentity(agent,arm,file);
            actions = landing2d.rl.probeActions(agent,bank,arm,run);
            validity = landing2d.consistency.probeValidity(bank,actions,frozen,grid,c, ...
                struct('parallel',options.parallel));
            [summary,byContext] = landing2d.consistency.probeMetrics(bank,actions,validity,c);
            id = table(string(method.id),s,g,string(run.GraphHash),run.RelationalPathActive, ...
                'VariableNames',{'MethodId','TrainSeed','GraphSeed','GraphHash','RelationalPathActive'});
            perRun = [perRun;[repmat(id,height(summary),1),summary]]; %#ok<AGROW>
            contexts = [contexts;[repmat(id(:,1:3),height(byContext),1),byContext]]; %#ok<AGROW>
            list = actionsByGroup(group); list{end+1} = actions; actionsByGroup(group) = list;
            if options.progress && isfield(info,'snapshots') && ~isempty(info.snapshots)
                for k = 1:numel(info.snapshots)
                    snap = info.snapshots(k);
                    a = landing2d.rl.probeActions(snap.agent,bank,arm,run);
                    v = landing2d.consistency.probeValidity(bank,a,frozen,grid,c, ...
                        struct('parallel',options.parallel));
                    sm = landing2d.consistency.probeMetrics(bank,a,v,c);
                    progress = [progress;table(string(method.id),s,g,snap.iteration, ...
                        snap.environmentSteps,sm.C_valid(nominal),sm.D_obs_mean(nominal), ...
                        sm.ReferenceValidRaw(nominal),'VariableNames',{'MethodId','TrainSeed', ...
                        'GraphSeed','Iteration','EnvironmentSteps','C_valid','D_obs_mean', ...
                        'ReferenceValidRaw'})]; %#ok<AGROW>
                end
            end
        end
    end
end
seeds = table();
groups = keys(actionsByGroup);
for i = 1:numel(groups)
    parts = split(string(groups{i}),'|');
    d = landing2d.consistency.seedDivergence(actionsByGroup(groups{i}),bank);
    seeds = [seeds;table(repmat(parts(1),numel(d.scales),1), ...
        repmat(str2double(parts(2)),numel(d.scales),1),d.scales(:), ...
        repmat(d.seedCount,numel(d.scales),1),d.D_seed(:),d.jackknifeSE(:), ...
        'VariableNames',{'MethodId','GraphSeed','NoiseScale','SeedCount','D_seed', ...
        'D_seed_jackknifeSE'})]; %#ok<AGROW>
end
out = struct('split',options.split,'frozenHash',frozen.hash,'perRun',perRun, ...
    'contexts',contexts,'seeds',seeds,'progress',progress,'missing',missing);
end
