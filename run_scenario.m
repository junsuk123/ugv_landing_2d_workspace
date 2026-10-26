function output = run_scenario(caseId,options)
% RUN_SCENARIO Current trained policies: S1 reference, S2 dropout, S3 acceleration.
% run_scenario('S2',struct('trainSeeds',421:425,'replicates',5))
if nargin<1 || isempty(caseId), caseId = 'S1'; end
if nargin<2, options = struct(); end
root = fileparts(mfilename('fullpath'));
for name = {'orchestration','simulations','algorithms'}
    addpath(fullfile(root,'src',name{1}));
end
assert(~isfield(options,'trace') && ~isfield(options,'replay'), ...
    'landing2d:MinimalTrace','The old trace dashboard is seven-node only. Use landing2d.orchestration.runTrace explicitly for archives.');
assert(ismember(upper(string(caseId)),["S1","S2","S3"]), ...
    'landing2d:ScenarioId','The active cases are S1, S2 and S3.');
if ~isfield(options,'trainSeeds'), options.trainSeeds = 421; end
output = landing2d.orchestration.runScenario(caseId,options,landing2d.residual_context.config(root));
if nargout==0, clear output; end
end
