function [next,nextStreak] = advanceCurriculumLevel(rl,current,landingRate,streak)
% ADVANCECURRICULUMLEVEL  Promote difficulty only after repeatable landings.
% STREAK > 0 counts consecutive windows at or above the promotion threshold.
% With rl.curriculumDemotionThreshold (planar contract), STREAK < 0 counts
% consecutive windows below it, and rl.curriculumDemotionWindows of them step
% the level back down (the scheduled floor, landing2d.rl.curriculumFloor, still
% applies): a policy that collapses after a promotion retrains on the easier
% level instead of staying at the harder one. Without that field the rule is
% the original promotion-only rule.
if nargin < 4, streak = 0; end
validateattributes(current,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
validateattributes(landingRate,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
validateattributes(streak,{'numeric'},{'scalar','integer'});
next = current;
nextStreak = 0;
if ~strcmp(rl.curriculumMode,'performance'), return; end
if landingRate >= rl.curriculumLandingThreshold
    nextStreak = max(streak,0)+1;
    if nextStreak >= rl.curriculumRequiredWindows
        next = min(1,current+rl.curriculumStep);
        nextStreak = 0;
    end
elseif isfield(rl,'curriculumDemotionThreshold') ...
        && landingRate < rl.curriculumDemotionThreshold
    nextStreak = min(streak,0)-1;
    if -nextStreak >= rl.curriculumDemotionWindows
        next = max(0,current-rl.curriculumStep);
        nextStreak = 0;
    end
end
end
