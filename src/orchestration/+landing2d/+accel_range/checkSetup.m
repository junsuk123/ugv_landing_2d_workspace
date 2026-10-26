function [report,smoke] = checkSetup(d)
% CHECKSETUP Pre-training checks of acceleration_range_r1_v1 (TEST ONLY; no performance evidence).
%   1 configurations opening 9101-9200 are rejected
%   2 the configuration differs from v5 only in the training a2Range, the
%     registered validationScenario (= the v5 scenario) and the output folder
%   3 training signatures differ from v5 (no checkpoint reuse); no new checkpoint exists
%   4 initial agents equal the v5 initial agents (four methods x five seeds)
%   5 training scenarios reach the new range (a2 in [0.3,1.4], some > 0.8)
%   6 four-method 1-update smoke: the initial validation row equals the v5
%     smoke's row (validation stays on the v5 family end to end)
%   7 the evaluation cells of a new run equal the v5 cells (six cells)
%   8 v5 checkpoints flown through the new-run evaluation path reproduce the
%     stored protocol-v2 episodes (environment 9001, six cells, four methods)
%   9 analysis and figure on tables derived from the stored v5 episodes: the
%     four verdict branches (no change, motion gain, gain with noise harm,
%     learning failure) and the df = 4 interval
% SMOKE returns the two smoke runs (new, v5) for regression comparisons.
if nargin<1, d = landing2d.accel_range.config(); end
report = struct();
bad = d; bad.environmentSeeds = 9101:9200;
report.confirmationClosed = throws(@()landing2d.accel_range.checkSeeds(bad));
assert(report.confirmationClosed);

x = d.c; x.experiment = rmfield(x.experiment,'validationScenario');
x.experiment.scenario.a2Range = d.v5.experiment.scenario.a2Range; x.outputDir = d.v5.outputDir;
assert(isequal(x,d.v5),'Only a2Range, validationScenario and outputDir may differ from v5.');
assert(isequal(d.c.experiment.validationScenario,d.v5.experiment.scenario));
assert(isequal(d.c.experiment.scenario.a2Range,[0.3,1.4]) && isequal(d.v5.experiment.scenario.a2Range,[0.3,0.8]));
report.onlyIndependentVariableDiffers = true;

newArms = []; v5Arms = [];
for s = d.trainSeeds
    newArms = [newArms,landing2d.config.comparisonArms(d.c,struct('methods',{d.methods},'trainSeed',s))]; %#ok<AGROW>
    v5Arms = [v5Arms,landing2d.config.comparisonArms(d.v5,struct('methods',{d.methods},'trainSeed',s))]; %#ok<AGROW>
end
assert(numel(newArms)==20 && isequal({newArms.id},{v5Arms.id}) && isequal([newArms.trainSeed],[v5Arms.trainSeed]));
for j = 1:numel(newArms)
    assert(~landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(v5Arms(j).config),newArms(j).config), ...
        'A v5 checkpoint must never match the new configuration.');
    assert(~isfile(fullfile(d.c.outputDir,newArms(j).config.rl.policyFile)), ...
        'A new checkpoint already exists: %s.',newArms(j).config.rl.policyFile);
    assert(isequaln(landing2d.rl.initialAgent(newArms(j).config),landing2d.rl.initialAgent(v5Arms(j).config)), ...
        'Initial agents must equal v5 (%s seed %d).',newArms(j).id,newArms(j).trainSeed);
end
report.signaturesDiffer = true; report.noCheckpointYet = true; report.initialAgentsEqual = numel(newArms);

a2 = zeros(1,2000); motion = false(1,2000);
for k = 1:2000
    p = landing2d.scenario.sampleParameters(d.c.experiment.scenario,100000+k);
    a2(k) = p.a2; motion(k) = p.a2>0;
end
assert(all(a2(motion)>=0.3 & a2(motion)<=1.4) && any(a2(motion)>0.8));
report.trainingA2Max = max(a2(motion)); report.trainingShareAbove08 = mean(a2(motion)>0.8);

smokeNew = landing2d.orchestration.smokeConfig(d.c); smokeV5 = landing2d.orchestration.smokeConfig(d.v5);
options = struct('trainSeeds',d.trainSeeds(1),'methods',{d.methods},'smoke',true,'concurrentRuns',1,'liveTraining',false);
runsNew = landing2d.orchestration.trainRuns(smokeNew,options);
runsV5 = landing2d.orchestration.trainRuns(smokeV5,options);
for j = 1:numel(runsNew)
    a = rmfield(runsNew(j).history(1),'wallSeconds'); b = rmfield(runsV5(j).history(1),'wallSeconds');
    assert(isequaln(a,b),'The initial validation must equal v5 (%s).',runsNew(j).id);
end
report.initialValidationEqual = numel(runsNew);
report.smokeTrainingReturnDiffers = arrayfun(@(a,b)a.history(end).trainReturn~=b.history(end).trainReturn,runsNew,runsV5);
smoke = struct('new',runsNew,'v5',runsV5);

shells = struct('id',{newArms.id},'trainSeed',num2cell([newArms.trainSeed]),'config',{newArms.config});
shells = landing2d.accel_range.evaluationRuns(shells,d);
for j = 1:numel(shells)
    for c = 1:size(d.cells,1)
        b1 = shells(j).config; b1.evaluation = d.v5.evaluation;
        b2 = v5Arms(j).config; b2.evaluation = d.v5.evaluation;
        [e1,s1] = landing2d.minimal.generalizationCondition(b1,d.cells{c,1},d.cells{c,2});
        [e2,s2] = landing2d.minimal.generalizationCondition(b2,d.cells{c,1},d.cells{c,2});
        assert(isequal(e1.experiment,e2.experiment) && s1==s2,'Evaluation cell differs from v5.');
    end
end
report.evaluationCellsEqual = numel(shells)*size(d.cells,1);

base = landing2d.bias_diagnostics.config(d.root);
v5Runs = landing2d.bias_diagnostics.models(base,d.trainSeeds(1));
for j = 1:numel(v5Runs)
    arm = newArms([newArms.trainSeed]==v5Runs(j).trainSeed & strcmp({newArms.id},v5Runs(j).id));
    v5Runs(j).config = arm.config;                        % new-run configuration, v5 policy
end
v5Runs = landing2d.accel_range.evaluationRuns(v5Runs,d);
one = d.v5; one.evaluation.generalization.episodes = 1;
out = landing2d.minimal.generalization(v5Runs,one);
report.storedV5Reproduced = compareStored(out.generalizationEpisodes,d);
report.analysisBranches = analysisChecks(d);
end

function n = analysisChecks(d)
v5 = readtable(fullfile(d.v5Evaluation,'generalizationEpisodes.csv'),'TextType','string');
learning = table(string(d.methods(:)),5*ones(4,1),5*ones(4,1),ones(4,1),zeros(4,1), ...
    'VariableNames',{'MethodId','Reached80','Selected80','ValidationMedian','UnsafeMedian'});
A = landing2d.accel_range.analyze(v5,v5,learning,d);
assert(A.verdict=="insufficient_evidence_of_improvement" && all(A.cells.dS_mean==0) && A.flags.N);
gain = v5; motion = gain.Factor=="motion" & gain.Shift=="OOD";
gain.Success(motion) = 1;
A = landing2d.accel_range.analyze(gain,v5,learning,d);
block = A.bySeed(A.bySeed.Factor=="motion" & A.bySeed.Shift=="OOD",:);
row = A.cells(A.cells.Factor=="motion" & A.cells.Shift=="OOD",:);
assert(abs((row.dS_high-row.dS_mean)-2.7764451051977987*std(block.dS)/sqrt(5))<=1e-9);
assert(A.flags.G && ~A.flags.H && A.verdict==string(ifelse(A.flags.N, ...
    "improved_within_registered_margins","gain_with_unresolved_risk")));
harm = gain; harm.Unsafe(harm.Factor=="noise" & harm.Shift=="OOD") = 1;
A = landing2d.accel_range.analyze(harm,v5,learning,d);
assert(A.verdict=="trade_off_supported" && A.flags.H);
folder = fullfile(tempdir,'accel_range_check'); if ~isfolder(folder), mkdir(folder); end
landing2d.accel_range.plots(A,d,folder);
learning.Reached80(3) = 4;
A = landing2d.accel_range.analyze(harm,v5,learning,d);
assert(A.verdict=="training_failure" && ~A.flags.L);
n = 4;
end

function n = compareStored(E,d)
stored = readtable(fullfile(d.v5Evaluation,'generalizationEpisodes.csv'),'TextType','string');
n = 0;
for i = 1:height(E)
    s = stored(stored.MethodId==string(E.MethodId(i)) & stored.TrainSeed==E.TrainSeed(i) ...
        & stored.Factor==string(E.Factor(i)) & stored.Shift==string(E.Shift(i)) ...
        & stored.EpisodeSeed==E.EpisodeSeed(i),:);
    assert(height(s)==1 && s.Success==E.Success(i) && s.Unsafe==E.Unsafe(i) ...
        && s.TerminalReason==string(E.TerminalReason(i)) ...
        && abs(s.AimErrorRMS_m-E.AimErrorRMS_m(i))<=1e-9*max(1,abs(s.AimErrorRMS_m)), ...
        'landing2d:AccelRangeReproduction','v5 episode not reproduced: %s seed %d %s %s.', ...
        E.MethodId(i),E.TrainSeed(i),E.Factor(i),E.Shift(i));
    n = n+1;
end
end

function v = ifelse(condition,a,b)
if condition, v = a; else, v = b; end
end

function tf = throws(f)
try
    f(); tf = false;
catch
    tf = true;
end
end
