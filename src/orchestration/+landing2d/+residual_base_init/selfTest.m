function report = selfTest()
% SELFTEST Single-factor initializer, unchanged equations, common contracts.
c = landing2d.residual_base_init.config(); prior = landing2d.residual_motion.config();
experiment = prior.experiment; experiment.designVersion = c.experiment.designVersion;
assert(isequal(experiment,c.experiment) && isequal(prior.evaluation,c.evaluation));
assert(isequal(prior.rl,c.rl) && c.graphState.encoderLearnRate==c.rl.policyLearnRate);
gs = prior.graphState; gs.encoderVersion = c.graphState.encoderVersion;
gs.actorMeanInitialization = c.graphState.actorMeanInitialization;
assert(isequaln(gs,c.graphState));
registry = landing2d.config.methodRegistry(c);
assert(isequal(registry.trainSeeds.residualPaired,381:385) ...
    && isequal(registry.trainSeeds.residualFresh,401:405) ...
    && isequal(registry.trainSeeds.residualConfirm,411:420));
arms = landing2d.config.comparisonArms(c,struct('trainSeed',381)); assert(numel(arms)==4);
counts = zeros(4,1);
for k = 1:4
    cfg = arms(k).config; agent = landing2d.rl.initialAgent(cfg);
    agentProfile = landing2d.rl.profileAgent(agent,cfg,2001,1); counts(k) = agentProfile.parameterCount;
    assert(isempty(fieldnames(agent.value.encoder)));
    if k>1
        assert(strcmp(agent.encoderSpec.encoderVersion,'relational_residual_v4'));
        assert(isempty(agent.policy.mean.W) && isempty(agent.policy.mean.b));
    end
end
assert(isequal(counts,[2095;2098;2089;2089]));
initialization = landing2d.residual_base_init.checkInitialization();
% V4 directly reuses these V3 forward/backward functions. The finite-difference
% fixture activates every branch; the initialization check also verifies the
% actual V4 dispatcher and common PPO gradient against the V3 counterfactual.
derivatives = landing2d.residual_motion.checkEncoder();
report = struct('testOnly',true,'parameters',counts,'initialization',initialization, ...
    'sharedEquationDerivatives',derivatives,'passed',true);
fprintf('Residual v4 initializer, contracts, actual PPO paths, and shared derivatives PASS (TEST ONLY).\n');
end
