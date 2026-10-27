function [report,runs,results] = smokeTest(d)
% SMOKETEST Native contract, gradients, four PPO updates, and eight cells.
% Every output is TEST ONLY. This function does not create a registration.
if nargin<1, d=landing2d.current_semantics.config(); end
registeredSources=landing2d.current_semantics.sourceManifest(d.root);
landing2d.current_semantics.checkSeeds(d);
assert(strcmp(landing2d.rl.algorithmVersion(d.c),'current-semantics-v1'));
assert(d.c.rl.observationDim==10 && d.c.rl.actionDim==2);
assert(isequal(d.c.rl,d.baseline.rl),'The original PPO configuration must be unchanged.');
experiment=d.c.experiment; experiment.designVersion=d.baseline.experiment.designVersion;
assert(isequal(experiment,d.baseline.experiment),'Physical, sensor, reward, observation and training distributions must be unchanged.');
% Shared dispatch changes must preserve the archived algorithm paths as well.
% Some archived suites contain their own bounded TEST ONLY smoke checks.
residualRegression=landing2d.residual_context.selfTest();
minimalRegression=landing2d.minimal.selfTest();
legacyRegression=landing2d.orchestration.selfTest();
regressionPassed=residualRegression.passed && all(minimalRegression.Passed) && all(legacyRegression.Passed);
assert(regressionPassed,'landing2d:CurrentSemanticsRegression','An archived native regression failed.');
core=landing2d.current_semantics.selfTest(d.c.graphState);
assert(core.passed,'landing2d:CurrentSemanticsCore','The native encoder checks failed.');
arms=landing2d.config.comparisonArms(d.c,struct('methods',{d.methods},'trainSeed',d.smokeTrainSeed));
counts=zeros(1,4); agents=cell(1,4);
for k=1:4
    agents{k}=landing2d.rl.initialAgent(arms(k).config);
    counts(k)=landing2d.current_semantics.parameterCount(agents{k});
    assert(isequal(agents{k}.value.net,agents{1}.value.net),'All methods must have the same initialized raw critic.');
end
assert(isequal(counts,[2095,2095,2094,2100]),'landing2d:CurrentSemanticsParameters','Actual parameter counts changed.');
old=landing2d.rl.initialAgent(landing2d.config.applyMethod(d.baseline,'ppo',d.smokeTrainSeed));
assert(isequal(agents{1}.policy.mean,old.policy.mean) ...
    && isequal(agents{1}.policy.logStd,old.policy.logStd) ...
    && isequal(agents{1}.value.net,old.value.net),'The Raw-PPO initial function must equal the original PPO.');
% Check equal external draws across all methods in each evaluation cell.
for factor=d.c.evaluation.generalization.conditions
    for shift={'ID','OOD'}
        expected='';
        for k=1:4
            [cfg,scale]=landing2d.current_semantics.condition(arms(k).config,factor{1},shift{1});
            env=landing2d.environment.reset(cfg,d.smokeEnvironmentSeed,struct('sensorNoiseScale',scale));
            manifest=landing2d.environment.exogenousManifest(env);
            if k==1, expected=manifest.hash; else, assert(strcmp(expected,manifest.hash)); end
        end
    end
end
checkSummary(d);
[inputs,~]=landing2d.current_semantics.diagnosticInputs(d.c);
assert(isequal(size(inputs),[10,96]));
temporary=tempname; mkdir(temporary);
cleanup=onCleanup(@()removeTemporary(temporary)); %#ok<NASGU>
smoke=d; smoke.c=landing2d.orchestration.smokeConfig(d.c);
smoke.c.outputDir=temporary;
runs=landing2d.orchestration.trainRuns(smoke.c,struct('trainSeeds',d.smokeTrainSeed, ...
    'methods',{d.methods},'smoke',true,'concurrentRuns',1,'liveTraining',false));
assert(numel(runs)==4);
for k=1:4
    assert(~isempty(runs(k).history) && all(arrayfun(@(h)isfinite(h.score),runs(k).history)));
end
results=landing2d.current_semantics.evaluate(runs,smoke,'development',true);
assert(height(results.generalizationEpisodes)==32 && results.isSmoke);
diagnostics=landing2d.current_semantics.semanticDiagnostics(runs,smoke);
assert(height(diagnostics.matchedActions)==4*96);
% Roundtrip the already-trained smoke model, without a fifth training run.
agent=runs(4).agent; info=struct('history',runs(4).history);
signature=landing2d.rl.trainingSignature(runs(4).config); %#ok<NASGU>
file=fullfile(temporary,'roundtrip.mat'); save(file,'agent','info','signature');
loaded=load(file);
assert(isequaln(agent,loaded.agent) && landing2d.rl.signatureMatches(loaded.signature,runs(4).config));
landing2d.rl.verifyCheckpointGraph(loaded.agent,runs(4).config);
[first,trace1]=landing2d.rl.rolloutEpisodeV2(agent,runs(4).config,d.smokeEnvironmentSeed,struct('deterministic',true));
[second,trace2]=landing2d.rl.rolloutEpisodeV2(loaded.agent,runs(4).config,d.smokeEnvironmentSeed,struct('deterministic',true));
assert(isequaln(first,second) && isequaln(trace1,trace2),'Saved and restored policy replay differs.');
landing2d.current_semantics.verifySources(d.root,registeredSources);
report=struct('testOnly',true,'passed',true,'smokePassed',true,'core',core, ...
    'parameterCounts',counts,'rawPpoInitializationPreserved',true,'commonRawCritic',true, ...
    'externalConditionsPaired',true,'summaryPairsChecked',true,'models',4, ...
    'updatesPerModel',1,'evaluationEpisodes',32,'saveRestoreReplay',true, ...
    'performanceEvidence',false,'matlab',string(version), ...
    'nativeRegressionPassed',regressionPassed, ...
    'nativeRegressions',struct('residualV5',residualRegression, ...
        'minimal',minimalRegression,'legacy',legacyRegression), ...
    'legacySuitesContainTheirOwnSmoke',true, ...
    'nativeRegressionPending','Archived seven-node trace requires historical checkpoints and is not run by this suite.', ...
    'configurationSha256',landing2d.util.sha256(jsonencode(d.c)),'sources',registeredSources);
disp(report);
end

function checkSummary(d)
rows={};
for method=1:4
    for seed=1:2
        for factor=d.c.evaluation.generalization.conditions
            for shift={'ID','OOD'}
                for episode=1:2
                    success=double(method==4 || seed==2);
                    rows{end+1}=struct('Factor',string(factor{1}),'Shift',string(shift{1}), ...
                        'MethodId',string(d.methods{method}),'Method',string(d.methods{method}), ...
                        'TrainSeed',seed,'EpisodeSeed',episode,'Success',success, ...
                        'Unsafe',0,'Timeout',1-success,'AimErrorRMS_m',.2, ...
                        'CommandRateRMS_mps3',.1,'Duration_s',1,'ExogenousDropout_s',0, ...
                        'ApproachViewLoss_s',0,'TerminalReason',"SYNTHETIC_TEST_ONLY", ...
                        'FailureClass',"SYNTHETIC_TEST_ONLY"); %#ok<AGROW>
                end
            end
        end
    end
end
T=struct2table([rows{:}]); S=landing2d.current_semantics.summarize(T,d);
assert(height(S.primaryBySeed)==8 && height(S.primaryContrasts)==2 ...
    && all(S.primaryContrasts.Seeds==2) && all(abs(S.primaryContrasts.Delta_OODSuccess-.5)<1e-12));
[~,lower,upper]=landing2d.current_semantics.pairedInterval([1;0],.975);
assert(all(abs(S.primaryContrasts.PrimaryLower-lower)<1e-12) ...
    && all(abs(S.primaryContrasts.PrimaryUpper-upper)<1e-12));
rejected=false;
try
    landing2d.current_semantics.summarize(T(2:end,:),d);
catch err
    rejected=strcmp(err.identifier,'landing2d:CurrentSemanticsPairs');
end
assert(rejected,'Missing paired episodes must be rejected.');
% Fixed-sequence interpretation: a Raw-PPO gain alone cannot complete the goal,
% and primary gains with a Raw-PPO regression cannot complete it either.
testDesign=d; testDesign.confirmationSeeds=1:2;
testRuns=struct('id',{},'trainSeed',{},'history',{});
for method=1:4
    for seed=1:2
        h=struct('selected',true,'landingRate',.9,'unsafeRate',0);
        testRuns(end+1)=struct('id',d.methods{method},'trainSeed',seed,'history',h); %#ok<AGROW>
    end
end
S.isSmoke=false;
S.guardContrasts.Lower(S.guardContrasts.Metric=="IDSuccess")=0;
S.primaryContrasts.PrimaryLower(:)=.01;
S.ppoContrasts.PracticalLower=-.01;
decision=landing2d.current_semantics.gate(testRuns,S,testDesign,'confirmation');
assert(decision.practicalSuccessEligible && ~decision.practicalSuccessPassed && ~decision.goalComplete);
S.ppoContrasts.PracticalLower=.01;
S.primaryContrasts.PrimaryLower(1)=-.01;
decision=landing2d.current_semantics.gate(testRuns,S,testDesign,'confirmation');
assert(~decision.practicalSuccessEligible && ~decision.goalComplete);
S.primaryContrasts.PrimaryLower(:)=.01;
decision=landing2d.current_semantics.gate(testRuns,S,testDesign,'confirmation');
assert(decision.practicalSuccessPassed && decision.goalComplete);
end

function removeTemporary(folder)
if isfolder(folder), rmdir(folder,'s'); end
end
