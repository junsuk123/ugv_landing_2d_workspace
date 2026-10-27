function output = run_live(caseId,options)
% RUN_LIVE Current trained policies over repeated sensor noise; diagnostic only.
% run_live('S2',struct('replicates',10,'trainSeeds',61001,'speed',1))
% Archived v5: options.profile = 'residual-v5'. No training is performed.
% run_live('ranking')   stored OOD cells ranked by the TOSM advantage
% run_live('showcase')   best cell: stored-metric overview + verified replay of
%                        episodes TOSM lands and the others fail (post-hoc
%                        selection for viewing; landing2d.showcase.play)
% run_live('showcase',struct('rank',2,'episodes','all','maxEpisodes',5,'speed',2))
if nargin<1 || isempty(caseId), caseId = 'S1'; end
if nargin<2, options = struct(); end
root = fileparts(mfilename('fullpath'));
for name = {'orchestration','simulations','algorithms'}
    addpath(fullfile(root,'src',name{1}));
end
if any(strcmpi(caseId,{'ranking','showcase'}))
    output = landing2d.showcase.play(lower(char(caseId)),options,root);
    if nargout==0, assignin('base','showcase',output); clear output; end
    return;
end
assert(ismember(upper(string(caseId)),["S1","S2","S3"]), ...
    'landing2d:ScenarioId','The active cases are S1, S2 and S3.');
profile = 'current-semantics';
if isfield(options,'profile'), profile = options.profile; options = rmfield(options,'profile'); end
switch profile
    case 'current-semantics'
        d = landing2d.current_semantics.config(root); cfg = d.c;
        defaultSeed = d.developmentSeeds(1);
    case 'residual-v5'
        cfg = landing2d.residual_context.config(root); defaultSeed = 421;
    otherwise
        error('landing2d:StudyProfile','Use current-semantics or residual-v5.');
end
if ~isfield(options,'trainSeeds'), options.trainSeeds = defaultSeed; end
output = landing2d.orchestration.runLive(caseId,options,cfg);
if nargout==0, assignin('base','liveReplicates',output); clear output; end
end
