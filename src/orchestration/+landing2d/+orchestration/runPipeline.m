function output = runPipeline(options)
% RUNPIPELINE  Self-test -> train -> evaluate -> figures (relational_policy_v1).
%   output = landing2d.orchestration.runPipeline(options)
% options
%   trainSeeds   training seeds of every method (default registry.trainSeeds.default
%                = 1-5; smoke: 1). Method differences are reported over seeds.
%   methods      registry ids (default ppo, onto_rgat_ppo, shuffled_rgat_ppo)
%   retrain      true retrains compatible checkpoints too (default false; an
%                incompatible or missing checkpoint is always retrained)
%   sections     evaluation sections (default all, see runEvaluation)
%   smoke        true: bounded integration run (1 PPO iteration, few episodes,
%                nothing saved unless saveResults); not a result
%   runSelfTest  default true
%   saveResults  default true (false in smoke)
%   figureVisible default false
% Outputs under results/: checkpoints/, evaluation/ (CSV + results.mat),
% figures/ (PNG). The test, stress and fixed-case seeds never select a
% checkpoint; checkpoint selection uses the validation split during PPO.
if nargin < 1, options = struct(); end
registry = landing2d.config.methodRegistry();
defaults = struct('trainSeeds',[],'methods',{{registry.methods.id}},'retrain',false, ...
    'sections',{{'learning','heldout','factorial','generalization','probes'}}, ...
    'smoke',false,'runSelfTest',true,'saveResults',[],'figureVisible',false);
options = parseOptions(options,defaults);
if isempty(options.trainSeeds)
    options.trainSeeds = registry.trainSeeds.default;
    if options.smoke, options.trainSeeds = 1; end
end
if isempty(options.saveResults), options.saveResults = ~options.smoke; end

root = landing2d.orchestration.projectRoot();
cfg = landing2d.config.primaryConfig(root);
cfg.figureVisible = options.figureVisible;
if options.smoke, cfg = landing2d.orchestration.smokeConfig(cfg); end
landing2d.config.validateConfig(cfg);
fprintf(['\nUGV landing 2D | relational_policy_v1 | %s | methods %s | training ' ...
    'seeds %s\n'],ternary(options.smoke,'smoke','full'),strjoin(options.methods,', '), ...
    mat2str(options.trainSeeds));

tests = table();
if options.runSelfTest, tests = landing2d.orchestration.selfTest(); end

runs = landing2d.orchestration.trainRuns(cfg,struct('methods',{options.methods}, ...
    'trainSeeds',options.trainSeeds,'retrain',options.retrain,'smoke',options.smoke));

outputDir = '';
if options.saveResults, outputDir = fullfile(cfg.outputDir,'evaluation'); end
results = landing2d.orchestration.runEvaluation(runs,cfg, ...
    struct('sections',{options.sections},'outputDir',outputDir));

figureDir = '';
if options.saveResults, figureDir = fullfile(cfg.outputDir,'figures'); end
figures = landing2d.viz.plotResults(results,cfg,struct('outputDir',figureDir, ...
    'visible',options.figureVisible));
landing2d.orchestration.printHeadline(results);
output = struct('config',cfg,'tests',tests,'results',results,'figures',figures);
end

function options = parseOptions(options,defaults)
assert(isstruct(options) && isscalar(options),'landing2d:InvalidOptions', ...
    'options must be a scalar struct.');
unknown = setdiff(fieldnames(options),fieldnames(defaults));
assert(isempty(unknown),'landing2d:UnknownOption','Unknown run option: %s', ...
    strjoin(unknown,', '));
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(options,names{i}), options.(names{i}) = defaults.(names{i}); end
end
options.methods = cellstr(options.methods);
options.sections = cellstr(options.sections);
options.smoke = logical(options.smoke);
end

function out = ternary(condition,a,b)
if condition, out = a; else, out = b; end
end
