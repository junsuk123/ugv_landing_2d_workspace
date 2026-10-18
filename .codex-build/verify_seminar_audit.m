function verify_seminar_audit()
addpath('src/orchestration','src/simulations','src/algorithms');
a=load('results/seminar_mechanism_audit/mechanism_audit.mat'); out=a.out;
assert(height(out.noiseSummary)==24 && height(out.episodes)==444);
assert(all(out.gradientChecks.Passed) && height(out.gradientChecks)==16);
assert(all(out.updateChecks.DeltaNorm>0));
assert(all(cellfun(@(q)q.verified && q.pairedAcrossMethods,out.contracts(:))));
assert(all(out.episodes.SupervisorInterventions==0));
z=out.noiseSummary.NoiseScale==0;
assert(all(out.noiseSummary.SpatialNormalVariance_m2(z)==0));
assert(all(out.noiseSummary.TerminalSpatialNormalVariance_m2(z)==0));
for j=1:numel(out.identities)
    file=out.identities{j}.CheckpointFile;
    fid=fopen(file,'r'); bytes=fread(fid,'*uint8'); fclose(fid);
    assert(strcmp(landing2d.util.sha256(bytes),out.identities{j}.CheckpointHash));
end
lint=checkcode('src/orchestration/+landing2d/+paper/seminarMechanismAudit.m','-id');
assert(isempty(lint));
lint=checkcode('src/orchestration/+landing2d/+paper/seminarCaseDiagnostics.m','-id');
assert(isempty(lint));
lint=checkcode('src/orchestration/+landing2d/+paper/seminarCheckpointHistory.m','-id');
assert(isempty(lint));
c=landing2d.config.primaryConfig(pwd);
h=landing2d.paper.seminarCheckpointHistory(landing2d.config.applyMethod(c,'onto_rgat_ppo',1),out.options.outputDir);
assert(all(h.snapshotChanges.DeltaNorm>0) && h.encoderBlendMaxAbsError<1e-12);
report=landing2d.paper.seminarCaseDiagnostics(out);
assert(height(report.cases)==6 && height(report.physical)==3);
fprintf('Mechanism audit regression: PASS (444 episodes, pairing, gradients, hashes, no supervisor, lint).\n');
pipeline=run(struct('executionMode','smoke','generatePaper',false, ...
    'figureVisible',false,'saveResults',false,'showLiveDashboard',false));
assert(all(pipeline.tests.Passed));
scenario=run_scenario('S1',struct('figureVisible',false,'saveResults',false,'profileRepetitions',2));
assert(all(scenario.study.metricTable.TerminalReason=="SUCCESS"));
for j=1:numel(out.identities)
    fid=fopen(out.identities{j}.CheckpointFile,'r'); bytes=fread(fid,'*uint8'); fclose(fid);
    assert(strcmp(landing2d.util.sha256(bytes),out.identities{j}.CheckpointHash));
end
fprintf('SEMINAR_FINAL_VERIFICATION_PASS\n');
end
