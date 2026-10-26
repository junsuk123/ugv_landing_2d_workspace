function report = selfTest()
% SELFTEST Direct-mean residual contracts and actual clipped PPO derivatives.
encoder = landing2d.residual_logits.checkEncoder();
c = landing2d.residual_logits.config(); prior = landing2d.residual.config();
experiment = prior.experiment; experiment.designVersion = c.experiment.designVersion;
assert(isequal(experiment,c.experiment) && isequal(prior.evaluation,c.evaluation));
assert(isequal(prior.rl,c.rl) && c.graphState.encoderLearnRate==c.rl.policyLearnRate);
registry = landing2d.config.methodRegistry(c);
assert(isequal(registry.trainSeeds.residualDev,361:365) ...
    && isequal(registry.trainSeeds.residualConfirm,371:380));
arms = landing2d.config.comparisonArms(c,struct('trainSeed',361)); assert(numel(arms)==4);
x = zeros(10,4);
for k = 1:4, [~,x(:,k)] = landing2d.environment.reset(c,2000+k); end
agents = cell(1,4); counts = zeros(4,1);
for k = 1:4
    cfg = arms(k).config; agent = landing2d.rl.initialAgent(cfg); agents{k} = agent;
    agentProfile = landing2d.rl.profileAgent(agent,cfg,2001,1); counts(k) = agentProfile.parameterCount;
    assert(isempty(fieldnames(agent.value.encoder)));
    oldCfg = landing2d.config.applyMethod(prior,arms(k).id,361);
    assert(~landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(oldCfg),cfg));
    landing2d.rl.verifyCheckpointGraph(agent,cfg);
    if k==1
        assert(isequaln(agent,landing2d.rl.initialAgent(oldCfg)),'Plain PPO initialization changed.');
    else
        assert(isempty(agent.policy.mean.W) && isempty(agent.policy.mean.b));
        assert(strcmp(agent.encoderSpec.encoderVersion,'relational_residual_v2'));
        assert(isequal(agent.value,agents{1}.value));
        assert(isequal(landing2d.rl.valueForward(agent,x),landing2d.rl.valueForward(agents{1},x)));
        [~,criticEncoderGradient] = landing2d.rl.valueLossGradient(agent,x,[.2 -.1 .3 -.2]);
        assert(isempty(fieldnames(criticEncoderGradient)));
    end
    if k>2
        for key = {'B1','b1','B2','b2'}
            assert(isequal(agent.policy.encoder.(key{1}),agents{2}.policy.encoder.(key{1})));
        end
    end
end
assert(isequal(counts,[2095;2098;2089;2089]));
[~,~,ontoMu] = landing2d.rl.policyAction(agents{3},x,[],true);
[~,~,shuffledMu] = landing2d.rl.policyAction(agents{4},x,[],true);
assert(isequal(ontoMu,shuffledMu));
maximumError = 0; step = 1e-6;
for arm = [2 3]
    agent = agents{arm}; cfg = arms(arm).config;
    [~,~,mu] = landing2d.rl.policyAction(agent,x,[],true);
    noise = [.3,-.4,.2,-.1;-.2,.1,.4,-.3];
    actions = mu+exp(agent.policy.logStd).*noise;
    oldLog = sum(-.5*noise.^2-agent.policy.logStd-.5*log(2*pi),1)-log([1 .5 1.6 1.1]);
    advantage = [1,-.4,.8,-.6];
    [head,grad] = landing2d.rl.policyLossGradient(agent,x,actions,oldLog,advantage,cfg.rl);
    [head2,grad2,stats] = landing2d.rl.policyLossGradient(agent,x,actions,oldLog,advantage,cfg.rl);
    assert(isequal(head,head2) && isequal(grad,grad2) && isfinite(stats.loss) && stats.clipFraction>0);
    if arm==3
        gradientFields = {'B1','B2','beta','R','W','a'};
    else
        gradientFields = {'B1','B2','beta','R','F'};
    end
    for name = gradientFields
        key = name{1};
        for j = 1:numel(grad.(key))
            plusAgent = agent; minusAgent = agent;
            plusAgent.policy.encoder.(key)(j) = plusAgent.policy.encoder.(key)(j)+step;
            minusAgent.policy.encoder.(key)(j) = minusAgent.policy.encoder.(key)(j)-step;
            [~,~,p] = landing2d.rl.policyLossGradient(plusAgent,x,actions,oldLog,advantage,cfg.rl);
            [~,~,m] = landing2d.rl.policyLossGradient(minusAgent,x,actions,oldLog,advantage,cfg.rl);
            maximumError = max(maximumError,abs((p.loss-m.loss)/(2*step)-grad.(key)(j)));
        end
    end
    assert(norm(grad.B1,'fro')>1e-8 && norm(grad.R,'fro')>1e-8);
    if arm==3, assert(norm(grad.W(:))>1e-8 && norm(grad.a)>1e-8); end
    joint = landing2d.util.clipGradient(struct('head',head,'encoder',grad),c.rl.maxGradNorm);
    optimizer = landing2d.util.adamInit(agent.policy.encoder);
    updated = landing2d.util.adamUpdate(agent.policy.encoder,joint.encoder,optimizer,c.rl.policyLearnRate);
    assert(norm(updated.B1-agent.policy.encoder.B1,'fro')>0 && norm(updated.R-agent.policy.encoder.R,'fro')>0);
end
assert(maximumError<2e-7,'Actual PPO derivative failed.');
report = struct('testOnly',true,'encoder',encoder,'parameters',counts, ...
    'maximumPpoDerivativeError',maximumError,'commonCriticPreserved',true,'passed',true);
fprintf('Residual v2 contracts/common critic/PPO chain PASS, max error %.3g (TEST ONLY).\n',maximumError);
end
