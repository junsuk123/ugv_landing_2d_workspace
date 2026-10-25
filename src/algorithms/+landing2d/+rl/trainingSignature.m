function signature = trainingSignature(c)
% TRAININGSIGNATURE  Fingerprint deciding whether a saved policy fits configuration C.
% Everything that can change a trained policy enters: the algorithm version,
% the PPO settings (rl, including the training seed and checkpoint name), the
% experiment contract (environment, sensors, reward, scenario family, seed
% manifest), the state representation (graphState, including the relation
% permutation of the shuffled arm) and the action/contact constants. Display
% and execution-only settings do not (verbose, retrain; parallel settings are
% ignored by landing2d.rl.signatureMatches). Evaluation settings (c.evaluation)
% are outside the signature, so a new evaluation never invalidates a run.
signature = struct('algorithmVersion',landing2d.rl.algorithmVersion(c),'rl',c.rl);
signature.rl.verbose = false;
signature.rl.retrain = false;
signature.experiment = c.experiment;
if isfield(signature.experiment,'currentScenario')
    signature.experiment = rmfield(signature.experiment,'currentScenario');
end
signature.graphState = c.graphState;
signature.graphState.policyFile = '';
for name = {'padHalfLength','axMax','azMax','vxMax','vzMax'}
    signature.(name{1}) = c.(name{1});
end
end
