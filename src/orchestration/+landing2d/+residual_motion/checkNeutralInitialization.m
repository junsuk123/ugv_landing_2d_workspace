function report = checkNeutralInitialization()
% TEST ONLY: actual configured initial distributions and two-stage PPO gradient flow.
c = landing2d.residual_motion.config(); trainSeeds = 381:385; validationSeeds = 2001:2020;
x = zeros(10,numel(validationSeeds));
for k = 1:numel(validationSeeds), [~,x(:,k)] = landing2d.environment.reset(c,validationSeeds(k)); end
rs = RandStream('threefry','Seed',74391);
noise = randn(rs,2,size(x,2));
advantage = sin(1:size(x,2)); advantage = (advantage-mean(advantage))/std(advantage);
rows = cell(1,20); rowIndex = 0;
for trainSeed = trainSeeds
    arms = landing2d.config.comparisonArms(c,struct('trainSeed',trainSeed));
    referenceAction = []; referenceLog = []; referenceValue = [];
    for k = 1:4
        cfg = arms(k).config; original = landing2d.rl.initialAgent(cfg); agent = original;
        [~,~,originalMu] = landing2d.rl.policyAction(original,x,[],true);
        assert(all(originalMu==0,'all'),'The configured initial actor mean must be zero.');
        % Biases already start at zero; random hidden weights remain intact.
        assert(isequal(agent.value,original.value) && isequal(agent.policy.logStd,original.policy.logStd));
        [~,~,mu] = landing2d.rl.policyAction(agent,x,[],true); assert(all(mu==0,'all'));
        [action,oldLog] = landing2d.rl.policyAction(agent,x,RandStream('threefry','Seed',74392),false);
        value = landing2d.rl.valueForward(agent,x);
        if k==1
            referenceAction = action; referenceLog = oldLog; referenceValue = value;
        else
            assert(isequal(action,referenceAction) && isequal(oldLog,referenceLog) && isequal(value,referenceValue));
        end
        action = exp(agent.policy.logStd).*noise;
        oldLog = sum(-.5*noise.^2-agent.policy.logStd-.5*log(2*pi),1);
        [head,grad] = landing2d.rl.policyLossGradient(agent,x,action,oldLog,advantage,cfg.rl);
        if k==1
            firstOutputNorm = norm(head.mean.W{end},'fro');
            assert(all(head.mean.W{1}==0,'all'));
        else
            firstOutputNorm = norm(grad.B2,'fro')+norm(grad.R,'fro');
            assert(all(grad.B1==0,'all') && grad.beta==0);
            if isfield(grad,'W'), assert(all(grad.W==0,'all')); else, assert(all(grad.F==0,'all')); end
        end
        assert(firstOutputNorm>1e-10);
        joint = landing2d.util.clipGradient(struct('head',head,'encoder',grad),cfg.rl.maxGradNorm);
        core = struct('mean',agent.policy.mean,'logStd',agent.policy.logStd);
        core = landing2d.util.adamUpdate(core,joint.head,landing2d.util.adamInit(core),cfg.rl.policyLearnRate);
        agent.policy.mean = core.mean; agent.policy.logStd = core.logStd;
        if k>1
            p = agent.policy.encoder;
            agent.policy.encoder = landing2d.util.adamUpdate(p,joint.encoder,landing2d.util.adamInit(p),cfg.rl.policyLearnRate);
        end
        [secondHead,secondGrad] = landing2d.rl.policyLossGradient(agent,x,action,oldLog,advantage,cfg.rl);
        relationNorm = NaN;
        if k==1
            secondHiddenNorm = norm(secondHead.mean.W{1},'fro');
        else
            secondHiddenNorm = norm(secondGrad.B1,'fro');
            if isfield(secondGrad,'W')
                relationNorm = norm(secondGrad.W(:)); assert(relationNorm>1e-12);
            else
                assert(norm(secondGrad.F,'fro')>1e-12);
            end
        end
        assert(secondHiddenNorm>1e-12);
        rowIndex = rowIndex+1;
        rows{rowIndex} = struct('MethodId',string(arms(k).id),'TrainSeed',trainSeed, ...
            'OriginalMeanAbsMax',max(abs(originalMu),[],'all'), ...
            'NeutralMeanAbsMax',max(abs(mu),[],'all'), ...
            'FirstOutputGradientNorm',firstOutputNorm,'SecondHiddenGradientNorm',secondHiddenNorm, ...
            'SecondRelationGradientNorm',relationNorm,'MatchedInitialDistribution',true);
    end
end
report = struct('testOnly',true,'models',struct2table([rows{:}]),'passed',true);
end
