function output = run_scenario(caseId,options)
% RUN_SCENARIO  Fly one controlled case with trained checkpoints and plot it.
%   run_scenario('S4')   % S1 CV+clean, S2 CV+dropout, S3 CA+clean, S4 CA+dropout
%   run_scenario('S4',struct('trainSeeds',1:5,'replicates',5))
% Needs the checkpoints written by run. A look at trajectories only; the study
% numbers come from run (results/evaluation).
if nargin < 1 || isempty(caseId), caseId = 'S4'; end
if nargin < 2, options = struct(); end
root = fileparts(mfilename('fullpath'));
for name = {'orchestration','simulations','algorithms'}
    folder = fullfile(root,'src',name{1});
    if ~contains([path pathsep],[folder pathsep]), addpath(folder); end
end
output = landing2d.orchestration.runScenario(caseId,options);
if nargout == 0, clear output; end
end
