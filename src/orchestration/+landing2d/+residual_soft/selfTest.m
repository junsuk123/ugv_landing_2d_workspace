function report = selfTest(d)
% SELFTEST relational_residual_v6 (C1) pre-registration checks (TEST ONLY; no performance evidence).
%   1 the configuration differs from v5 only in graphState.correctionActivation
%     and the output folder; algorithm version and training signature are new
%   2 initial agents (four methods x development seeds) equal the v5 ones, the
%     parameter counts are 2095/2098/2089/2089, the residual arms start at their
%     base mean and TOSM/Shuffled start with equal encoders
%   3 activation: phi and its slope against central differences
%   4 graph (TOSM, Shuffled) and MLP corrections: every parameter and input
%     derivative against central differences, batch = columns
%   5 actual PPO loss: every graph-encoder parameter against central differences
%   6 Shuffled: equal semantic matrices give equal outputs but different
%     relation gradients (sharing, not names)
%   7 four-method 1-update smoke: finite; after the first minibatch the internal
%     correction parameters move (learning reaches the branch through R)
%   8 save / restore of a smoke checkpoint and a bit-identical deterministic replay
if nargin<1, d = landing2d.residual_soft.config(); end
c = d.c; v5 = d.v5; report = struct('testOnly',true);
x5 = c; x5.graphState = rmfield(x5.graphState,'correctionActivation'); x5.outputDir = v5.outputDir;
assert(isequal(x5,v5),'Only the correction activation and the output folder may differ from v5.');
assert(strcmp(landing2d.rl.algorithmVersion(c),'relational-residual-v6.0') ...
    && strcmp(landing2d.rl.algorithmVersion(v5),'relational-residual-v5.0'));
report.onlyActivationDiffers = true;

counts = zeros(4,numel(d.developmentSeeds));
for s = 1:numel(d.developmentSeeds)
    seed = d.developmentSeeds(s);
    arms = landing2d.config.comparisonArms(c,struct('methods',{d.methods},'trainSeed',seed));
    old = landing2d.config.comparisonArms(v5,struct('methods',{d.methods},'trainSeed',seed));
    rs = RandStream('threefry','Seed',97000+seed); x = .6*tanh(randn(rs,10,6));
    residualMean = []; graphEncoder = [];
    for k = 1:4
        agent = landing2d.rl.initialAgent(arms(k).config); prior = landing2d.rl.initialAgent(old(k).config);
        assert(isequaln(agent.policy,prior.policy) && isequaln(agent.value,prior.value), ...
            'Initial parameters must equal v5 (%s seed %d).',arms(k).id,seed);
        assert(~landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(old(k).config),arms(k).config));
        [~,~,mu] = landing2d.rl.policyAction(agent,x,[],true); [~,~,mu0] = landing2d.rl.policyAction(prior,x,[],true);
        assert(isequal(mu,mu0),'Initial policy must equal v5 (R = 0).');
        profile = landing2d.rl.profileAgent(agent,arms(k).config,2001,1); counts(k,s) = profile.parameterCount;
        if k>1
            if isempty(residualMean), residualMean = mu; else, assert(isequal(residualMean,mu)); end
        end
        if k>=3
            if isempty(graphEncoder), graphEncoder = agent.policy.encoder;
            else, assert(isequaln(graphEncoder,agent.policy.encoder)); end
        end
    end
end
assert(all(counts==d.parameterCounts,'all'),'Parameter counts changed.');
report.parameterCounts = counts(:,1); report.initialAgentsEqualV5 = numel(counts);

z = linspace(-6,6,41); h = 1e-6;
[y,slope] = landing2d.residual_motion.correctionActivation(z,'soft_linear_v1');
numeric = (landing2d.residual_motion.correctionActivation(z+h,'soft_linear_v1') ...
    -landing2d.residual_motion.correctionActivation(z-h,'soft_linear_v1'))/(2*h);
assert(max(abs(numeric-slope))<1e-8 && all(slope>=0.1-1e-12) && abs(y(end)-(0.9*tanh(6)+0.6))<1e-12);
report.activationSlopeError = max(abs(numeric-slope));

rs = RandStream('threefry','Seed',97501); x = .6*tanh(randn(rs,10,5)); dMu = randn(rs,2,5);
errors = zeros(3,2); names = {'onto_rgat_ppo','shuffled_rgat_ppo','residual_mlp_ppo'};
for m = 1:3
    cfg = landing2d.config.applyMethod(c,names{m},451); agent = landing2d.rl.initialAgent(cfg);
    p = perturb(agent.policy.encoder,rs); spec = agent.encoderSpec;
    assert(strcmp(spec.correctionActivation,'soft_linear_v1'));
    [errors(m,1),errors(m,2)] = finiteDifference(p,spec,x,dMu);
    batch = landing2d.graphstate.encoderForward(p,spec,x);
    for j = 1:size(x,2)
        assert(max(abs(landing2d.graphstate.encoderForward(p,spec,x(:,j))-batch(:,j)))<=1e-12,'Batch must equal columns.');
    end
end
assert(all(errors(:)<2e-7),'Encoder derivatives differ from central differences.');
report.encoderDerivativeErrors = array2table(errors,'RowNames',names,'VariableNames',{'Parameters','Inputs'});

cfg = landing2d.config.applyMethod(c,'onto_rgat_ppo',451); agent = landing2d.rl.initialAgent(cfg);
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

shuffled = landing2d.rl.initialAgent(landing2d.config.applyMethod(c,'shuffled_rgat_ppo',451));
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
smokeConfig.outputDir = fullfile(tempdir,'relational_residual_v6_selftest');
if isfolder(smokeConfig.outputDir), rmdir(smokeConfig.outputDir,'s'); end
runs = landing2d.orchestration.trainRuns(smokeConfig,struct('trainSeeds',451,'methods',{d.methods}, ...
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

arm = landing2d.config.comparisonArms(smokeConfig,struct('methods',{{'onto_rgat_ppo'}},'trainSeed',451));
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
    p.W(:,:,1) = p.W(:,:,1)+.1*randn(rs,8,8); p.a = p.a+.1*randn(rs,size(p.a));
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
