function report = selfTest(d)
% SELFTEST relational_residual_v7 (C2) pre-registration checks (TEST ONLY; no performance evidence).
%   1 the configuration differs from v5 only in the three registered widths and
%     the output folder; algorithm versions v5/v6/v7 are distinct; mixed width
%     bundles (C2 with phi, partial widths, explicit v5 width field) are rejected
%   2 capacityEncoderInit with widths 74/8/36 reproduces every v5 residual
%     encoder and spec exactly (same generation rule and draw order)
%   3 initial agents (four methods x development seeds): PPO equals v5, the
%     parameter counts are 2095/2098/2093/2093 (node width 12), the residual arms
%     start at their common base mean (R = 0) and TOSM/Shuffled have equal encoders
%   4 graph (TOSM, Shuffled) and MLP corrections at nonzero correction states:
%     every parameter and input derivative against central differences, batch = columns
%   5 actual PPO loss: every graph-encoder parameter against central differences
%   6 Shuffled: equal semantic matrices give equal outputs but different
%     relation gradients (sharing, not names)
%   7 four-method 1-update smoke: finite; after the first minibatch the internal
%     correction parameters move (learning reaches the branch through R)
%   8 save / restore of a smoke checkpoint and a bit-identical deterministic replay
if nargin<1, d = landing2d.residual_capacity.config(); end
c = d.c; v5 = d.v5; report = struct('testOnly',true);
x5 = c; x5.graphState = rmfield(x5.graphState,'correctionHiddenSize'); x5.outputDir = v5.outputDir;
x5.graphState.basePolicyHiddenSizes = 74; x5.graphState.hiddenDim = 8;
assert(isequal(x5,v5),'Only the three widths and the output folder may differ from v5.');
c1 = landing2d.residual_soft.config(d.root);
assert(strcmp(landing2d.rl.algorithmVersion(c),'relational-residual-v7.0') ...
    && strcmp(landing2d.rl.algorithmVersion(v5),'relational-residual-v5.0') ...
    && strcmp(landing2d.rl.algorithmVersion(c1.c),'relational-residual-v6.0'));
bad = {setfield(c.graphState,'correctionActivation','soft_linear_v1'), ... %#ok<SFLD>
    setfield(c.graphState,'hiddenDim',8),setfield(c.graphState,'basePolicyHiddenSizes',74), ... %#ok<SFLD>
    setfield(c.graphState,'correctionHiddenSize',36),setfield(v5.graphState,'correctionHiddenSize',36), ... %#ok<SFLD>
    setfield(v5.graphState,'hiddenDim',12)}; %#ok<SFLD>
for k = 1:numel(bad)
    rejected = false;
    try
        landing2d.residual_context.validateGraphConfig(bad{k});
    catch err
        rejected = ismember(err.identifier,{'landing2d:ResidualV7Widths','landing2d:ResidualV5Config'});
    end
    assert(rejected,'Mixed width bundle %d must be rejected.',k);
end
report.onlyWidthsDiffer = true; report.mixedBundlesRejected = numel(bad);

reproduced = 0;
for seed = d.developmentSeeds
    old = landing2d.config.comparisonArms(v5,struct('methods',{d.methods(2:4)},'trainSeed',seed));
    for k = 1:3
        prior = landing2d.rl.initialAgent(old(k).config);
        gs = old(k).config.graphState; gs.correctionHiddenSize = 36;
        rs = RandStream('threefry','Seed',old(k).config.rl.seed+101);
        policyRs = RandStream('threefry','Seed',old(k).config.rl.seed+31001);
        [p,spec] = landing2d.residual_context.capacityEncoderInit(gs,rs,policyRs);
        assert(isequaln(p,prior.policy.encoder) && isequaln(spec,prior.encoderSpec), ...
            'Widths 74/8/36 must reproduce the v5 encoder (%s seed %d).',old(k).id,seed);
        reproduced = reproduced+1;
    end
end
report.v5EncodersReproduced = reproduced;

counts = zeros(4,numel(d.developmentSeeds));
for s = 1:numel(d.developmentSeeds)
    seed = d.developmentSeeds(s);
    arms = landing2d.config.comparisonArms(c,struct('methods',{d.methods},'trainSeed',seed));
    old = landing2d.config.comparisonArms(v5,struct('methods',{d.methods},'trainSeed',seed));
    rs = RandStream('threefry','Seed',97000+seed); x = .6*tanh(randn(rs,10,6));
    residualMean = []; graphEncoder = [];
    for k = 1:4
        agent = landing2d.rl.initialAgent(arms(k).config);
        assert(~landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(old(k).config),arms(k).config));
        [~,~,mu] = landing2d.rl.policyAction(agent,x,[],true);
        profile = landing2d.rl.profileAgent(agent,arms(k).config,2001,1); counts(k,s) = profile.parameterCount;
        if k==1
            prior = landing2d.rl.initialAgent(old(k).config);
            assert(isequaln(agent.policy,prior.policy) && isequaln(agent.value,prior.value),'PPO must equal v5.');
        else
            assert(agent.encoderSpec.hiddenDim==12 && size(agent.policy.encoder.B1,1)==42);
            [~,cache] = landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,x,'policy');
            assert(isequal(mu,cache.baseMean),'Initial residual mean must equal its base (R = 0).');
            if isempty(residualMean), residualMean = mu; else, assert(isequal(residualMean,mu)); end
        end
        if k>=3
            if isempty(graphEncoder), graphEncoder = agent.policy.encoder;
            else, assert(isequaln(graphEncoder,agent.policy.encoder)); end
        end
    end
end
assert(all(counts==d.parameterCounts,'all'),'Parameter counts differ from 2095/2098/2093/2093.');
report.parameterCounts = counts(:,1); report.initialAgentsChecked = numel(counts);

rs = RandStream('threefry','Seed',97701); x = .6*tanh(randn(rs,10,5)); dMu = randn(rs,2,5);
errors = zeros(3,2); names = {'onto_rgat_ppo','shuffled_rgat_ppo','residual_mlp_ppo'};
for m = 1:3
    cfg = landing2d.config.applyMethod(c,names{m},461); agent = landing2d.rl.initialAgent(cfg);
    p = perturb(agent.policy.encoder,rs); spec = agent.encoderSpec;
    assert(~isfield(spec,'correctionActivation'));
    [errors(m,1),errors(m,2)] = finiteDifference(p,spec,x,dMu);
    batch = landing2d.graphstate.encoderForward(p,spec,x);
    for j = 1:size(x,2)
        assert(max(abs(landing2d.graphstate.encoderForward(p,spec,x(:,j))-batch(:,j)))<=1e-12,'Batch must equal columns.');
    end
end
assert(all(errors(:)<2e-7),'Encoder derivatives differ from central differences.');
report.encoderDerivativeErrors = array2table(errors,'RowNames',names,'VariableNames',{'Parameters','Inputs'});

cfg = landing2d.config.applyMethod(c,'onto_rgat_ppo',461); agent = landing2d.rl.initialAgent(cfg);
p = perturb(agent.policy.encoder,rs); agent.policy.encoder = p;
[mu,~] = landing2d.graphstate.encoderForward(p,agent.encoderSpec,x);
noise = .25*randn(rs,2,5); action = mu+exp(agent.policy.logStd).*noise;
oldLog = sum(-.5*noise.^2-agent.policy.logStd-.5*log(2*pi),1); advantage = [-1 .3 1 -.3 .5];
[~,actualGrad] = landing2d.rl.policyLossGradient(agent,x,action,oldLog,advantage,cfg.rl);
ppoError = 0; step = 1e-6;
for field = fieldnames(p)'
    key = field{1};
    for j = 1:numel(p.(key))
        ap = agent; am = agent; ap.policy.encoder.(key)(j) = p.(key)(j)+step; am.policy.encoder.(key)(j) = p.(key)(j)-step;
        [~,~,sp] = landing2d.rl.policyLossGradient(ap,x,action,oldLog,advantage,cfg.rl);
        [~,~,sm] = landing2d.rl.policyLossGradient(am,x,action,oldLog,advantage,cfg.rl);
        ppoError = max(ppoError,abs((sp.loss-sm.loss)/(2*step)-actualGrad.(key)(j)));
    end
end
assert(ppoError<2e-7,'PPO loss gradient differs from central differences.');
report.ppoDerivativeError = ppoError;

shuffled = landing2d.rl.initialAgent(landing2d.config.applyMethod(c,'shuffled_rgat_ppo',461));
neutral = landing2d.rl.initialAgent(cfg).policy.encoder; neutral.R = p.R;   % equal semantic matrices (v5 test)
[a1,c1] = landing2d.graphstate.encoderForward(neutral,agent.encoderSpec,x);
[a2,c2] = landing2d.graphstate.encoderForward(neutral,shuffled.encoderSpec,x);
assert(isequal(a1,a2));
g1 = landing2d.graphstate.encoderBackward(neutral,agent.encoderSpec,c1,dMu);
g2 = landing2d.graphstate.encoderBackward(neutral,shuffled.encoderSpec,c2,dMu);
assert(norm(g1.W(:)-g2.W(:))>1e-8,'Shuffled must change relation sharing.');
report.shuffleChangesSharing = true;

smokeConfig = landing2d.orchestration.smokeConfig(c);
smokeConfig.rl.miniBatch = 16;   % several minibatches in the single update
smokeConfig.outputDir = fullfile(tempdir,'relational_residual_v7_selftest');
if isfolder(smokeConfig.outputDir), rmdir(smokeConfig.outputDir,'s'); end
runs = landing2d.orchestration.trainRuns(smokeConfig,struct('trainSeeds',461,'methods',{d.methods}, ...
    'smoke',true,'concurrentRuns',1,'liveTraining',false));
moved = false(1,3);
for k = 2:4
    initial = landing2d.rl.initialAgent(runs(k).config).policy.encoder; final = runs(k).agent.policy.encoder;
    assert(all(arrayfun(@(h)isfinite(h.score),runs(k).history)));
    if isfield(final,'P'), moved(k-1) = ~isequal(initial.P,final.P) && ~isequal(initial.W,final.W);
    else, moved(k-1) = ~isequal(initial.F,final.F); end
end
assert(all(moved),'Internal correction parameters must move after the first minibatch.');
report.internalLearningActivated = moved;

arm = landing2d.config.comparisonArms(smokeConfig,struct('methods',{{'onto_rgat_ppo'}},'trainSeed',461));
[a1,~,file] = landing2d.rl.loadOrTrainAgent(arm.config,@landing2d.rl.ppoTrain);
[a2,~,file2] = landing2d.rl.loadOrTrainAgent(arm.config,@landing2d.rl.ppoTrain);
assert(strcmp(file,file2) && isequaln(a1,a2),'Saved checkpoint must restore exactly.');
[r1,t1] = landing2d.rl.rolloutEpisodeV2(a2,arm.config,9001,struct('deterministic',true));
[r2,t2] = landing2d.rl.rolloutEpisodeV2(a2,arm.config,9001,struct('deterministic',true));
assert(isequaln(r1,r2) && isequaln(t1,t2),'Deterministic replay must be bit-identical.');
rmdir(smokeConfig.outputDir,'s');
report.saveRestoreReplay = true; report.passed = true;
disp(report);
end

function p = perturb(p,rs)
% Nonzero correction head and unequal relations so every parameter matters.
p.R = .3*randn(rs,size(p.R)); p.br = .2*randn(rs,size(p.br)); p.beta = .3;
if isfield(p,'W')
    h = size(p.W,1);
    p.W(:,:,1) = p.W(:,:,1)+.1*randn(rs,h,h); p.a = p.a+.1*randn(rs,size(p.a));
    p.bp = .2*randn(rs,size(p.bp)); p.b = .2*randn(rs,size(p.b));
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
