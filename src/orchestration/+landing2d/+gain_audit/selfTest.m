function report = selfTest(d)
% SELFTEST Unit checks of control_gain_audit_v1 (TEST ONLY; no performance evidence).
%   1 configurations opening 9101-9200 are rejected
%   2 checkpoints equal the evaluated protocol-v2 models (identity hash)
%   3 k = 1 is bit-identical to landing2d.rl.rolloutEpisodeV2 (four methods)
%   4 k = 2: a_x = clip(2 tanh mu_x) and a_z = tanh mu_z exactly at every decision;
%     requested = limits .* normalized; direct application (no supervisor change)
%   5 k = 1 rows reproduce the stored v2 episodes (reproduce)
%   6 aggregation and criteria on synthetic tables: seed-block means, the
%     df = 4 t interval and the four verdict branches
if nargin<1, d = landing2d.gain_audit.config(); end
report = struct();
bad = d; bad.environmentSeeds = 9101;
report.confirmationClosed = throws(@()landing2d.gain_audit.checkSeeds(bad));
assert(report.confirmationClosed,'Configurations using 9101-9200 must be rejected.');
runs = landing2d.bias_diagnostics.models(d,421);
report.checkpointsVerified = numel(runs);
seed = d.environmentSeeds(1);
limits = landing2d.environment.actionLimits(d.c);
for r = 1:numel(runs)
    for cellIndex = [2 6]                                      % motion OOD, noise OOD
        [c,scale] = landing2d.bias_diagnostics.condition(d,runs(r).config, ...
            d.cells{cellIndex,1},d.cells{cellIndex,2});
        [r0,t0] = landing2d.rl.rolloutEpisodeV2(runs(r).agent,c,seed, ...
            struct('deterministic',true,'run',runs(r).identity,'sensorNoiseScale',scale));
        [r1,t1] = landing2d.gain_audit.rollout(runs(r).agent,c,seed,1,struct('sensorNoiseScale',scale));
        assert(isequaln(r0,r1) && isequaln(t0,t1),'landing2d:GainAuditIdentity', ...
            'k = 1 must equal rolloutEpisodeV2 (%s, cell %d).',runs(r).id,cellIndex);
        [~,t2,info] = landing2d.gain_audit.rollout(runs(r).agent,c,seed,2,struct('sensorNoiseScale',scale));
        assert(isequal(t2.command,t2.actorMean),'Deterministic: command = actor mean.');
        assert(isequal(t2.normalizedAction(2,:),tanh(t2.command(2,:))),'a_z must be unchanged.');
        assert(isequal(t2.normalizedAction(1,:),min(max(2*tanh(t2.command(1,:)),-1),1)), ...
            'a_x must be clip(2 tanh mu_x).');
        assert(isequal(t2.requestedAcceleration,limits.*t2.normalizedAction),'requested = limits .* a.');
        assert(~any(t2.safetyIntervened) && max(abs(t2.appliedAccelerationIntervalMean- ...
            t2.requestedAcceleration),[],'all')<=1e-12,'Direct policy: applied = requested.');
        assert(info.ClippedFraction==mean(abs(2*tanh(t2.command(1,:)))>1));
    end
end
report.gainOneBitIdentical = true; report.gainTwoExact = true; report.directApplication = true;
E = landing2d.gain_audit.episodes(runs,d,seed);
R = landing2d.gain_audit.reproduce(E,d);
report.storedEpisodesReproduced = height(R);
report.maxAimDifference_m = max(R.AimAbsDiff_m);
report.synthetic = syntheticChecks(d);
end

function out = syntheticChecks(d)
% Known paired differences per (cell, method, seed); 10 environments per model.
n = 10; k2 = 2.7764451051977987;                           % t(0.975, df = 4)
plan = struct('motionOOD',[3 0 -0.2],'motionID',[0 0 0],'noiseOOD',[0 0 0]);
A = landing2d.gain_audit.analyze(synthetic(d,n,plan),d);
block = A.bySeed(A.bySeed.Factor=="motion" & A.bySeed.Shift=="OOD",:);
row = A.cells(A.cells.Factor=="motion" & A.cells.Shift=="OOD",:);
assert(abs(row.dS_mean-mean(block.dS))<=1e-12);
assert(abs((row.dS_high-row.dS_mean)-k2*std(block.dS)/sqrt(5))<=1e-9,'t interval df = 4.');
expected = mean(arrayfun(@(s)mean(arrayfun(@(m)100*extra(3,m,s)/n,1:4)),1:5));
assert(abs(row.dS_mean-expected)<=1e-12,'Seed blocks are the equal-weight method means.');
assert(A.verdict=="acceleration_gain_bottleneck_only" && A.flags.G && ~A.flags.B && ~A.flags.C);
plan.motionID = [0 0 -0.2];
A = landing2d.gain_audit.analyze(synthetic(d,n,plan),d);
assert(A.verdict=="global_low_gain_supported" && A.flags.B);
plan.noiseOOD = [-4 0 0];
A = landing2d.gain_audit.analyze(synthetic(d,n,plan),d);
assert(A.verdict=="trade_off_supported" && A.flags.C && ~A.flags.B);
plan = struct('motionOOD',[-3 0 0.2],'motionID',[0 0 0],'noiseOOD',[0 0 0]);
A = landing2d.gain_audit.analyze(synthetic(d,n,plan),d);
assert(A.verdict=="worse" && ~A.flags.G);
out = struct('verdictBranches',4,'intervalDf4',true,'seedBlocks',true);
end

function E = synthetic(d,n,plan)
% Gain 1: no success, no unsafe contact, aim 1 m. Gain 2 in a planned cell:
% extra(base,m,s) more successes (base < 0: that many fewer, from an all-success
% gain 1), and aim 1 + dE + 0.01 (m + s) / 10. Other cells: no change.
rows = {};
for m = 1:4
    for s = 1:5
        for c = 1:size(d.cells,1)
            name = [d.cells{c,1},d.cells{c,2}];
            p = [0 0 0]; if isfield(plan,name), p = plan.(name); end
            for e = 1:n
                base = struct('MethodId',string(d.methods{m}),'TrainSeed',420+s, ...
                    'Factor',string(d.cells{c,1}),'Shift',string(d.cells{c,2}),'EpisodeSeed',e, ...
                    'Unsafe',0,'Duration_s',10,'AccelerationExposure_s',0,'ClippedFraction',0, ...
                    'SaturatedFraction',0,'MeanAbsRequestedAx_mps2',0,'CommandRateRMS_mps3',0, ...
                    'FailureClass',"SUCCESS");
                g1 = base; g1.Gain = 1; g1.Success = double(p(1)<0); g1.AimErrorRMS_m = 1;
                g2 = base; g2.Gain = 2; g2.Success = g1.Success; g2.AimErrorRMS_m = 1;
                if any(p)
                    if p(1)>0 && e<=extra(p(1),m,s), g2.Success = 1; end
                    if p(1)<0 && e<=extra(-p(1),m,s), g2.Success = 0; end
                    g2.AimErrorRMS_m = 1+p(3)+0.01*(m+s)/10*sign(p(3));
                end
                rows(end+1:end+2) = {g1,g2};
            end
        end
    end
end
E = struct2table([rows{:}]);
end

function k = extra(base,m,s)
k = base+mod(m+s,3);
end

function tf = throws(f)
try
    f(); tf = false;
catch
    tf = true;
end
end
