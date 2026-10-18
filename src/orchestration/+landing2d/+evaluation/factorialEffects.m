function E = factorialEffects(T,metrics)
% FACTORIALEFFECTS  Replicate-paired 2 x 2 effects inside each run.
%   E = landing2d.evaluation.factorialEffects(T,metrics)
% T has one row per run (MethodId, Method, TrainSeed), Replicate and Case
% (S1-S4); the four cases of one replicate must share the episode seed.
%   Dropout|CV = S2-S1, Dropout|CA = S4-S3, Motion|clean = S3-S1,
%   Motion|dropout = S4-S2, Interaction = S4-S3-S2+S1
names = ["Dropout|CV","Dropout|CA","Motion|clean","Motion|dropout","Interaction"];
weights = [-1 1 0 0; 0 0 -1 1; -1 0 1 0; 0 -1 0 1; 1 -1 -1 1]; % S1..S4
cases = ["S1","S2","S3","S4"];
[g,G] = findgroups(T(:,{'MethodId','Method','TrainSeed','Replicate'}));
E = table();
for i = 1:height(G)
    rows = T(g==i,:);
    [present,order] = ismember(cases,rows.Case);
    if ~all(present), continue; end
    rows = rows(order,:);
    assert(numel(unique(rows.EpisodeSeed))==1,'landing2d:FactorialPairing', ...
        'The four factorial cases of one replicate must share the episode seed.');
    for e = 1:numel(names)
        out = G(i,:); out.Effect = names(e);
        for k = 1:numel(metrics)
            out.(metrics{k}) = weights(e,:)*double(rows.(metrics{k}));
        end
        E = [E;out]; %#ok<AGROW>
    end
end
end
