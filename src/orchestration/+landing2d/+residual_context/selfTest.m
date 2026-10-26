function report = selfTest()
% SELFTEST Test the new graph paths, full derivatives, PPO, and preserved base.
c=landing2d.residual_context.config(); old=landing2d.residual_base_init.config();
experiment=old.experiment; experiment.designVersion=c.experiment.designVersion;
assert(isequal(experiment,c.experiment) && isequal(old.rl,c.rl) && isequal(old.evaluation,c.evaluation));
gs=old.graphState; gs.encoderVersion=c.graphState.encoderVersion; gs.topologyVersion=c.graphState.topologyVersion;
assert(isequal(gs,c.graphState));
registry=landing2d.config.methodRegistry(c);
assert(isequal(registry.trainSeeds.residualDev,421:425) && isequal(registry.trainSeeds.residualConfirm,431:440));
[schema,T]=landing2d.residual_context.schema(); [previous,priorT]=landing2d.residual_motion.schema();
assert(isequal(schema.observationIndices,previous.observationIndices) && T.nEdges==10);
assert(isequal(schema.src(1:3),previous.src(1:3)) && isequal(schema.dst(1:3),previous.dst(1:3)));
assert(isequal(sort(unique(T.dst(T.rel~=3))),[2 3 4]) && isequal(unique(priorT.dst(priorT.rel~=3)),4));
assert(isequal(histcounts(T.rel,.5:1:3.5),[2 4 4]));
rs=RandStream('threefry','Seed',74501); x=.6*tanh(randn(rs,10,4)); dMu=randn(rs,2,4);
counts=zeros(4,1); equalityRows=cell(1,20); row=0;
for seed=421:425
    arms=landing2d.config.comparisonArms(c,struct('trainSeed',seed));
    initialGraph=[]; initialCritic=[]; residualMean=[];
    for k=1:4
        cfg=arms(k).config; agent=landing2d.rl.initialAgent(cfg);
        oldCfg=landing2d.config.applyMethod(old,arms(k).id,seed); prior=landing2d.rl.initialAgent(oldCfg);
        assert(isequal(agent.policy,prior.policy) && isequal(agent.value,prior.value) && isequal(agent.rl,prior.rl));
        assert(~landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(oldCfg),cfg));
        landing2d.rl.verifyCheckpointGraph(agent,cfg);
        [~,~,mu]=landing2d.rl.policyAction(agent,x,[],true);
        [~,~,priorMu]=landing2d.rl.policyAction(prior,x,[],true); assert(isequal(mu,priorMu));
        value=landing2d.rl.valueForward(agent,x);
        if isempty(initialCritic), initialCritic=value; else, assert(isequal(initialCritic,value)); end
        if k>1
            if isempty(residualMean), residualMean=mu; else, assert(isequal(residualMean,mu)); end
        end
        profile=landing2d.rl.profileAgent(agent,cfg,2001,1); counts(k)=profile.parameterCount;
        if k>=3
            if isempty(initialGraph), initialGraph=agent.policy.encoder; else, assert(isequal(initialGraph,agent.policy.encoder)); end
            spec=agent.encoderSpec;
            assert(spec.T.nEdges==10 && all(spec.T.rel(7:10)==3));
            if k==4, assert(sum(spec.graph.rel~=spec.graph.canonicalRel)==4); end
        end
        row=row+1; equalityRows{row}=struct('MethodId',string(arms(k).id),'TrainSeed',seed, ...
            'ParametersAndCriticExactlyV4',true,'InitialPolicyExactlyV4',true);
    end
end
assert(isequal(counts,[2095;2098;2089;2089]));

% Nonzero heads and unequal relations exercise every graph parameter, the
% new reverse/quality edges, and actual policy-loss dispatch (TEST ONLY).
cfg=landing2d.config.applyMethod(c,'onto_rgat_ppo',421); agent=landing2d.rl.initialAgent(cfg);
p=agent.policy.encoder; p.R=.03*randn(rs,size(p.R)); p.W(:,:,1)=p.W(:,:,1)+.1*randn(rs,8,8);
spec=agent.encoderSpec; [mu,cache]=landing2d.graphstate.encoderForward(p,spec,x);
[grad,dx]=landing2d.graphstate.encoderBackward(p,spec,cache,dMu);
step=1e-6; parameterError=0; inputError=0; parameterCount=0;
for field=fieldnames(p)'
    key=field{1}; parameterCount=parameterCount+numel(p.(key));
    for j=1:numel(p.(key))
        a=p; b=p; a.(key)(j)=a.(key)(j)+step; b.(key)(j)=b.(key)(j)-step;
        yp=landing2d.graphstate.encoderForward(a,spec,x); ym=landing2d.graphstate.encoderForward(b,spec,x);
        parameterError=max(parameterError,abs(sum((yp-ym).*dMu,'all')/(2*step)-grad.(key)(j)));
    end
end
for j=1:numel(x)
    a=x; b=x; a(j)=a(j)+step; b(j)=b(j)-step;
    yp=landing2d.graphstate.encoderForward(p,spec,a); ym=landing2d.graphstate.encoderForward(p,spec,b);
    inputError=max(inputError,abs(sum((yp-ym).*dMu,'all')/(2*step)-dx(j)));
end
assert(parameterCount==1426 && parameterError<2e-7 && inputError<2e-7);

% Shuffling must change parameter sharing, not just names. At equal semantic
% matrices the encoder functions agree, but their relation gradients differ.
perturbed=landing2d.rl.initialAgent(landing2d.config.applyMethod(c,'shuffled_rgat_ppo',421));
neutral=agent.policy.encoder; neutral.R=p.R;
[canonical,canonicalCache]=landing2d.graphstate.encoderForward(neutral,spec,x);
[shuffled,shuffledCache]=landing2d.graphstate.encoderForward(neutral,perturbed.encoderSpec,x);
assert(isequal(canonical,shuffled));
g1=landing2d.graphstate.encoderBackward(neutral,spec,canonicalCache,dMu);
g2=landing2d.graphstate.encoderBackward(neutral,perturbed.encoderSpec,shuffledCache,dMu);
assert(norm(g1.W(:)-g2.W(:))>1e-8);

% Semantic weights now influence all motion/relative readout nodes, while Q
% retains its own evidence. Test fixed functions, not empirical importance.
changed=p; changed.W(:,:,2)=p.W(:,:,2)+.07*eye(8);
[~,changedCache]=landing2d.graphstate.encoderForward(changed,spec,x);
effect=zeros(1,4);
for node=1:4
    effect(node)=norm(reshape(changedCache.layers{end}.H(:,node,:)-cache.layers{end}.H(:,node,:),[],1));
end
assert(effect(1)==0 && all(effect(2:4)>1e-8));

agent.policy.encoder=p;
noise=.25*randn(rs,2,4); action=mu+exp(agent.policy.logStd).*noise;
oldLog=sum(-.5*noise.^2-agent.policy.logStd-.5*log(2*pi),1); advantage=[-1 .3 1 -.3];
[~,actualGrad]=landing2d.rl.policyLossGradient(agent,x,action,oldLog,advantage,cfg.rl);
ppoError=0;
for key={'W','a','R'}
    for j=1:numel(p.(key{1}))
        ap=agent; am=agent; ap.policy.encoder.(key{1})(j)=p.(key{1})(j)+step;
        am.policy.encoder.(key{1})(j)=p.(key{1})(j)-step;
        [~,~,sp]=landing2d.rl.policyLossGradient(ap,x,action,oldLog,advantage,cfg.rl);
        [~,~,sm]=landing2d.rl.policyLossGradient(am,x,action,oldLog,advantage,cfg.rl);
        ppoError=max(ppoError,abs((sp.loss-sm.loss)/(2*step)-actualGrad.(key{1})(j)));
    end
end
assert(ppoError<2e-7);
report=struct('testOnly',true,'parameters',counts,'initialization',struct2table([equalityRows{:}]), ...
    'maximumParameterError',parameterError,'maximumInputError',inputError,'maximumPpoError',ppoError, ...
    'semanticReadoutNodeEffects',effect,'passed',true);
disp(report);
end
