function [next,nextStreak] = advanceCurriculumLevel(rl,current,landingRate,streak)
% ADVANCECURRICULUMLEVEL  Promote difficulty only after repeatable landings.
if nargin < 4, streak = 0; end
validateattributes(current,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
validateattributes(landingRate,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
validateattributes(streak,{'numeric'},{'scalar','integer','nonnegative'});
next = current;
nextStreak = 0;
if strcmp(rl.curriculumMode,'performance') ...
        && landingRate >= rl.curriculumLandingThreshold
    nextStreak = streak+1;
    if nextStreak >= rl.curriculumRequiredWindows
        next = min(1,current+rl.curriculumStep);
        nextStreak = 0;
    end
end
end
