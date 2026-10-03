function [score,rates] = selectionScoreV2(reasons,returns)
% SELECTIONSCOREV2  Outcome-ordered checkpoint score for the V2 task.
%
% A cheap SAFE_ABORT became a learnable shortcut: the controller discarded
% the target and ended early instead of retaining FOV.  Among zero-success
% policies, keep a visible timeout above a self-induced abort.  Unsafe
% contact remains the worst outcome.
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
    -10*rates.timeout-100*rates.safeAbort+mean(returns);
end
