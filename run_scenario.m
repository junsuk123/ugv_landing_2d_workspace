function output = run_scenario(scenarioId,options)
% RUN_SCENARIO  Evaluate one fixed final-policy scenario: S1, S2, or S3.
%   run_scenario('S3',struct('spatialDimension',3))   % 3D option checkpoints
if nargin < 1 || isempty(scenarioId), scenarioId='S3'; end
if nargin < 2, options=struct(); end
root=fileparts(mfilename('fullpath'));
sourceRoots={fullfile(root,'src','orchestration'), ...
    fullfile(root,'src','simulations'),fullfile(root,'src','algorithms')};
for i=1:numel(sourceRoots)
    if ~contains([path pathsep],[sourceRoots{i} pathsep])
        addpath(sourceRoots{i});
    end
end
output=landing2d.orchestration.runScenario(scenarioId,options);
if nargout==0, assignin('base','landingScenario',output); end
end
