function C = methodContrasts(R,keys,metrics,pairs)
% METHODCONTRASTS  Seed-paired method differences (A - B) with a 95% t interval.
%   C = landing2d.evaluation.methodContrasts(R,{'Cell'},{'Success'})
% R from landing2d.evaluation.runMeans. Runs of two methods with the same
% training seed trained on the same episode sequence, so the difference is
% paired by TrainSeed. Default pairs (docs/EXPERIMENT_DESIGN_KO.md):
%   onto_rgat_ppo - ppo                 relational representation vs plain MLP
%   onto_rgat_ppo - shuffled_rgat_ppo   correct vs permuted relation semantics
%   shuffled_rgat_ppo - ppo             graph architecture without the semantics
% For every metric M: Delta_M (mean over seeds), Delta_M_ci, Delta_M_n and
% Delta_M_positive (seeds with A > B). Whether positive is better depends on M.
if nargin < 4 || isempty(pairs)
    pairs = {'onto_rgat_ppo','ppo';'onto_rgat_ppo','shuffled_rgat_ppo'; ...
        'shuffled_rgat_ppo','ppo'};
    if any(string(R.MethodId)=="residual_mlp_ppo")
        pairs(end+1,:) = {'onto_rgat_ppo','residual_mlp_ppo'};
    end
end
keys = cellstr(keys); metrics = cellstr(metrics);
present = unique(string(R.MethodId));
C = table();
if isempty(keys)
    groups = {true(height(R),1)}; keyRows = table();
else
    [g,keyRows] = findgroups(R(:,keys));
    groups = arrayfun(@(i)g==i,1:height(keyRows),'UniformOutput',false);
end
for p = 1:size(pairs,1)
    if ~all(ismember(string(pairs(p,:)),present)), continue; end
    for i = 1:numel(groups)
        rows = R(groups{i},:);
        a = rows(string(rows.MethodId)==pairs{p,1},:);
        b = rows(string(rows.MethodId)==pairs{p,2},:);
        [seeds,ia,ib] = intersect(a.TrainSeed,b.TrainSeed);
        if isempty(seeds), continue; end
        out = table(string(pairs{p,1}),string(pairs{p,2}), ...
            string(pairs{p,1})+" - "+string(pairs{p,2}),numel(seeds), ...
            'VariableNames',{'MethodA','MethodB','Contrast','Seeds'});
        if ~isempty(keys), out = [keyRows(i,:),out]; end %#ok<AGROW>
        for k = 1:numel(metrics)
            d = double(a.(metrics{k})(ia))-double(b.(metrics{k})(ib));
            [mu,~,half,n] = landing2d.evaluation.tInterval(d);
            out.(['Delta_',metrics{k}]) = mu;
            out.(['Delta_',metrics{k},'_ci']) = half;
            out.(['Delta_',metrics{k},'_n']) = n;
            out.(['Delta_',metrics{k},'_positive']) = sum(d>0);
        end
        C = [C;out]; %#ok<AGROW>
    end
end
end
