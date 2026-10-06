function [episodeConfig,scenarioHeightRange,progress] = trainingEpisodeConfig(c,iteration,curriculumLevel)
% TRAININGEPISODECONFIG  Pure-RL training curriculum for one PPO iteration.
%
% Only episode generation is modified. Validation and final evaluation keep
% the nominal configuration in C, so reported performance is never measured
% on an easier curriculum distribution.
rl = c.rl;
validateattributes(iteration,{'numeric'},{'scalar','integer','positive'});
episodeConfig = c;

if nargin >= 3 && isfinite(curriculumLevel)
    level = min(max(curriculumLevel,0),1);
    progress = struct('height',level,'abort',level,'motion',level);
    startScale = [rl.initialHeightRange(1),rl.curriculumStartHeight];
    heightScale = startScale+(1-startScale)*level;
else
    heightScale = landing2d.rl.curriculumRange(rl,iteration);
    progress = struct('height',curriculumProgress(rl.curriculumFraction, ...
        rl.ppoIterations,iteration), ...
        'abort',curriculumProgress(rl.abortCurriculumFraction, ...
        rl.ppoIterations,iteration), ...
        'motion',curriculumProgress(rl.motionCurriculumFraction, ...
        rl.ppoIterations,iteration));
end
scenarioHeightRange = sort(c.experiment.scenario.heightRange.*heightScale);

nominalLoss = c.experiment.safety.prolongedLoss;
startLoss = max(nominalLoss,rl.abortCurriculumStart);
episodeConfig.experiment.safety.prolongedLoss = ...
    startLoss+(nominalLoss-startLoss)*progress.abort;

% Discover safe-contact structure under a relaxed speed limit first, then
% tighten continuously to the unchanged nominal touchdown contract.
speedScale = rl.touchdownSpeedCurriculumScale+ ...
    (1-rl.touchdownSpeedCurriculumScale)*progress.height;
episodeConfig.experiment.safety.touchdownSpeedX = ...
    c.experiment.safety.touchdownSpeedX*speedScale;
episodeConfig.experiment.safety.touchdownSpeedZ = ...
    c.experiment.safety.touchdownSpeedZ*speedScale;

motionScale = rl.motionCurriculumStartScale+ ...
    (1-rl.motionCurriculumStartScale)*progress.motion;
episodeConfig.experiment.scenario.v1Range = ...
    c.experiment.scenario.v1Range*motionScale;
episodeConfig.experiment.scenario.a2Range = ...
    c.experiment.scenario.a2Range*motionScale;
episodeConfig.experiment.scenario.T1Range = ...
    rl.curriculumStartT1Range+ ...
    (c.experiment.scenario.T1Range-rl.curriculumStartT1Range)*progress.motion;

% Early pure-RL exploration must not let one random impact erase the signal
% from many near-contact transitions. Physical contact classification stays
% unchanged; only the training reward tightens to the nominal safety penalty.
failureNames={'UNSAFE_CONTACT','UNAUTHORIZED_CONTACT', ...
    'MISSED_PAD_CONTACT','SAFETY_ENVELOPE_VIOLATION'};
for i=1:numel(failureNames)
    name=failureNames{i};
    nominal=c.experiment.reward.(name);
    start=max(nominal,rl.unsafePenaltyCurriculumStart);
    episodeConfig.experiment.reward.(name)= ...
        start+(nominal-start)*progress.height;
end
end

function value = curriculumProgress(fraction,totalIterations,iteration)
if fraction <= 0
    value = 1;
    return;
end
span = max(1,round(fraction*totalIterations));
value = min(max((iteration-1)/span,0),1);
end
