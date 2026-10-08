function [episodeConfig,scenarioHeightRange,progress] = trainingEpisodeConfig(c,iteration,curriculumLevel,contractLevel)
% TRAININGEPISODECONFIG  Pure-RL training curriculum for one PPO iteration.
%
% Only episode generation is modified. Validation and final evaluation keep
% the nominal configuration in C, so reported performance is never measured
% on an easier curriculum distribution.
% CURRICULUMLEVEL is the episode's difficulty (easy/bridge replay or current).
% CONTRACTLEVEL (optional) is the current curriculum level of the run. With
% rl.curriculumReplayContract = 'current' (planar contract), the safety and
% terminal contract of every training episode -- touchdown speed limits,
% failure rewards and the prolonged-loss threshold -- follows CONTRACTLEVEL,
% while the start height and UGV motion follow CURRICULUMLEVEL. Replay
% episodes then keep their easy starts without teaching a relaxed touchdown
% contract: a low-altitude replay state cannot be told apart from the final
% descent of a nominal episode, so a contact that is SUCCESS in replay and
% UNSAFE_CONTACT at nominal gave conflicting outcomes for the same state.
rl = c.rl;
validateattributes(iteration,{'numeric'},{'scalar','integer','positive'});
episodeConfig = c;

if nargin >= 3 && isfinite(curriculumLevel)
    level = min(max(curriculumLevel,0),1);
    progress = struct('height',level,'abort',level,'motion',level);
    if nargin >= 4 && isfinite(contractLevel) && isfield(rl,'curriculumReplayContract') ...
            && strcmp(rl.curriculumReplayContract,'current')
        progress.abort = min(max(contractLevel,0),1);
        progress.contract = progress.abort;
    end
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

% Touchdown/terminal contract progress: the episode level, or the current
% level of the run when rl.curriculumReplayContract = 'current'.
contract = progress.height;
if isfield(progress,'contract'), contract = progress.contract; end

% Discover safe-contact structure under a relaxed speed limit first, then
% tighten continuously to the unchanged nominal touchdown contract.
speedScale = rl.touchdownSpeedCurriculumScale+ ...
    (1-rl.touchdownSpeedCurriculumScale)*contract;
episodeConfig.experiment.safety.touchdownSpeedX = ...
    c.experiment.safety.touchdownSpeedX*speedScale;
episodeConfig.experiment.safety.touchdownSpeedZ = ...
    c.experiment.safety.touchdownSpeedZ*speedScale;
if isfield(rl,'touchdownAttitudeCurriculumScale')
    % 3D option only: pitch and roll must both be calm at contact, so the
    % attitude/rate envelope is relaxed early and tightened to nominal.
    attitudeScale = rl.touchdownAttitudeCurriculumScale+ ...
        (1-rl.touchdownAttitudeCurriculumScale)*progress.height;
    episodeConfig.experiment.safety.touchdownPitchTolerance = ...
        c.experiment.safety.touchdownPitchTolerance*attitudeScale;
    episodeConfig.experiment.safety.touchdownPitchRateTolerance = ...
        c.experiment.safety.touchdownPitchRateTolerance*attitudeScale;
end
if isfield(rl,'trackAuthorizationCurriculumScale')
    % 3D option only: the pad must be confidently seen in a cone in both
    % axes before an authorized contact. Early training widens the recent-
    % detection window and lowers the confidence threshold, then restores
    % the nominal decision-context contract.
    authorizationScale = rl.trackAuthorizationCurriculumScale+ ...
        (1-rl.trackAuthorizationCurriculumScale)*progress.height;
    episodeConfig.experiment.safety.recentTrackGrace = ...
        c.experiment.safety.recentTrackGrace*authorizationScale;
    episodeConfig.experiment.safety.minimumTrackConfidence = ...
        c.experiment.safety.minimumTrackConfidence/authorizationScale;
end

motionScale = rl.motionCurriculumStartScale+ ...
    (1-rl.motionCurriculumStartScale)*progress.motion;
episodeConfig.experiment.scenario.v1Range = ...
    c.experiment.scenario.v1Range*motionScale;
episodeConfig.experiment.scenario.a2Range = ...
    c.experiment.scenario.a2Range*motionScale;
episodeConfig.experiment.scenario.T1Range = ...
    rl.curriculumStartT1Range+ ...
    (c.experiment.scenario.T1Range-rl.curriculumStartT1Range)*progress.motion;
if isfield(c.experiment.scenario,'lateralV1Range')
    % 3D option: the lateral pad motion follows the same motion curriculum.
    episodeConfig.experiment.scenario.lateralV1Range = ...
        c.experiment.scenario.lateralV1Range*motionScale;
    episodeConfig.experiment.scenario.lateralA2Range = ...
        c.experiment.scenario.lateralA2Range*motionScale;
end

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
        start+(nominal-start)*contract;
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
