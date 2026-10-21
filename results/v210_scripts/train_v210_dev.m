% Pre-registered v2.10 development gate (docs/RGAT_V2_DESIGN_KO.md section 17.2).
root = 'C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_d4';
for name = {'orchestration','simulations','algorithms'}, addpath(fullfile(root,'src',name{1})); end
cfg = landing2d.config.primaryConfig(root);
cfg.rl.parallelEpisodes = false;
registry = landing2d.config.methodRegistry();
seeds = registry.trainSeeds.v210Dev;
methods = {'onto_rgat_ppo','shuffled_rgat_ppo'};
assert(isequal(seeds,161:164) && strcmp(registry.version,'comparison_registry_v16'));
assert(strcmp(landing2d.rl.algorithmVersion(),'relational-policy-v2.10'));
fprintf('algorithm %s | development gate seeds %s\n', ...
    landing2d.rl.algorithmVersion(),mat2str(seeds));
started = tic;
runs = landing2d.orchestration.trainRuns(cfg,struct('methods',{methods}, ...
    'trainSeeds',seeds,'concurrentRuns',8,'concurrentPool','threads'));
learning = landing2d.evaluation.learningEfficiency(runs,cfg);
out = fullfile(root,'results','evaluation');
if ~exist(out,'dir'), mkdir(out); end
writetable(learning.runs,fullfile(out,'v210_dev_learning_runs.csv'));
T = learning.runs;
onto = sortrows(T(T.MethodId=="onto_rgat_ppo",:),'TrainSeed');
shuffled = sortrows(T(T.MethodId=="shuffled_rgat_ppo",:),'TrainSeed');
assert(isequal(onto.TrainSeed,shuffled.TrainSeed));
delta = onto.AUC-shuffled.AUC;
gate = table(sum(onto.Reached80),sum(shuffled.Reached80),mean(delta),sum(delta>0), ...
    sum(onto.Reached80)>=3 && sum(shuffled.Reached80)>=3 && mean(delta)>0 && sum(delta>0)>=3, ...
    'VariableNames',{'TosmReached80','ShuffledReached80','MeanAucDelta', ...
    'PositiveAucSeeds','Passed'});
disp(onto(:,{'TrainSeed','Reached80','AUC','BestValidationSuccess'}));
disp(shuffled(:,{'TrainSeed','Reached80','AUC','BestValidationSuccess'}));
disp(gate);
writetable(gate,fullfile(out,'v210_dev_gate.csv'));
fprintf('DEVELOPMENT DONE in %.1f min | gate passed = %d\n',toc(started)/60,gate.Passed);
