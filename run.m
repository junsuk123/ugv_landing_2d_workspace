function output = run(options)
% RUN  Full study: self-test -> train -> evaluate -> figures (relational_policy_v1).
%   run                                   % 3 methods x training seeds 1-5
%   run(struct('trainSeeds',1:10))        % larger seed plan
%   run(struct('smoke',true))             % bounded integration run (no result)
%   run(struct('sections',{{'factorial','probes'}}))   % selected evaluations
% Compatible checkpoints in results/checkpoints are reused (an interrupted run
% resumes); pass retrain=true to train everything again.
% Outputs: results/checkpoints, results/evaluation (CSV + results.mat),
% results/figures (PNG). See docs/EXPERIMENT_DESIGN_KO.md for the design.
if nargin < 1, options = struct(); end
addSources();
output = landing2d.orchestration.runPipeline(options);
if nargout == 0, assignin('base','landingStudy',output); clear output; end
end

function addSources()
root = fileparts(mfilename('fullpath'));
for name = {'orchestration','simulations','algorithms'}
    folder = fullfile(root,'src',name{1});
    if ~contains([path pathsep],[folder pathsep]), addpath(folder); end
end
end
