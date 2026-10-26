function R = reproduce(E,d)
% REPRODUCE The k = 1 rows must equal the stored protocol-v2 development episodes.
% Success, Unsafe, TerminalReason and FailureClass exactly; AimErrorRMS_m,
% Duration_s and Return within aimTolerance * max(1,|stored|) (the CSV keeps
% 15 significant digits). Throws on the first mismatch; R lists every check.
stored = readtable(fullfile(d.v2Evaluation,'generalizationEpisodes.csv'),'TextType','string');
keyNames = {'MethodId','TrainSeed','Factor','Shift','EpisodeSeed'};
A = E(E.Gain==1,:);
A.MethodId = string(A.MethodId); A.Factor = string(A.Factor); A.Shift = string(A.Shift);
B = stored(:,[keyNames,{'Success','Unsafe','TerminalReason','FailureClass','AimErrorRMS_m','Duration_s','Return'}]);
B.Properties.VariableNames(6:end) = strcat('Stored',B.Properties.VariableNames(6:end));
J = innerjoin(A,B,'Keys',keyNames);
assert(height(J)==height(A) && height(A)>0,'landing2d:GainAuditReproduction', ...
    'Every k = 1 episode needs exactly one stored v2 episode (%d of %d).',height(J),height(A));
tol = d.reproduction.aimTolerance;
near = @(x,y) abs(x-y)<=tol*max(1,abs(y));
R = table(J.MethodId,J.TrainSeed,J.Factor,J.Shift,J.EpisodeSeed, ...
    J.Success==J.StoredSuccess & J.Unsafe==J.StoredUnsafe, ...
    string(J.TerminalReason)==J.StoredTerminalReason & string(J.FailureClass)==J.StoredFailureClass, ...
    near(J.AimErrorRMS_m,J.StoredAimErrorRMS_m),near(J.Duration_s,J.StoredDuration_s), ...
    near(J.Return,J.StoredReturn),abs(J.AimErrorRMS_m-J.StoredAimErrorRMS_m), ...
    'VariableNames',[keyNames,{'OutcomeEqual','ReasonEqual','AimClose','DurationClose','ReturnClose','AimAbsDiff_m'}]);
bad = find(~(R.OutcomeEqual & R.ReasonEqual & R.AimClose & R.DurationClose & R.ReturnClose),1);
assert(isempty(bad),'landing2d:GainAuditReproduction', ...
    'k = 1 differs from the stored v2 episode: %s seed %d %s %s env %d.',R.MethodId(bad), ...
    R.TrainSeed(bad),R.Factor(bad),R.Shift(bad),R.EpisodeSeed(bad));
end
