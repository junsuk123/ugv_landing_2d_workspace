function report = run_activate_rgat_checkpoint(options)
% RUN_ACTIVATE_RGAT_CHECKPOINT  Activate the typed relation residual while
% preserving the selected checkpoint through validation-only calibration.
if nargin<1, options=struct(); end
projectRoot=setup_project();
c=landing2d.config.primaryConfig(projectRoot);
c=landing2d.graphstate.applyStateRepresentation(c,'context_rgat');
c.rl.policyFile='ppo_context_rgat_planar_visibility_v2.mat';
file=fullfile(c.outputDir,c.rl.policyFile);
saved=load(file);
assert(isfield(saved,'agent') && isfield(saved,'info') ...
    && isfield(saved,'signature'),'landing2d:InvalidCheckpoint', ...
    'Checkpoint must contain agent, info, and signature.');
assert(isequal(saved.signature,landing2d.rl.trainingSignature(c)), ...
    'landing2d:CheckpointMismatch', ...
    'Checkpoint signature does not match the current experiment.');
anchor=landing2d.rl.normalizeAgent(saved.agent,c.rl);
testSeeds=c.experiment.manifest.testSeeds(1:c.experiment.testEpisodeCount);
[~,~,testBefore]=landing2d.rl.evaluateV2(anchor,c,testSeeds);
[agent,activation]=landing2d.rl.ensureRelationalPath(anchor,c,options);
assert(activation.accepted,'landing2d:RelationActivationRejected', ...
    'No active relational candidate passed the validation performance guard.');
[~,~,testAfter]=landing2d.rl.evaluateV2(agent,c,testSeeds);

backup=[file(1:end-4) '.pre_relation_activation.mat'];
if ~isfile(backup), copyfile(file,backup); end
info=saved.info;
info.relationActivation=activation;
signature=saved.signature; %#ok<NASGU>
save(file,'agent','info','signature');
writetable(activation.guard.guardTable,fullfile(c.outputDir, ...
    'rgat_relation_activation_guard.csv'));
report=struct('checkpoint',file,'backup',backup,'activation',activation, ...
    'testBefore',testBefore,'testAfter',testAfter);
save(fullfile(c.outputDir,'rgat_relation_activation_report.mat'),'report');
disp(comparisonTable(testBefore,testAfter));
fprintf('관계 경로 활성화 체크포인트 저장: %s\n',file);
fprintf('기존 체크포인트 백업: %s\n',backup);
end

function t=comparisonTable(before,after)
Metric=["LandingRate";"UnsafeRate";"SafeAbortRate";"TimeoutRate"; ...
    "MeanReturn";"SelectionScore";"HorizontalResidual";"VerticalResidual"];
Before=[before.landingRate;before.unsafeRate;before.safeAbortRate; ...
    before.timeoutRate;before.meanReturn;before.selectionScore; ...
    before.meanAbsRelationResidual(:)];
After=[after.landingRate;after.unsafeRate;after.safeAbortRate; ...
    after.timeoutRate;after.meanReturn;after.selectionScore; ...
    after.meanAbsRelationResidual(:)];
t=table(Metric,Before,After,After-Before,'VariableNames', ...
    {'Metric','Before','After','Delta'});
end
