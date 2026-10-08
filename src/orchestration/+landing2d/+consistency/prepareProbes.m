function probes = prepareProbes(c,options)
% PREPAREPROBES  Build or load the fixed-probe banks, validity grids and frozen judge.
%   probes = landing2d.consistency.prepareProbes(c)
% Order (validation before test, test never used for any choice):
%   1) validation bank (landing2d.probe.buildBank) and its validity grid over all
%      horizon/kappa candidates (landing2d.consistency.validityGrid)
%   2) frozen judge settings from validation only (calibrateValidity) ->
%      <outputDir>/consistency/validity_frozen.json
%   3) test bank and its validity grid for the frozen horizon and kappa only
% Files in <outputDir>/consistency are reused when their configuration hash
% matches the current configuration (OPTIONS.rebuild forces a rebuild).
% OPTIONS: validationCount, testCount, rebuild, parallel, verbose.
if nargin < 2, options = struct(); end
cc = c.consistency;
defaults = struct('validationCount',cc.probe.validationEpisodeCount, ...
    'testCount',cc.probe.testEpisodeCount,'rebuild',false,'parallel',false, ...
    'verbose',true,'folder',fullfile(c.outputDir,'consistency'));
names = fieldnames(options);
for i = 1:numel(names)
    assert(isfield(defaults,names{i}),'landing2d:ProbeOption','Unknown option %s.',names{i});
    defaults.(names{i}) = options.(names{i});
end
options = defaults;
if ~exist(options.folder,'dir'), mkdir(options.folder); end
[~,configHash] = landing2d.util.resolvedConfig(c);
validation = cached(fullfile(options.folder,'probe_bank_validation.mat'),'bank',configHash, ...
    options,@()landing2d.probe.buildBank(c,'validation', ...
    struct('count',options.validationCount,'verbose',options.verbose)));
validationGrid = cached(fullfile(options.folder,'validity_grid_validation.mat'),'grid', ...
    configHash,options,@()landing2d.consistency.validityGrid(validation,c, ...
    struct('parallel',options.parallel)));
frozenFile = fullfile(options.folder,'validity_frozen.json');
frozen = landing2d.consistency.calibrateValidity(validation,validationGrid,c,frozenFile);
test = cached(fullfile(options.folder,'probe_bank_test.mat'),'bank',configHash,options, ...
    @()landing2d.probe.buildBank(c,'test',struct('count',options.testCount, ...
    'verbose',options.verbose)));
testGrid = cached(fullfile(options.folder,sprintf('validity_grid_test_H%g_k%g.mat', ...
    frozen.horizon,frozen.kappa)),'grid',configHash,options, ...
    @()landing2d.consistency.validityGrid(test,c,struct('horizons',frozen.horizon, ...
    'kappas',frozen.kappa,'parallel',options.parallel)));
probes = struct('validation',validation,'validationGrid',validationGrid, ...
    'test',test,'testGrid',testGrid,'frozen',frozen,'frozenFile',frozenFile, ...
    'configHash',configHash,'folder',options.folder);
if options.verbose
    fprintf('probes: validation %d, test %d; frozen horizon %.2f s, kappa %.2f (floors met %d)\n', ...
        validation.meta.probeCount,test.meta.probeCount,frozen.horizon,frozen.kappa, ...
        frozen.meetsFloors);
end
end

function value = cached(file,name,configHash,options,build)
if ~options.rebuild && isfile(file)
    saved = load(file,name,'configHash');
    if isfield(saved,'configHash') && strcmp(saved.configHash,configHash)
        value = saved.(name);
        return;
    end
end
value = build(); %#ok<NASGU>
s = struct(name,value,'configHash',configHash); %#ok<NASGU>
save(file,'-struct','s','-v7.3');
value = s.(name);
end
