function out = v215DevelopmentGate(c)
% V215DEVELOPMENTGATE Registered validation gate; never trains or uses test data.
% Run after the user trains v2.15 with run.m. Exact current signatures only;
% learning scores are recomputed from those checkpoints, not stale CSV files.
% G2-G5 retain v2.14 thresholds. G6 additionally requires corrective vertical
% response in >=4/5 seeds per graph arm and >=50% of its v2.14 mean authority.
% G6 prevents calling a nearly constant vertical command a noise improvement.
if nargin<1, c=landing2d.config.primaryConfig(landing2d.orchestration.projectRoot()); end
assert(strcmp(landing2d.rl.algorithmVersion(),'relational-policy-v2.15'));
assert(strcmp(c.graphState.observationFeatures,'tosm7_v5'));
registry=landing2d.config.methodRegistry(); seeds=registry.trainSeeds.v215Dev;
runs=landing2d.orchestration.loadRuns(c,struct('trainSeeds',seeds));
L=landing2d.evaluation.learningEfficiency(runs,c);
referenceFile=fullfile(c.outputDir,'review_2026-10-24','v214_vertical_probe.csv');
assert(isfile(referenceFile),'landing2d:GateReference','Missing frozen v2.14 reference: %s',referenceFile);
fid=fopen(referenceFile,'rb'); cleanup=onCleanup(@()fclose(fid));
referenceHash=landing2d.util.sha256(fread(fid,Inf,'*uint8')); clear cleanup;
assert(strcmp(referenceHash,'826c7b350c3a55786b20245599ddf3905d4691fd447762eb4dfcce76639f0dff'), ...
    'landing2d:GateReference','The frozen v2.14 vertical reference has changed.');
reference=readtable(referenceFile,'TextType','string');
D=landing2d.evaluation.verticalResponseProbe(runs,c);
graphArms=["onto_rgat_ppo","shuffled_rgat_ppo"];
noiseReference=[0.020898,0.018859]; rows=cell(1,2);
for m=1:2
    id=graphArms(m); p=D.runs(D.runs.MethodId==id,:);
    ref=reference(reference.MethodId==id,:);
    learning=L.runs(L.runs.MethodId==id,:);
    assert(isequal(sort(p.TrainSeed)',seeds) && isequal(sort(ref.TrainSeed)',seeds));
    authorityReference=mean(ref.VerticalSensitivity);
    assert(authorityReference>0,'landing2d:GateReference','v2.14 authority reference must be positive.');
    rows{m}=table(id,sum(learning.Reached80),sum(p.SignCorrect),mean(p.NoiseActionVar), ...
        mean(p.NoiseActionVar)/noiseReference(m),sum(p.VerticalSignCorrect), ...
        mean(p.VerticalSensitivity),authorityReference,mean(p.VerticalSensitivity)/authorityReference, ...
        'VariableNames',{'MethodId','Reached80','SignCorrect','NoiseActionVar', ...
        'NoiseRatioToV212','VerticalSignCorrect','VerticalSensitivity', ...
        'VerticalSensitivityV214','VerticalAuthorityRatio'});
end
arms=vertcat(rows{:});
auc=@(id)arrayfun(@(s)L.runs.AUC(L.runs.MethodId==id & L.runs.TrainSeed==s),seeds);
difference=auc(graphArms(1))-auc(graphArms(2));
G2=all(arms.Reached80>=4); G3=all(arms.SignCorrect>=4);
G4=all(arms.NoiseRatioToV212<=0.5); G5=mean(difference)>0 && sum(difference>0)>=4;
G6=all(arms.VerticalSignCorrect>=4 & arms.VerticalAuthorityRatio>=0.5);
verdict=table(G2,G3,G4,G5,G6,G2&&G3&&G4&&G6,G2&&G3&&G4&&G5&&G6, ...
    mean(difference),sum(difference>0),'VariableNames', ...
    {'G2_Learnability','G3_SignCorrect','G4_Noise','G5_RelationAUC', ...
    'G6_VerticalAuthority','BehaviorFixed','Passed','AUCDifferenceMean','AUCDifferencePositive'});
folder=fullfile(c.outputDir,'evaluation'); if ~isfolder(folder), mkdir(folder); end
writetable(D.runs,fullfile(folder,'v215_dev_probe_runs.csv'));
writetable(L.runs,fullfile(folder,'v215_dev_learning_runs.csv'));
writetable(arms,fullfile(folder,'v215_dev_gate_arms.csv'));
writetable(verdict,fullfile(folder,'v215_dev_gate.csv'));
out=struct('runs',runs,'probes',D,'learning',L,'arms',arms,'verdict',verdict);
disp(arms); disp(verdict);
end
