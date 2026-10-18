function arms = comparisonArms(cfg,options)
% COMPARISONARMS  Configured runs of one training seed (shared by train and evaluate).
%   options.trainSeed  training seed id (default 1)
%   options.graphSeed  graph seed of the shuffled method (default = trainSeed)
%   options.methods    subset of registry method ids (default all, registry order)
if nargin < 2, options = struct(); end
trainSeed = fieldOr(options,'trainSeed',1);
graphSeed = fieldOr(options,'graphSeed',[]);
arms = struct('id',{},'label',{},'representation',{},'graphPerturbation',{}, ...
    'trainSeed',{},'graphSeed',{},'color',{},'lineStyle',{},'marker',{},'config',{});
registry = landing2d.config.methodRegistry();
ids = fieldOr(options,'methods',{registry.methods.id});
unknown = setdiff(ids,{registry.methods.id});
assert(isempty(unknown),'landing2d:UnknownMethod','Unknown method(s): %s',strjoin(unknown,', '));
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
