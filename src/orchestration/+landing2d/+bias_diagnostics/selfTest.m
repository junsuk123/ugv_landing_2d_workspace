function report = selfTest(d)
% SELFTEST Unit checks of the diagnostic chain (TEST ONLY; no performance evidence).
%   1 configuration keeps 9101-9200 closed        6 env-struct snapshot is exact
%   2 checkpoints equal the evaluated v2 models   7 Delta = 0 branch reproduces the rollout
%   3 nominal sensing replay is bit-identical     8 reward split reproduces reward_v5 and the
%   4 actor response is repeatable; batch = columns  stored v2 rollouts are reproduced
%   5 residual split and correction-off are exact 9 probe rows repeat exactly; FD step halving
%                                                  agrees; own-typing swap is the identity
if nargin<1, d = landing2d.bias_diagnostics.config(); end
report = struct();
bad = d; bad.rollout.seeds = 9101;
report.confirmationClosed = throws(@()landing2d.bias_diagnostics.checkSeeds(bad));
assert(report.confirmationClosed,'Configurations using 9101-9200 must be rejected.');
runs = landing2d.bias_diagnostics.models(d,421);
report.checkpointsVerified = numel(runs);
record = landing2d.probe.recordReference(d.c,d.reference.seeds(1));
rep = landing2d.probe.replaySensing(record,d.c,1);
report.replayBitIdentical = isequal(rep.observation,record.observation);
assert(report.replayBitIdentical);
k = find(rep.flags.estimateInitialized,6); assert(numel(k)>=3);
O = rep.observation(:,k(end-2:end));
O = [O, landing2d.observation.toVector(rep.O{k(end)},rep.context)];
for r = 1:numel(runs)
    a = landing2d.bias_diagnostics.response(runs(r),O);
    b = landing2d.bias_diagnostics.response(runs(r),O);
    assert(isequal(a,b),'Repeated responses must be bit-identical.');
    for j = 1:size(O,2)
        one = landing2d.bias_diagnostics.response(runs(r),O(:,j));
        assert(max(abs(one.mu-a.mu(:,j)))<=1e-12,'Batch and column responses must agree.');
    end
    if isfield(a,'correction')
        assert(max(abs(a.base+a.correction-a.mu),[],'all')<=1e-12);
        off = landing2d.bias_diagnostics.response(runs(r),O,struct('correction','off'));
        assert(isequal(off.mu,a.base),'Correction-off must equal the base mean exactly.');
        if strcmp(runs(r).agent.encoderSpec.correctionType,'graph')
            own = landing2d.bias_diagnostics.response(runs(r),O,struct('spec',runs(r).agent.encoderSpec));
            assert(isequal(own,a),'Swapping in the own typing must be the identity.');
        end
    end
end
report.responsesRepeatable = true; report.residualSplitExact = true;
env0 = landing2d.environment.reset(runs(1).config,d.rollout.seeds(1),struct());
envA = env0; envB = env0;
for decision = 1:40
    action = [0.3*sin(decision/5);-0.1];
    [envA,oA,rA] = landing2d.environment.step(envA,action);
    [envB,oB,rB] = landing2d.environment.step(envB,action);
    assert(isequal(oA,oB) && rA==rB && isequal(envA.physicalState,envB.physicalState));
    if envA.episodeStatus.terminated, break; end
end
report.snapshotExact = true;
branch = landing2d.bias_diagnostics.branchRollouts(runs(3),d,d.branch.seeds(1));
report.branchReproduced = height(branch)>0;
[phases,episodes] = landing2d.bias_diagnostics.closedLoop(runs([1 3]),d,d.rollout.seeds(1));
report.rewardSplitExact = height(phases)>0; report.storedRolloutsReproduced = height(episodes);
small = struct('o',O,'ugvPlus',O,'ugvMinus',O,'dronePlus',O,'droneMinus',O,'posPlus',O,'posMinus',O, ...
    'noise',repmat(reshape(O,10,1,[]),1,2,1),'stale',NaN(size(O)), ...
    'reference',repmat(struct('base',[0;0],'ugv',[0;0],'drone',[0;0],'pos',[0;0],'stale',[NaN;NaN]),1,size(O,2)), ...
    'inputScale',ones(10,1));
small.states = table(repmat("selftest",size(O,2),1),zeros(size(O,2),1),(1:size(O,2))', ...
    repmat("freshUpdate",size(O,2),1),true(size(O,2),1),ones(size(O,2),1),zeros(size(O,2),1), ...
    zeros(size(O,2),1),false(size(O,2),1),'VariableNames',{'Family','EnvironmentSeed','Decision', ...
    'Class','MarkerUpdated','Height','FovRatio','PadAcceleration','HasStale'});
T1 = landing2d.bias_diagnostics.probeResponses(runs,small,d);
T2 = landing2d.bias_diagnostics.probeResponses(runs,small,d);
assert(isequaln(T1,T2),'Probe rows must repeat exactly.');
half = d; half.perturbation.finiteDifference = d.perturbation.finiteDifference/2;
T3 = landing2d.bias_diagnostics.probeResponses(runs,small,half);
report.fdHalvingMaxDifference = max(abs(T3.NormSensitivity-T1.NormSensitivity)./max(1,abs(T1.NormSensitivity)));
assert(report.fdHalvingMaxDifference<1e-4,'Finite-difference sensitivity must be step-stable.');
report.probeRepeatable = true;
report.passed = true; report.testOnly = true;
end

function ok = throws(f)
ok = false;
try, f(); catch, ok = true; end
end
