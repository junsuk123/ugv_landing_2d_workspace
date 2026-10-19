function output = run_scenario(caseId,options)
% RUN_SCENARIO  Fly one controlled case with trained checkpoints and plot it.
%   run_scenario('S4')   % S1 CV+clean, S2 CV+dropout, S3 CA+clean, S4 CA+dropout
%   run_scenario('S4',struct('trainSeeds',1:5,'replicates',5))
%   run_scenario('S4',struct('trace',true))     % live decision-trace dashboard of
%                                               % the trained TOSM R-GAT Actor (M2)
%   run_scenario('S1',struct('trace',true,'visible',false))   % headless record + export
%   run_scenario([],struct('replay','results/trace/S4_onto_rgat_ppo_s11_r01.mat'))
% Needs the checkpoints written by run. A look at trajectories only; the study
% numbers come from run (results/evaluation). See docs/TRACE_DASHBOARD_KO.md.
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
