function [score,rates] = selectionScoreV2(reasons,returns)
% SELECTIONSCOREV2  Outcome-ordered checkpoint score for the V2 task.
%
% The previous score penalized SAFE_ABORT but did not penalize TASK_TIMEOUT,
% so a controller that hovered until the deadline beat a safe abort.  The
% explicit ordering below is SUCCESS > SAFE_ABORT > TASK_TIMEOUT > UNSAFE.
reasons = string(reasons);
returns = double(returns(:));
assert(numel(reasons)==numel(returns), ...
    'landing2d:EvaluationSize','Reasons and returns must have equal length.');
success = reasons=="SUCCESS";
safeAbort = reasons=="SAFE_ABORT";
timeout = reasons=="TASK_TIMEOUT";
unsafe = ismember(reasons,["UNSAFE_CONTACT","UNAUTHORIZED_CONTACT", ...
    "MISSED_PAD_CONTACT","SAFETY_ENVELOPE_VIOLATION"]);
known = success | safeAbort | timeout | unsafe;
assert(all(known),'landing2d:UnknownTerminalReason', ...
    'Checkpoint selection received an unknown terminal reason.');
rates = struct('success',mean(success),'safeAbort',mean(safeAbort), ...
    'timeout',mean(timeout),'unsafe',mean(unsafe));
score = 1000*rates.success-1000*rates.unsafe ...
    -100*rates.timeout-10*rates.safeAbort+mean(returns);
end
