function registry = registry()
% REGISTRY Four fixed controls; no relation-shuffle arm in the main study.
ids = {'ppo','semantic_mlp_ppo','untyped_gnn_ppo','onto_rgat_ppo'};
labels = {'PPO','Current-feature MLP PPO','Untyped GNN PPO','Ontology R-GAT PPO'};
modes = {'baseline','semantic_mlp','untyped','rgat'};
widths = [110,65,55,46];
colors = {[.10 .32 .62],[.15 .55 .35],[.75 .45 .10],[.35 .16 .60]};
markers = {'o','d','s','^'};
% A fieldless struct([]) cannot take an indexed struct assignment in MATLAB.
methods = cell(1,4);
for k=1:4
    representation = 'current_semantics_actor';
    if k==1, representation = 'baseline'; end
    methods{k} = struct('id',ids{k},'label',labels{k}, ...
        'representation',representation,'graphPerturbation','none', ...
        'encoderMode',modes{k},'policyHiddenSize',widths(k), ...
        'color',colors{k},'lineStyle','-','marker',markers{k});
end
methods = [methods{:}];
registry = struct('version','comparison_registry_current_semantics_v1', ...
    'methods',methods,'trainSeeds',struct('default',61001:61005, ...
    'development',61001:61005,'confirmation',61101:61120), ...
    'relationShuffle',struct('minChangedFraction',2/3));
end
