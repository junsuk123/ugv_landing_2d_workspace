function tests=test_training_curriculum_v2
tests=functiontests(localfunctions);
end

function testScratchScheduleAndCurriculum(testCase)
root=fileparts(fileparts(mfilename('fullpath')));
c=landing2d.config.primaryConfig(root);
verifyEqual(testCase,c.rl.ppoIterations,2500);
verifyFalse(testCase,c.rl.useImitationLearning);

[early,hEarly,pEarly]=landing2d.rl.trainingEpisodeConfig(c,1);
[late,hLate,pLate]=landing2d.rl.trainingEpisodeConfig(c,c.rl.ppoIterations);

verifyEqual(testCase,pEarly.height,0,'AbsTol',eps);
verifyEqual(testCase,pEarly.abort,0,'AbsTol',eps);
verifyEqual(testCase,pEarly.motion,0,'AbsTol',eps);
verifyEqual(testCase,early.experiment.safety.prolongedLoss, ...
    c.rl.abortCurriculumStart,'AbsTol',1e-12);
verifyEqual(testCase,early.experiment.scenario.v1Range, ...
    c.experiment.scenario.v1Range*c.rl.motionCurriculumStartScale, ...
    'AbsTol',1e-12);
verifyEqual(testCase,early.experiment.scenario.a2Range, ...
    c.experiment.scenario.a2Range*c.rl.motionCurriculumStartScale, ...
    'AbsTol',1e-12);
verifyLessThan(testCase,max(hEarly),max(c.experiment.scenario.heightRange));

verifyEqual(testCase,pLate.height,1,'AbsTol',eps);
verifyEqual(testCase,pLate.abort,1,'AbsTol',eps);
verifyEqual(testCase,pLate.motion,1,'AbsTol',eps);
verifyEqual(testCase,late.experiment.safety.prolongedLoss, ...
    c.experiment.safety.prolongedLoss,'AbsTol',1e-12);
verifyEqual(testCase,late.experiment.scenario.v1Range, ...
    c.experiment.scenario.v1Range,'AbsTol',1e-12);
verifyEqual(testCase,late.experiment.scenario.a2Range, ...
    c.experiment.scenario.a2Range,'AbsTol',1e-12);
verifyEqual(testCase,hLate,c.experiment.scenario.heightRange,'AbsTol',1e-12);

% Curriculum construction must not mutate nominal evaluation settings.
verifyEqual(testCase,c.experiment.safety.prolongedLoss,3.0,'AbsTol',1e-12);
end
