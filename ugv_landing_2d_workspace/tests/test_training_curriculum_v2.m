function test_training_curriculum_v2()
% TEST_TRAINING_CURRICULUM_V2  Executed directly by run_tests.
root=fileparts(fileparts(mfilename('fullpath')));
c=landing2d.config.primaryConfig(root);
assert(c.rl.ppoIterations==2500);
assert(~c.rl.useBehaviorClone);
assert(strcmp(c.rl.curriculumMode,'performance'));
assert(c.axMax>c.experiment.scenario.a2Range(2));
assert(c.graphState.graphAdaptationWarmupFraction==0.90);
assert(c.graphState.preserveRawPolicyDuringGraphAdaptation);
assert(c.graphState.graphSelectionMargin>0);

warm=max(1,round(c.rl.curriculumFloorStartFraction*c.rl.ppoIterations));
full=round(c.rl.curriculumFullDifficultyFraction*c.rl.ppoIterations);
assert(landing2d.rl.curriculumFloor(c.rl,warm)==0);
middle=landing2d.rl.curriculumFloor(c.rl,round((warm+full)/2));
assert(middle>0 && middle<1);
assert(landing2d.rl.curriculumFloor(c.rl,full)==1);
assert(~landing2d.rl.checkpointEligible(c.rl,0.99));
assert(landing2d.rl.checkpointEligible(c.rl,1));
levels=landing2d.rl.curriculumBatchLevels(c.rl,1,c.rl.episodesPerIteration);
assert(levels(1)==0 && levels(2)==0.5);
assert(all(levels(3:end)==1));

[early,hEarly,pEarly]=landing2d.rl.trainingEpisodeConfig(c,1,0);
[late,hLate,pLate]=landing2d.rl.trainingEpisodeConfig(c,c.rl.ppoIterations,1);
assert(all(abs([pEarly.height,pEarly.abort,pEarly.motion])<eps));
assert(all(abs([pLate.height,pLate.abort,pLate.motion]-1)<eps));
assert(max(abs(hEarly-[0.1,0.4]))<1e-12);
assert(max(abs(hLate-c.experiment.scenario.heightRange))<1e-12);
assert(abs(early.experiment.safety.prolongedLoss- ...
    c.rl.abortCurriculumStart)<1e-12);
assert(abs(early.experiment.safety.touchdownSpeedZ- ...
    c.experiment.safety.touchdownSpeedZ*c.rl.touchdownSpeedCurriculumScale)<1e-12);
assert(max(abs(early.experiment.scenario.v1Range- ...
    c.experiment.scenario.v1Range*c.rl.motionCurriculumStartScale))<1e-12);
assert(max(abs(early.experiment.scenario.T1Range- ...
    c.rl.curriculumStartT1Range))<1e-12);
assert(abs(late.experiment.safety.prolongedLoss- ...
    c.experiment.safety.prolongedLoss)<1e-12);
assert(abs(late.experiment.safety.touchdownSpeedZ- ...
    c.experiment.safety.touchdownSpeedZ)<1e-12);
assert(max(abs(late.experiment.scenario.v1Range- ...
    c.experiment.scenario.v1Range))<1e-12);
assert(max(abs(late.experiment.scenario.T1Range- ...
    c.experiment.scenario.T1Range))<1e-12);
assert(early.experiment.reward.UNSAFE_CONTACT== ...
    c.rl.unsafePenaltyCurriculumStart);
assert(late.experiment.reward.UNSAFE_CONTACT== ...
    c.experiment.reward.UNSAFE_CONTACT);

level=0; streak=0;
[level,streak]=landing2d.rl.advanceCurriculumLevel(c.rl,level, ...
    c.rl.curriculumLandingThreshold-1e-3,streak);
assert(level==0 && streak==0);
for i=1:c.rl.curriculumRequiredWindows
    [level,streak]=landing2d.rl.advanceCurriculumLevel(c.rl,level, ...
        c.rl.curriculumLandingThreshold,streak);
end
assert(abs(level-c.rl.curriculumStep)<1e-12 && streak==0);

% Nominal evaluation configuration is never mutated by curriculum creation.
assert(abs(c.experiment.safety.prolongedLoss-3.0)<1e-12);
assert(max(abs(c.experiment.scenario.heightRange-[4,8]))<1e-12);
end
