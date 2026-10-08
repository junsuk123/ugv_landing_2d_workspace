function arms = comparisonArms(cfg,options)
% COMPARISONARMS  Configured runs of one comparison (shared by train, evaluate, live).
%   options.trainSeed  training seed id (default 1)
%   options.graphSeed  graph seed id of the perturbed method (default 1)
%   options.methods    subset of registry method ids (default all, registry order)
%   options.modes      legacy stateRepresentation list (ablations); overrides methods
% Planar contract: the registered methods (landing2d.config.methodRegistry).
% 3D option or explicit legacy modes: the previous mode-based arms with their
% previous checkpoint names, so those paths are unchanged.
if nargin < 2, options = struct(); end
trainSeed = fieldOr(options,'trainSeed',1);
graphSeed = fieldOr(options,'graphSeed',1);
modes = fieldOr(options,'modes',{});
arms = struct('id',{},'label',{},'representation',{},'graphPerturbation',{}, ...
    'trainSeed',{},'graphSeed',{},'color',{},'lineStyle',{},'marker',{},'config',{});
if landing2d.environment.isSpatial(cfg) || ~isempty(modes)
    if isempty(modes), modes = {'baseline','context_flat','context_rgat'}; end
    colors = [0.10 0.32 0.62; 0.85 0.33 0.10; 0.35 0.16 0.60];
    colors = [colors; lines(max(numel(modes)-3,0))];
    for i = 1:numel(modes)
        arm = landing2d.graphstate.applyStateRepresentation(cfg,modes{i});
        arm.graphState.stateRepresentation = modes{i};
        arm.rl.policyFile = sprintf('ppo_%s_planar_visibility_v2.mat',modes{i});
        arm.dashboardAgentLabel = legacyLabel(modes{i});
        arms(end+1) = struct('id',modes{i},'label',legacyLabel(modes{i}), ...
            'representation',modes{i},'graphPerturbation','none', ...
            'trainSeed',NaN,'graphSeed',NaN,'color',colors(i,:), ...
            'lineStyle','-','marker','o','config',arm); %#ok<AGROW>
    end
    return;
end
registry = landing2d.config.methodRegistry();
ids = fieldOr(options,'methods',{registry.methods.id});
for i = 1:numel(registry.methods)
    method = registry.methods(i);
    if ~ismember(method.id,ids), continue; end
    arm = landing2d.config.applyMethod(cfg,method.id,trainSeed,graphSeed);
    arms(end+1) = struct('id',method.id,'label',method.label, ...
        'representation',method.representation, ...
        'graphPerturbation',method.graphPerturbation, ...
        'trainSeed',arm.comparisonRun.trainSeed,'graphSeed',arm.comparisonRun.graphSeed, ...
        'color',method.color,'lineStyle',method.lineStyle,'marker',method.marker, ...
        'config',arm); %#ok<AGROW>
end
end

function value = fieldOr(s,name,default)
value = default;
if isfield(s,name) && ~isempty(s.(name)), value = s.(name); end
if iscell(default) && ~iscell(value), value = cellstr(value); end
end

function label = legacyLabel(mode)
switch mode
    case 'baseline', label = 'Low-level PPO';
    case 'context_flat', label = 'Semantic-flat PPO';
    case 'context_node_pool', label = 'Ontology node-pool PPO';
    case 'context_gat', label = 'Single-relation GAT PPO';
    case 'context_rgat', label = 'Ontology R-GAT PPO';
    otherwise, label = mode;
end
end
