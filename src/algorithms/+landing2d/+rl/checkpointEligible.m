function eligible = checkpointEligible(rl,curriculumLevel)
% CHECKPOINTELIGIBLE  Prevent easy-curriculum policies becoming final models.
if isfield(rl,'trainingRegime') && strcmp(rl.trainingRegime,'direct_ppo_v1')
    eligible = true;
    return;
end
if strcmp(rl.curriculumMode,'performance')
    eligible = isfinite(curriculumLevel) ...
        && curriculumLevel >= rl.checkpointMinCurriculum-1e-12;
else
    eligible = true;
end
end
