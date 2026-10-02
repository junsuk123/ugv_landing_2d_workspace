function levels = curriculumBatchLevels(rl,currentLevel,count)
% CURRICULUMBATCHLEVELS  Stratified replay across curriculum difficulty.
%
% A curriculum that replaces the easy distribution at every promotion
% forgets the rare touchdown examples that enabled promotion.  Keep a small
% easy and bridge subset while most episodes train at the current level.
validateattributes(count,{'numeric'}, ...
    {'scalar','real','finite','positive','integer'},mfilename,'count');
if ~isfinite(currentLevel)
    levels = nan(count,1);
    return;
end
currentLevel = min(max(currentLevel,0),1);
levels = currentLevel*ones(count,1);
if count==1, return; end
easyCount = min(count-1,round(rl.curriculumEasyReplayFraction*count));
if rl.curriculumEasyReplayFraction>0 && easyCount==0, easyCount=1; end
bridgeCount = min(count-easyCount-1, ...
    round(rl.curriculumBridgeReplayFraction*count));
if rl.curriculumBridgeReplayFraction>0 && bridgeCount==0 ...
        && easyCount<count-1, bridgeCount=1; end
levels(1:easyCount) = 0;
levels(easyCount+(1:bridgeCount)) = 0.5*currentLevel;
end
