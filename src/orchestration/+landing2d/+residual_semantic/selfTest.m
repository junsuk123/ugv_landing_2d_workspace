function report = selfTest(d)
% SELFTEST relational_residual_v8 (C3) pre-registration checks (TEST ONLY; no performance evidence).
%   1 the configuration differs from v5 only in the six registered C3 fields and
%     the output folder; algorithm versions v5/v6/v7/v8 are distinct; mixed
%     bundles are rejected
%   2 initial agents (four methods x development seeds): PPO equals v5, the
%     parameter counts are 2095/2085/2087/2087, beta = 0, the residual arms start
%     at their common base mean (R = 0), TOSM and Shuffled draw identical
%     parameters, the TOSM placement is the ontology one (gates Q->R, Q->T) and
%     every Shuffled placement moves operators (same counts: 2 gates, 4 additive
%     semantic edges, 4 self edges)
%   3 with identical nonzero parameters TOSM and Shuffled compute different
%     corrections (the placement changes the computation)
%   4 graph (TOSM, Shuffled) and MLP corrections at nonzero correction states:
%     every parameter and input derivative against central differences, batch = columns
%   5 actual PPO loss: every graph-encoder parameter of TOSM and Shuffled against
%     central differences
%   6 four-method 1-update smoke: finite; after the first minibatch the internal
%     correction parameters move (learning reaches the branch through R)
%   7 save / restore of a smoke checkpoint and a bit-identical deterministic replay
if nargin<1, d = landing2d.residual_semantic.config(); end
c = d.c; v5 = d.v5; report = struct('testOnly',true);
fields = {'correctionOperators','correctionHiddenSize','betaInit'};
x5 = c; x5.graphState = rmfield(x5.graphState,fields); x5.outputDir = v5.outputDir;
x5.graphState.readout = 'all_nodes'; x5.graphState.basePolicyHiddenSizes = 74;
assert(isequal(x5,v5),'Only the six C3 fields and the output folder may differ from v5.');
assert(strcmp(landing2d.rl.algorithmVersion(c),'relational-residual-v8.0') ...
    && strcmp(landing2d.rl.algorithmVersion(v5),'relational-residual-v5.0') ...
    && strcmp(landing2d.rl.algorithmVersion(landing2d.residual_soft.config(d.root).c),'relational-residual-v6.0') ...
    && strcmp(landing2d.rl.algorithmVersion(landing2d.residual_capacity.config(d.root).c),'relational-residual-v7.0'));
gs = c.graphState;
bad = {setfield(gs,'betaInit',-2),rmfield(gs,'betaInit'),setfield(gs,'readout','all_nodes'), ... %#ok<SFLD>
    setfield(gs,'basePolicyHiddenSizes',74),setfield(gs,'correctionHiddenSize',36), ... %#ok<SFLD>
    setfield(gs,'correctionActivation','soft_linear_v1'),setfield(gs,'correctionOperators','message'), ... %#ok<SFLD>
    setfield(v5.graphState,'readout','goal_node'),setfield(v5.graphState,'betaInit',0), ... %#ok<SFLD>
    setfield(landing2d.residual_capacity.config(d.root).c.graphState,'correctionOperators','semantic_v1')}; %#ok<SFLD>
for k = 1:numel(bad)
    rejected = false;
    try
        landing2d.residual_context.validateGraphConfig(bad{k});
    catch err
        rejected = ismember(err.identifier,{'landing2d:ResidualV8Bundle','landing2d:ResidualV7Widths','landing2d:ResidualV5Config'});
    end
    assert(rejected,'Mixed bundle %d must be rejected.',k);
end
report.onlyRegisteredFieldsDiffer = true; report.mixedBundlesRejected = numel(bad);

counts = zeros(4,numel(d.developmentSeeds)); placements = strings(numel(d.developmentSeeds),1);
for s = 1:numel(d.developmentSeeds)
    seed = d.developmentSeeds(s);
    arms = landing2d.config.comparisonArms(c,struct('methods',{d.methods},'trainSeed',seed));
    old = landing2d.config.comparisonArms(v5,struct('methods',{d.methods},'trainSeed',seed));
    rs = RandStream('threefry','Seed',97000+seed); x = .6*tanh(randn(rs,10,6));
    residualMean = []; graph = {};
    for k = 1:4
        agent = landing2d.rl.initialAgent(arms(k).config);
        assert(~landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(old(k).config),arms(k).config));
        [~,~,mu] = landing2d.rl.policyAction(agent,x,[],true);
        profile = landing2d.rl.profileAgent(agent,arms(k).config,2001,1); counts(k,s) = profile.parameterCount;
        if k==1
            prior = landing2d.rl.initialAgent(old(k).config);
            assert(isequaln(agent.policy,prior.policy) && isequaln(agent.value,prior.value),'PPO must equal v5.');
            continue;
        end
        assert(agent.policy.encoder.beta==0 && size(agent.policy.encoder.B1,1)==77 && all(agent.policy.encoder.R(:)==0));
        [~,cache] = landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,x,'policy');
        assert(isequal(mu,cache.baseMean),'Initial residual mean must equal its base (R = 0).');
        if isempty(residualMean), residualMean = mu; else, assert(isequal(residualMean,mu)); end
        if k>=3, graph{end+1} = agent; end %#ok<AGROW>
    end
    assert(isequaln(graph{1}.policy.encoder,graph{2}.policy.encoder),'TOSM and Shuffled must draw identical parameters.');
    t = graph{1}.encoderSpec; u = graph{2}.encoderSpec;
    tosmEdges = sortrows([t.qualifies.src;t.qualifies.dst]'); shuffledEdges = sortrows([u.qualifies.src;u.qualifies.dst]');
    assert(isequal(tosmEdges,[1 2;1 4]) && numel(u.qualifies.src)==2 && ~isequal(shuffledEdges,tosmEdges) ...
        && t.Tadd.nEdges==8 && u.Tadd.nEdges==8 && sum(u.Tadd.rel==2)==4,'Shuffled must move the operators.');
    placements(s) = sprintf('seed %d gates %s',seed,mat2str(shuffledEdges));
end
assert(all(counts==d.parameterCounts,'all'),'Parameter counts differ from 2095/2085/2087/2087.');
report.parameterCounts = counts(:,1); report.initialAgentsChecked = numel(counts); report.shuffledGates = placements;

rs = RandStream('threefry','Seed',97801); x = .6*tanh(randn(rs,10,5)); dMu = randn(rs,2,5);
tosm = landing2d.rl.initialAgent(landing2d.config.applyMethod(c,'onto_rgat_ppo',471));
shuffled = landing2d.rl.initialAgent(landing2d.config.applyMethod(c,'shuffled_rgat_ppo',471));
p = perturb(tosm.policy.encoder,rs);
y1 = landing2d.graphstate.encoderForward(p,tosm.encoderSpec,x); y2 = landing2d.graphstate.encoderForward(p,shuffled.encoderSpec,x);
assert(max(abs(y1-y2),[],'all')>1e-6,'The placement must change the computation.');
report.placementChangesComputation = max(abs(y1-y2),[],'all');

errors = zeros(3,2); names = {'onto_rgat_ppo','shuffled_rgat_ppo','residual_mlp_ppo'};
for m = 1:3
    cfg = landing2d.config.applyMethod(c,names{m},471); agent = landing2d.rl.initialAgent(cfg);
    q = perturb(agent.policy.encoder,rs); spec = agent.encoderSpec;
    [errors(m,1),errors(m,2)] = finiteDifference(q,spec,x,dMu);
    batch = landing2d.graphstate.encoderForward(q,spec,x);
    for j = 1:size(x,2)
        assert(max(abs(landing2d.graphstate.encoderForward(q,spec,x(:,j))-batch(:,j)))<=1e-12,'Batch must equal columns.');
    end
end
assert(all(errors(:)<2e-7),'Encoder derivatives differ from central differences.');
report.encoderDerivativeErrors = array2table(errors,'RowNames',names,'VariableNames',{'Parameters','Inputs'});

ppoErrors = zeros(1,2);
for m = 1:2
    cfg = landing2d.config.applyMethod(c,names{m},471); agent = landing2d.rl.initialAgent(cfg);
    q = perturb(agent.policy.encoder,rs); agent.policy.encoder = q;
    mu = landing2d.graphstate.encoderForward(q,agent.encoderSpec,x);
    noise = .25*randn(rs,2,5); action = mu+exp(agent.policy.logStd).*noise;
    oldLog = sum(-.5*noise.^2-agent.policy.logStd-.5*log(2*pi),1); advantage = [-1 .3 1 -.3 .5];
    [~,actualGrad] = landing2d.rl.policyLossGradient(agent,x,action,oldLog,advantage,cfg.rl);
    step = 1e-6;
    for field = fieldnames(q)'
        key = field{1};
        for j = 1:numel(q.(key))
            ap = agent; am = agent; ap.policy.encoder.(key)(j) = q.(key)(j)+step; am.policy.encoder.(key)(j) = q.(key)(j)-step;
            [~,~,sp] = landing2d.rl.policyLossGradient(ap,x,action,oldLog,advantage,cfg.rl);
            [~,~,sm] = landing2d.rl.policyLossGradient(am,x,action,oldLog,advantage,cfg.rl);
            ppoErrors(m) = max(ppoErrors(m),abs((sp.loss-sm.loss)/(2*step)-actualGrad.(key)(j)));
        end
    end
end
assert(all(ppoErrors<2e-7),'PPO loss gradient differs from central differences.');
report.ppoDerivativeErrors = ppoErrors;

smokeConfig = landing2d.orchestration.smokeConfig(c);
smokeConfig.rl.miniBatch = 16;   % several minibatches in the single update
smokeConfig.outputDir = fullfile(tempdir,'relational_residual_v8_selftest');
if isfolder(smokeConfig.outputDir), rmdir(smokeConfig.outputDir,'s'); end
runs = landing2d.orchestration.trainRuns(smokeConfig,struct('trainSeeds',471,'methods',{d.methods}, ...
    'smoke',true,'concurrentRuns',1,'liveTraining',false));
for k = 1:4, assert(all(arrayfun(@(h)isfinite(h.score),runs(k).history))); end
% Learning path, independent of the validation-selected smoke checkpoint (which
% may be the initial agent): at R = 0 the actual PPO gradient reaches only the
% base, R, br and beta; after one gradient step on R every internal correction
% parameter has a nonzero gradient.
moved = false(1,3); x = .6*tanh(randn(rs,10,32));
for k = 2:4
    agent = landing2d.rl.initialAgent(runs(k).config);
    mu = landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,x);
    noise = .25*randn(rs,2,32); action = mu+exp(agent.policy.logStd).*noise;
    oldLog = sum(-.5*noise.^2-agent.policy.logStd-.5*log(2*pi),1); advantage = randn(rs,1,32);
    [~,g0] = landing2d.rl.policyLossGradient(agent,x,action,oldLog,advantage,runs(k).config.rl);
    internal = setdiff(fieldnames(g0),{'B1','b1','B2','b2','R','br','beta'});
    assert(all(cellfun(@(f)all(g0.(f)(:)==0),internal)) && any(g0.R(:)~=0),'At R = 0 only R reaches the correction.');
    agent.policy.encoder.R = agent.policy.encoder.R-1e-2*sign(g0.R);
    [~,g1] = landing2d.rl.policyLossGradient(agent,x,action,oldLog,advantage,runs(k).config.rl);
    moved(k-1) = all(cellfun(@(f)any(g1.(f)(:)~=0),internal));
end
assert(all(moved),'Internal correction parameters must receive gradient after R moves.');
report.internalLearningActivated = moved;

arm = landing2d.config.comparisonArms(smokeConfig,struct('methods',{{'onto_rgat_ppo'}},'trainSeed',471));
[a1,~,file] = landing2d.rl.loadOrTrainAgent(arm.config,@landing2d.rl.ppoTrain);
[a2,~,file2] = landing2d.rl.loadOrTrainAgent(arm.config,@landing2d.rl.ppoTrain);
assert(strcmp(file,file2) && isequaln(a1,a2),'Saved checkpoint must restore exactly.');
[r1,t1] = landing2d.rl.rolloutEpisodeV2(a2,arm.config,9001,struct('deterministic',true));
[r2,t2] = landing2d.rl.rolloutEpisodeV2(a2,arm.config,9001,struct('deterministic',true));
assert(isequaln(r1,r2) && isequaln(t1,t2),'Deterministic replay must be bit-identical.');
if isfolder(smokeConfig.outputDir), rmdir(smokeConfig.outputDir,'s'); end
report.saveRestoreReplay = true; report.passed = true;
disp(report); disp(report.shuffledGates);
end

function p = perturb(p,rs)
% Nonzero correction head, gates and unequal relations so every parameter matters.
p.R = .3*randn(rs,size(p.R)); p.br = .2*randn(rs,size(p.br)); p.beta = .3;
if isfield(p,'W')
    p.W = p.W+.1*randn(rs,size(p.W)); p.a = p.a+.1*randn(rs,size(p.a));
    p.bp = .2*randn(rs,size(p.bp)); p.b = .2*randn(rs,size(p.b)); p.bq = .2*randn(rs,size(p.bq));
else
    p.bf = .2*randn(rs,size(p.bf));
end
end

function [parameterError,inputError] = finiteDifference(p,spec,x,dMu)
[~,cache] = landing2d.graphstate.encoderForward(p,spec,x);
[grad,dx] = landing2d.graphstate.encoderBackward(p,spec,cache,dMu);
step = 1e-6; parameterError = 0; inputError = 0;
for field = fieldnames(p)'
    key = field{1};
    for j = 1:numel(p.(key))
        a = p; b = p; a.(key)(j) = a.(key)(j)+step; b.(key)(j) = b.(key)(j)-step;
        yp = landing2d.graphstate.encoderForward(a,spec,x); ym = landing2d.graphstate.encoderForward(b,spec,x);
        parameterError = max(parameterError,abs(sum((yp-ym).*dMu,'all')/(2*step)-grad.(key)(j)));
    end
end
for j = 1:numel(x)
    a = x; b = x; a(j) = a(j)+step; b(j) = b(j)-step;
    yp = landing2d.graphstate.encoderForward(p,spec,a); ym = landing2d.graphstate.encoderForward(p,spec,b);
    inputError = max(inputError,abs(sum((yp-ym).*dMu,'all')/(2*step)-dx(j)));
end
end
