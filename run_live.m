function output = run_live(caseId,options)
% RUN_LIVE  Live overlay of sensor-noise replicates: every method flies one controlled case.
%   run_live                                      % S4 (CA + dropout), training seed 1, 10 replicates
%   run_live('S2')                                % another case S1-S4
%   run_live('S4',struct('replicates',20))        % more noise realizations
%   run_live('S4',struct('trainSeeds',1:3))       % several trained checkpoints (one color each)
%   run_live('S4',struct('speed',1))              % paced to real time
% All replicates share the scenario, UGV motion, initial state and injected
% marker dropout; only the perception/localization sensor noise differs
% (marker corners, fused localization, tracker). One window per method shows
% the trajectories and requested accelerations of every replicate growing
% live, and a comparison window shows their across-replicate spread over
% time (behavioral consistency). Needs trained checkpoints of the current
% configuration (run first). Options: landing2d.orchestration.runLive.
if nargin < 1, caseId = []; end
if nargin < 2, options = struct(); end
addSources();
output = landing2d.orchestration.runLive(caseId,options);
if nargout == 0, assignin('base','liveReplicates',output); clear output; end
end

function addSources()
root = fileparts(mfilename('fullpath'));
for name = {'orchestration','simulations','algorithms'}
    folder = fullfile(root,'src',name{1});
    if ~contains([path pathsep],[folder pathsep]), addpath(folder); end
end
end
