function tf = signatureMatches(saved,c)
% SIGNATUREMATCHES  Whether a saved training signature fits configuration C.
% Execution-only settings that cannot change a trained policy are ignored on
% both sides: rl.parallelWorkers and rl.parallelEpisodes (episode random
% streams are drawn before collection, so serial and parallel runs are
% identical). The stored signature content itself is unchanged, so existing
% checkpoints and the 3D signature hash stay valid.
tf = isequal(normalize(saved),normalize(landing2d.rl.trainingSignature(c)));
end

function s = normalize(s)
if isstruct(s) && isfield(s,'rl')
    s.rl = rmfield(s.rl,intersect(fieldnames(s.rl),{'parallelWorkers','parallelEpisodes'}));
end
end
