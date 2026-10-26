function output = run_live(caseId,options)
% RUN_LIVE Current trained policies over repeated sensor noise; diagnostic only.
% run_live('S2',struct('replicates',10,'trainSeeds',421,'speed',1))
if nargin<1 || isempty(caseId), caseId = 'S1'; end
if nargin<2, options = struct(); end
root = fileparts(mfilename('fullpath'));
for name = {'orchestration','simulations','algorithms'}
    addpath(fullfile(root,'src',name{1}));
end
assert(ismember(upper(string(caseId)),["S1","S2","S3"]), ...
    'landing2d:ScenarioId','The active cases are S1, S2 and S3.');
if ~isfield(options,'trainSeeds'), options.trainSeeds = 421; end
output = landing2d.orchestration.runLive(caseId,options,landing2d.residual_context.config(root));
if nargout==0, assignin('base','liveReplicates',output); clear output; end
end
