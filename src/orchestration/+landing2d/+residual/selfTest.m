function report = selfTest()
% SELFTEST Residual architecture contracts and the actual PPO chain rule.
encoder = landing2d.residual.checkEncoder();
c = landing2d.residual.config(); prior = landing2d.minimal.config();
experiment = prior.experiment; experiment.designVersion = c.experiment.designVersion;
assert(isequal(experiment,c.experiment) && isequal(prior.evaluation,c.evaluation));
commonRl = rmfield(c.rl,{'baselinePolicyHiddenSizes'});
assert(isequal(commonRl,rmfield(prior.rl,{'baselinePolicyHiddenSizes'})));
assert(c.graphState.encoderLearnRate==c.rl.policyLearnRate);
arms = landing2d.config.comparisonArms(c,struct('trainSeed',341));
assert(numel(arms)==4);
x = zeros(10,4);
for k = 1:4, [~,x(:,k)] = landing2d.environment.reset(c,2000+k); end
agents = cell(1,4); counts = zeros(4,1);
for k = 1:4
    cfg = arms(k).config; agent = landing2d.rl.initialAgent(cfg); agents{k} = agent;
    agentProfile = landing2d.rl.profileAgent(agent,cfg,1,1); counts(k) = agentProfile.parameterCount;
    assert(isempty(fieldnames(agent.value.encoder)));
    if k>1
        assert(strcmp(agent.encoderSpec.mode,'residual_actor'));
        assert(isequal(agent.value,agents{1}.value));
        assert(isequal(landing2d.rl.valueForward(agent,x),landing2d.rl.valueForward(agents{1},x)));
        [~,valueEncoderGrad] = landing2d.rl.valueLossGradient(agent,x,[.2 -.1 .3 -.2]);
        assert(isempty(fieldnames(valueEncoderGrad)));
    end
    if k>2
        assert(isequal(agent.policy.mean,agents{2}.policy.mean));
        assert(isequal(agent.policy.encoder.Pb,agents{2}.policy.encoder.Pb));
    end
    assert(~landing2d.rl.signatureMatches(landing2d.rl.trainingSignature( ...
        landing2d.config.applyMethod(prior,'ppo',341)),cfg));
end
assert(isequal(counts,[2095;2112;2101;2101]));
agent = agents{3}; cfg = arms(3).config;
[~,~,mu] = landing2d.rl.policyAction(agent,x,[],true);
noise = [.3,-.4,.2,-.1;-.2,.1,.4,-.3];
actions = mu+exp(agent.policy.logStd).*noise;
oldLog = sum(-.5*noise.^2-agent.policy.logStd-.5*log(2*pi),1);
advantage = [1,-.4,.8,-.6];
[head,grad] = landing2d.rl.policyLossGradient(agent,x,actions,oldLog,advantage,cfg.rl);
[head2,grad2,stats] = landing2d.rl.policyLossGradient(agent,x,actions,oldLog,advantage,cfg.rl);
assert(isequal(head,head2) && isequal(grad,grad2) && isfinite(stats.loss));
maximumError = 0; step = 1e-6;
for name = {'W','a','beta','Pb','R','lnScale'}
    key = name{1};
    for k = 1:numel(grad.(key))
        plusAgent = agent; minusAgent = agent;
        plusAgent.policy.encoder.(key)(k) = plusAgent.policy.encoder.(key)(k)+step;
        minusAgent.policy.encoder.(key)(k) = minusAgent.policy.encoder.(key)(k)-step;
        [~,~,p] = landing2d.rl.policyLossGradient(plusAgent,x,actions,oldLog,advantage,cfg.rl);
        [~,~,m] = landing2d.rl.policyLossGradient(minusAgent,x,actions,oldLog,advantage,cfg.rl);
        maximumError = max(maximumError,abs((p.loss-m.loss)/(2*step)-grad.(key)(k)));
    end
end
assert(maximumError<2e-7,'Actual PPO derivative failed.');
assert(norm(grad.W(:))>1e-8 && norm(grad.a)>1e-8 && norm(grad.Pb,'fro')>1e-8);
report = struct('testOnly',true,'encoder',encoder,'parameters',counts, ...
    'maximumPpoDerivativeError',maximumError,'passed',true);
fprintf('Residual contracts/common critic/PPO chain PASS, max error %.3g (TEST ONLY).\n',maximumError);
end
