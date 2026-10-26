function report = checkInitialization()
% TEST ONLY: the v4 initial state differs from v3 only in base output weights.
c = landing2d.residual_base_init.config(); prior = landing2d.residual_motion.config();
x = zeros(10,20);
for j = 1:20, [~,x(:,j)] = landing2d.environment.reset(c,2000+j); end
noise = randn(RandStream('threefry','Seed',74391),2,size(x,2));
advantage = sin(1:size(x,2)); advantage = (advantage-mean(advantage))/std(advantage);
rows = cell(1,20); index = 0;
for trainSeed = 381:385
    arms = landing2d.config.comparisonArms(c,struct('trainSeed',trainSeed));
    referenceValue = []; residualMu = []; secondRelation = cell(1,2); graphIndex = 0;
    for k = 1:4
        cfg = arms(k).config; agent = landing2d.rl.initialAgent(cfg);
        oldCfg = landing2d.config.applyMethod(prior,arms(k).id,trainSeed);
        original = landing2d.rl.initialAgent(oldCfg); expected = original;
        rs = RandStream('threefry','Seed',cfg.rl.seed+31001);
        if strcmp(arms(k).id,'ppo')
            base = landing2d.rl.mlpInit([10 cfg.rl.baselinePolicyHiddenSizes 2],.1,rs);
            expected.policy.mean.W{end} = base.W{end};
        else
            base = landing2d.rl.mlpInit([10 74 2],.1,rs);
            expected.policy.encoder.B2 = base.W{end};
            assert(all(agent.policy.encoder.R==0,'all'));
        end
        same = expected;
        if isfield(same.encoderSpec,'encoderVersion'), same.encoderSpec.encoderVersion = 'relational_residual_v4'; end
        assert(isequaln(agent,same),'Only the base output initializer and version metadata may change.');
        assert(isequal(agent.value,original.value) && isequal(agent.policy.logStd,original.policy.logStd));
        assert(~landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(oldCfg),cfg));
        landing2d.rl.verifyCheckpointGraph(agent,cfg);
        [~,~,mu] = landing2d.rl.policyAction(agent,x,[],true);
        [~,~,expectedMu] = landing2d.rl.policyAction(expected,x,[],true);
        assert(isequal(mu,expectedMu) && all(isfinite(mu),'all') && any(mu~=0,'all'));
        value = landing2d.rl.valueForward(agent,x);
        if isempty(referenceValue), referenceValue = value; else, assert(isequal(value,referenceValue)); end
        if k>1
            if isempty(residualMu), residualMu = mu; else, assert(isequal(mu,residualMu)); end
        end
        action = mu+exp(agent.policy.logStd).*noise;
        oldLog = sum(-.5*noise.^2-agent.policy.logStd-.5*log(2*pi),1);
        [head,grad] = landing2d.rl.policyLossGradient(agent,x,action,oldLog,advantage,cfg.rl);
        [oldHead,oldGrad] = landing2d.rl.policyLossGradient(expected,x,action,oldLog,advantage,oldCfg.rl);
        assert(isequal(head,oldHead) && isequal(grad,oldGrad),'V3 and v4 equations must be identical.');
        if k==1
            firstHiddenNorm = norm(head.mean.W{1},'fro');
        else
            firstHiddenNorm = norm(grad.B1,'fro');
            assert(norm(grad.R,'fro')>1e-12 && grad.beta==0);
            if isfield(grad,'W'), assert(all(grad.W==0,'all')); else, assert(all(grad.F==0,'all')); end
        end
        assert(firstHiddenNorm>1e-12);
        joint = landing2d.util.clipGradient(struct('head',head,'encoder',grad),cfg.rl.maxGradNorm);
        core = struct('mean',agent.policy.mean,'logStd',agent.policy.logStd);
        core = landing2d.util.adamUpdate(core,joint.head,landing2d.util.adamInit(core),cfg.rl.policyLearnRate);
        agent.policy.mean = core.mean; agent.policy.logStd = core.logStd;
        secondRelationNorm = NaN;
        if k>1
            p = agent.policy.encoder;
            agent.policy.encoder = landing2d.util.adamUpdate(p,joint.encoder,landing2d.util.adamInit(p),cfg.rl.policyLearnRate);
            [~,secondGrad] = landing2d.rl.policyLossGradient(agent,x,action,oldLog,advantage,cfg.rl);
            if isfield(secondGrad,'W')
                secondRelationNorm = norm(secondGrad.W(:)); assert(secondRelationNorm>1e-12);
                graphIndex = graphIndex+1; secondRelation{graphIndex} = secondGrad.W;
            else
                assert(norm(secondGrad.F,'fro')>1e-12);
            end
        end
        index = index+1;
        rows{index} = struct('MethodId',string(arms(k).id),'TrainSeed',trainSeed, ...
            'InitialMeanAbsMax',max(abs(mu),[],'all'),'FirstBaseHiddenGradientNorm',firstHiddenNorm, ...
            'SecondRelationGradientNorm',secondRelationNorm,'OnlyBaseOutputWeightsChanged',true);
    end
    assert(graphIndex==2 && ~isequal(secondRelation{1},secondRelation{2}));
end
report = struct('testOnly',true,'models',struct2table([rows{:}]), ...
    'initialResidualFunctionsEqual',true,'commonCriticPreserved',true,'equationsUnchanged',true,'passed',true);
end
