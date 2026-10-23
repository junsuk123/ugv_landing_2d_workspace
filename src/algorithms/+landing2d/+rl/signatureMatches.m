function tf = signatureMatches(saved,c)
% SIGNATUREMATCHES  Whether a saved training signature fits configuration C.
% Execution-only settings that cannot change a trained policy are ignored on
% both sides: rl.parallelWorkers and rl.parallelEpisodes (episode random
% streams are drawn before collection, so serial and parallel runs are
% identical). The stored signature content itself is unchanged, so existing
% checkpoints retain exact signature matching.
% Plain PPO (graphState.stateRepresentation = 'baseline') never reads the
% graph settings: on both sides they are dropped and the algorithm version
% is replaced by its plain-PPO path version (landing2d.rl.baselineVersion),
% so an R-GAT-only change does not retrain plain PPO. rl, experiment and the
% action constants still have to match exactly.
tf = isequal(normalize(saved),normalize(landing2d.rl.trainingSignature(c)));
end

function s = normalize(s)
if isstruct(s) && isfield(s,'rl')
    s.rl = rmfield(s.rl,intersect(fieldnames(s.rl),{'parallelWorkers','parallelEpisodes'}));
end
if isstruct(s) && isfield(s,'graphState') && isfield(s.graphState,'stateRepresentation') ...
        && strcmp(s.graphState.stateRepresentation,'baseline')
    s.algorithmVersion = landing2d.rl.baselineVersion(s.algorithmVersion);
    s.graphState = struct('stateRepresentation',s.graphState.stateRepresentation, ...
        'observationSource',s.graphState.observationSource);
end
end
