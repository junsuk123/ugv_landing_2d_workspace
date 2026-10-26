function checkNeutralRelationInitialization()
% CHECKNEUTRALRELATIONINITIALIZATION TEST ONLY: equal functions, grouped updates.
root = landing2d.orchestration.projectRoot();
c = landing2d.minimal.config(root,'v33'); prior = landing2d.minimal.config(root,'v32');
assert(isequaln(c.rl,prior.rl) && isequaln(c.experiment,prior.experiment) ...
    && isequaln(c.evaluation,prior.evaluation));
assert(isequaln(rmfield(c.graphState,'relationInitialization'),prior.graphState));
for seed = [271,291,294]
    pair = cell(1,2);
    for method = {'ppo','onto_rgat_ppo','shuffled_rgat_ppo'}
        cfg = landing2d.config.applyMethod(c,method{1},seed);
        oldCfg = landing2d.config.applyMethod(prior,method{1},seed);
        agent = landing2d.rl.initialAgent(cfg); old = landing2d.rl.initialAgent(oldCfg);
        signature = landing2d.rl.trainingSignature(cfg);
        assert(strcmp(signature.algorithmVersion,'minimal-relational-v3.3'));
        assert(landing2d.rl.signatureMatches(signature,cfg));
        assert(~landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(oldCfg),cfg));
        if seed==271
            profile = landing2d.rl.profileAgent(agent,cfg,2001,1);
            assert(profile.parameterCount==1419);
        end
        if strcmp(method{1},'ppo')
            assert(isequaln(agent.policy,old.policy) && isequaln(agent.value,old.value));
            continue;
        end
        for role = {'policy','value'}
            expected = old.(role{1});
            common = (expected.encoder.W(:,:,1)+expected.encoder.W(:,:,2))/sqrt(2);
            expected.encoder.W(:,:,1) = common; expected.encoder.W(:,:,2) = common;
            assert(isequaln(agent.(role{1}),expected), ...
                'Only the two initial semantic transforms may change.');
        end
        assert(agent.encoderSpec.layers==2 ...
            && strcmp(agent.encoderSpec.evidenceSource,'initial_projection') ...
            && strcmp(agent.encoderSpec.relationInitialization,'shared_semantic_v1'));
        index = 1+strcmp(method{1},'shuffled_rgat_ppo'); pair{index} = agent;
    end
    x = zeros(40,4);
    for k = 1:4
        [~,o] = landing2d.environment.reset(c,2000+k);
        x(:,k) = landing2d.minimal.features(o);
    end
    a = pair{1}; b = pair{2};
    assert(isequaln(a.policy,b.policy) && isequaln(a.value,b.value));
    muA = landing2d.rl.policyAction(a,x,[],true); muB = landing2d.rl.policyAction(b,x,[],true);
    valueA = landing2d.rl.valueForward(a,x); valueB = landing2d.rl.valueForward(b,x);
    assert(isequal(muA,muB) && isequal(valueA,valueB),'Initial functions must be bit-equal.');
    z = [.3,-.4,.2,-.1;-.2,.1,.4,-.3];
    actions = muA+exp(a.policy.logStd).*z;
    oldLog = sum(-.5*z.^2-a.policy.logStd-.5*log(2*pi),1);
    advantage = [1,-.4,.8,-.6];
    [ha,ea,sa] = landing2d.rl.policyLossGradient(a,x,actions,oldLog,advantage,c.rl);
    [hb,eb,sb] = landing2d.rl.policyLossGradient(b,x,actions,oldLog,advantage,c.rl);
    [hva,eva,sva] = landing2d.rl.valueLossGradient(a,x,[.2,-.3,.4,-.1]);
    [hvb,evb,svb] = landing2d.rl.valueLossGradient(b,x,[.2,-.3,.4,-.1]);
    assert(isequaln(ha,hb) && isequaln(hva,hvb) && sa.loss==sb.loss && sva.loss==svb.loss);
    assert(norm(ea.W(:)-eb.W(:))>1e-10 && norm(eva.W(:)-evb.W(:))>1e-10);
    assert(max(abs(sum(ea.W(:,:,1:2),3)-sum(eb.W(:,:,1:2),3)),[],'all')<1e-11);
    assert(max(abs(sum(eva.W(:,:,1:2),3)-sum(evb.W(:,:,1:2),3)),[],'all')<1e-11);
end
% Equal initial values must not accidentally tie the two parameter arrays
% during differentiation. Perturb every parameter and every input separately.
rs = RandStream('threefry','Seed',173);
x = .2*randn(rs,40,3); dG = randn(rs,8,3);
p = a.policy.encoder; spec = a.encoderSpec;
[g,cache] = landing2d.minimal.encoderForward(p,spec,x);
[grad,dx] = landing2d.minimal.encoderBackward(p,spec,cache,dG);
epsilon = 1e-6; maximumError = 0;
for name = fieldnames(p)'
    key = name{1};
    for k = 1:numel(p.(key))
        plus = p; minus = p;
        plus.(key)(k) = plus.(key)(k)+epsilon; minus.(key)(k) = minus.(key)(k)-epsilon;
        numerical = (objective(plus,spec,x,dG)-objective(minus,spec,x,dG))/(2*epsilon);
        maximumError = max(maximumError,abs(numerical-grad.(key)(k)));
    end
end
for k = 1:numel(x)
    plus = x; minus = x; plus(k) = plus(k)+epsilon; minus(k) = minus(k)-epsilon;
    numerical = (objective(p,spec,plus,dG)-objective(p,spec,minus,dG))/(2*epsilon);
    maximumError = max(maximumError,abs(numerical-dx(k)));
end
assert(maximumError<2e-7,'Neutral initialization derivative error %.3g.',maximumError);
for k = 1:3
    one = landing2d.minimal.encoderForward(p,spec,x(:,k));
    assert(max(abs(one-g(:,k)))<1e-12);
end
landing2d.minimal.checkLearningPath(c);
bad = c.graphState; bad.relationInitialization = 'unsupported'; rejected = false;
try
    landing2d.minimal.validateGraphConfig(bad);
catch err
    rejected = strcmp(err.identifier,'landing2d:MinimalInitialization');
end
assert(rejected,'Unknown initialization must not silently reuse an old signature.');
fprintf('    TEST ONLY equal initial functions; grouped PPO gradients; 371 parameters + 120 inputs, max error %.3g\n',maximumError);
end

function value = objective(p,spec,x,dG)
g = landing2d.minimal.encoderForward(p,spec,x); value = sum(g.*dG,'all');
end
