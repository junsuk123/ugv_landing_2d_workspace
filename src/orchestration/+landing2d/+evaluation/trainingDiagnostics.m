function out = trainingDiagnostics(runs,c)
% TRAININGDIAGNOSTICS  Does the PPO loss reach and train the R-GAT encoders? Which graph was used?
%   out = landing2d.evaluation.trainingDiagnostics(runs,c)
% Per run, from the checkpoint alone (also for runs trained before the PPO
% history recorded gradient norms):
%   gradient  the common PPO actor loss (landing2d.rl.policyLossGradient) and
%             critic loss (landing2d.rl.valueLossGradient) at the trained
%             policy on the first c.evaluation.training.gradientEpisodes
%             episodes of the run's own training-episode stream (stochastic
%             policy, advantages normalized as in PPO). Pre-clip L2 norms of
%             the actor/critic encoder and head gradients; nonzero encoder
%             norms show that PPO -> MLP -> graph embedding -> R-GAT carries
%             gradient.
%   change    ||theta_final - theta_init|| of every encoder and head, with
%             theta_init rebuilt by landing2d.rl.initialAgent (the exact PPO
%             starting point): nonzero means the encoder was updated.
%   training  window means of the encoder gradient norms recorded during PPO
%             (landing2d.rl.ppoTrain history; NaN for older checkpoints).
%   graph     the typed graph each graph run used: per run the number and
%             fraction of semantic edges whose relation type differs from
%             TOSM, the per-relation edge counts, and one row per edge.
% Diagnostics only: nothing here selects a checkpoint or enters a metric.
% Plain PPO has no encoder (encoder columns NaN).
n = c.evaluation.training.gradientEpisodes;
rows = cell(1,numel(runs)); parameters = cell(1,numel(runs));
relations = cell(1,numel(runs)); edges = cell(1,numel(runs));
for r = 1:numel(runs)
    run = runs(r);
    fprintf('  training diagnostics %-18s seed %d\n',run.id,run.trainSeed);
    [rows{r},parameters{r}] = runRow(run,n);
    [relations{r},edges{r}] = graphRows(run);
end
R = vertcat(rows{:});
metrics = {'ActorEncoderGradNorm','CriticEncoderGradNorm','ActorHeadGradNorm', ...
    'CriticHeadGradNorm','ActorEncoderChange','CriticEncoderChange', ...
    'ActorEncoderRelativeChange','CriticEncoderRelativeChange', ...
    'ActorHeadRelativeChange','CriticHeadRelativeChange', ...
    'TrainingActorEncoderGradNorm','TrainingCriticEncoderGradNorm'};
out = struct('runs',R,'summary',landing2d.evaluation.seedSummary(R,{},metrics), ...
    'parameters',vertcat(parameters{:}),'relations',vertcat(relations{:}), ...
    'edges',vertcat(edges{:}),'metrics',{metrics});
end

function [row,P] = runRow(run,n)
c = run.config; agent = run.agent; rl = c.rl;
initial = landing2d.rl.initialAgent(c);
% Gradient batch: the first N episodes of the run's training stream.
stream = RandStream('threefry','Seed',rl.seed+rl.episodeStreamSeedOffset);
seeds = randi(stream,double(c.experiment.manifest.trainEpisodeSeedRange),n,1);
policyInput = {}; preTanhAction = {}; logProbability = {}; advantage = {}; valueTarget = {};
for i = 1:n
    options = struct('deterministic',false,'collect',true, ...
        'rs',RandStream('threefry','Seed',seeds(i)));
    [~,traj] = landing2d.rl.rolloutEpisodeV2(agent,c,seeds(i),options);
    [episodeAdvantage,episodeValueTarget] = landing2d.rl.computeAdvantage(traj,rl);
    policyInput{end+1} = traj.state; preTanhAction{end+1} = traj.command; %#ok<AGROW>
    logProbability{end+1} = traj.logProbability; advantage{end+1} = episodeAdvantage; %#ok<AGROW>
    valueTarget{end+1} = episodeValueTarget; %#ok<AGROW>
end
policyInput = [policyInput{:}]; preTanhAction = [preTanhAction{:}];
logProbability = [logProbability{:}]; advantage = [advantage{:}]; valueTarget = [valueTarget{:}];
advantage = (advantage-mean(advantage))/(std(advantage)+1e-8);
[~,actorEncoder,actorStats] = landing2d.rl.policyLossGradient(agent,policyInput, ...
    preTanhAction,logProbability,advantage,rl);
[~,criticEncoder,criticStats] = landing2d.rl.valueLossGradient(agent,policyInput,valueTarget);
hasGraphEncoder = ~isempty(fieldnames(agent.policy.encoder));
[actorChange,actorRelative] = change(agent.policy.encoder,initial.policy.encoder,hasGraphEncoder);
[criticChange,criticRelative] = change(agent.value.encoder,initial.value.encoder,hasGraphEncoder);
[~,actorHeadRelative] = change(struct('mean',agent.policy.mean,'logStd',agent.policy.logStd), ...
    struct('mean',initial.policy.mean,'logStd',initial.policy.logStd),true);
[~,criticHeadRelative] = change(agent.value.net,initial.value.net,true);
row = table(string(run.id),string(run.label),run.trainSeed,size(policyInput,2), ...
    actorStats.encoderGradNorm,criticStats.encoderGradNorm, ...
    actorStats.headGradNorm,criticStats.headGradNorm, ...
    actorChange,criticChange,actorRelative,criticRelative, ...
    actorHeadRelative,criticHeadRelative, ...
    historyMean(run.history,'policyEncoderGradNorm'), ...
    historyMean(run.history,'valueEncoderGradNorm'), ...
    'VariableNames',{'MethodId','Method','TrainSeed','GradientDecisions', ...
    'ActorEncoderGradNorm','CriticEncoderGradNorm','ActorHeadGradNorm','CriticHeadGradNorm', ...
    'ActorEncoderChange','CriticEncoderChange','ActorEncoderRelativeChange', ...
    'CriticEncoderRelativeChange','ActorHeadRelativeChange','CriticHeadRelativeChange', ...
    'TrainingActorEncoderGradNorm','TrainingCriticEncoderGradNorm'});
P = table();
if hasGraphEncoder
    P = [parameterRows(run,'actor',agent.policy.encoder,initial.policy.encoder,actorEncoder); ...
        parameterRows(run,'critic',agent.value.encoder,initial.value.encoder,criticEncoder)];
end
end

function [delta,relative] = change(final,initial,present)
delta = NaN; relative = NaN;
if ~present, return; end
assert(isequal(structSizes(final),structSizes(initial)),'landing2d:InitialAgent', ...
    'The rebuilt initialization does not match the trained parameter shapes.');
delta = landing2d.util.gradientNorm(subtract(final,initial));
relative = delta/max(landing2d.util.gradientNorm(initial),eps);
end

function P = parameterRows(run,part,final,initial,grads)
names = fieldnames(final);
n = numel(names);
initialNorm = zeros(n,1); delta = zeros(n,1); gradient = nan(n,1);
for k = 1:n
    initialNorm(k) = norm(initial.(names{k})(:));
    delta(k) = norm(final.(names{k})(:)-initial.(names{k})(:));
    if isfield(grads,names{k}), gradient(k) = norm(grads.(names{k})(:)); end
end
P = table(repmat(string(run.id),n,1),repmat(string(run.label),n,1), ...
    repmat(run.trainSeed,n,1),repmat(string(part),n,1),string(names), ...
    initialNorm,delta,delta./max(initialNorm,eps),gradient, ...
    'VariableNames',{'MethodId','Method','TrainSeed','Encoder','Parameter', ...
    'InitialNorm','Change','RelativeChange','GradNorm'});
end

function [R,E] = graphRows(run)
R = table(); E = table();
spec = run.agent.encoderSpec;
if ~isfield(spec,'graph') || isempty(spec.graph), return; end
schema = spec.schema; g = spec.graph;
selfId = find(strcmp(schema.relationNames,'self'));
semantic = find(g.canonicalRel~=selfId);
canonical = g.canonicalRel(semantic); used = g.rel(semantic);
semanticNames = schema.relationNames(setdiff(1:numel(schema.relationNames),selfId));
counts = @(rel)strjoin(arrayfun(@(k)sprintf('%s=%d',schema.relationNames{k}, ...
    sum(rel==k)),setdiff(1:numel(schema.relationNames),selfId),'UniformOutput',false),'; ');
changed = used~=canonical;
R = table(string(run.id),string(run.label),run.trainSeed,run.graphSeed, ...
    string(g.perturbation),numel(semantic),sum(changed),mean(changed), ...
    string(counts(canonical)),string(counts(used)),string(g.hash), ...
    'VariableNames',{'MethodId','Method','TrainSeed','GraphSeed','Perturbation', ...
    'SemanticEdges','ChangedEdges','ChangedFraction','CanonicalCounts','RunCounts','GraphHash'});
assert(isequal(sort(canonical),sort(used)) && numel(semanticNames)>0, ...
    'landing2d:RelationShuffle','A relation shuffle must keep the per-relation edge counts.');
m = numel(semantic);
E = table(repmat(string(run.id),m,1),repmat(run.trainSeed,m,1),repmat(run.graphSeed,m,1), ...
    (1:m)',string(schema.nodeNames(g.src(semantic)))',string(schema.nodeNames(g.dst(semantic)))', ...
    string(schema.relationNames(canonical))',string(schema.relationNames(used))',double(changed(:)), ...
    'VariableNames',{'MethodId','TrainSeed','GraphSeed','Edge','Source','Target', ...
    'CanonicalRelation','RunRelation','Changed'});
end

function value = historyMean(history,name)
value = NaN;
if isempty(history) || ~isfield(history,name), return; end
x = double([history.(name)]); x = x(isfinite(x));
if ~isempty(x), value = mean(x); end
end

function d = subtract(a,b)
% Elementwise a - b of nested struct/cell parameters (MLP weights are cells).
if isnumeric(a)
    d = a-b;
elseif iscell(a)
    d = cellfun(@subtract,a,b,'UniformOutput',false);
else
    d = a;
    names = fieldnames(a);
    for k = 1:numel(names), d.(names{k}) = subtract(a.(names{k}),b.(names{k})); end
end
end

function s = structSizes(a)
% Flat list of the parameter shapes of a nested struct/cell.
if isnumeric(a)
    s = {size(a)};
elseif iscell(a)
    s = cellfun(@structSizes,a(:),'UniformOutput',false); s = vertcat(s{:});
else
    s = cellfun(@(k)structSizes(a.(k)),fieldnames(a),'UniformOutput',false); s = vertcat(s{:});
end
end
