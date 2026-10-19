function tf = plateauReached(history,iteration,rl)
% PLATEAUREACHED  Common validation-plateau stop of landing2d.rl.ppoTrain.
%   tf = landing2d.rl.plateauReached(history,iteration,rl)
% validation_plateau_v1: true when the rl.earlyStop.window most recent
% validation evaluations after update 0 (history(2:end)) all have a landing
% rate of at least rl.earlyStop.minimumLandingRate and ITERATION >=
% rl.earlyStop.minimumIterations. Without rl.earlyStop it is always false.
% Only the validation split enters; the rule is the same for every method.
tf = false;
if ~isfield(rl,'earlyStop') || ~strcmp(rl.earlyStop.rule,'validation_plateau_v1'), return; end
rule = rl.earlyStop;
recent = history(2:end);
if iteration < rule.minimumIterations || numel(recent) < rule.window, return; end
tf = all([recent(end-rule.window+1:end).landingRate] >= rule.minimumLandingRate);
end
