function level = curriculumFloor(rl,iteration)
% CURRICULUMFLOOR  Scheduled lower bound for performance curriculum.
%
% Pure performance gating can remain forever on an easy task when safe
% touchdown is rare.  The floor preserves an initial discovery period, then
% guarantees a nominal-difficulty training phase before training ends.
validateattributes(iteration,{'numeric'}, ...
    {'scalar','real','finite','positive','integer'},mfilename,'iteration');
if ~strcmp(rl.curriculumMode,'performance')
    level = NaN;
    return;
end
startIteration = max(1,round(rl.curriculumFloorStartFraction*rl.ppoIterations));
fullIteration = max(startIteration+1, ...
    round(rl.curriculumFullDifficultyFraction*rl.ppoIterations));
if iteration <= startIteration
    level = 0;
else
    level = min(1,(iteration-startIteration)/(fullIteration-startIteration));
end
end
