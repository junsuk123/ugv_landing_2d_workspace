function [episodeConfig,scenarioHeightRange,progress] = trainingEpisodeConfig(c,iteration)
% TRAININGEPISODECONFIG  Pure-RL training curriculum for one PPO iteration.
%
% Only episode generation is modified. Validation and final evaluation keep
% the nominal configuration in C, so reported performance is never measured
% on an easier curriculum distribution.
rl = c.rl;
validateattributes(iteration,{'numeric'},{'scalar','integer','positive'});
episodeConfig = c;

heightScale = landing2d.rl.curriculumRange(rl,iteration);
scenarioHeightRange = sort(c.experiment.scenario.heightRange.*heightScale);

progress = struct('height',curriculumProgress(rl.curriculumFraction, ...
    rl.ppoIterations,iteration), ...
    'abort',curriculumProgress(rl.abortCurriculumFraction, ...
    rl.ppoIterations,iteration), ...
    'motion',curriculumProgress(rl.motionCurriculumFraction, ...
    rl.ppoIterations,iteration));

nominalLoss = c.experiment.safety.prolongedLoss;
startLoss = max(nominalLoss,rl.abortCurriculumStart);
episodeConfig.experiment.safety.prolongedLoss = ...
    startLoss+(nominalLoss-startLoss)*progress.abort;

motionScale = rl.motionCurriculumStartScale+ ...
    (1-rl.motionCurriculumStartScale)*progress.motion;
episodeConfig.experiment.scenario.v1Range = ...
    c.experiment.scenario.v1Range*motionScale;
episodeConfig.experiment.scenario.a2Range = ...
    c.experiment.scenario.a2Range*motionScale;
end

function value = curriculumProgress(fraction,totalIterations,iteration)
if fraction <= 0
    value = 1;
    return;
end
span = max(1,round(fraction*totalIterations));
value = min(max((iteration-1)/span,0),1);
end
