function output = run_live(target,options)
% RUN_LIVE  Real-time side-by-side test of the three final policies.
%   run_live            % S3 visibility-recovery scenario
%   run_live('S2')      % fixed paper scenario S1, S2, or S3
%   run_live(3001)      % held-out test seed
%   run_live('S1',struct('playbackSpeed',4,'videoFile','live_s1.mp4'))
%   run_live('S3',struct('spatialDimension',3))   % 3D option, 3D axes
if nargin < 1 || isempty(target), target='S3'; end
if nargin < 2, options=struct(); end
root=fileparts(mfilename('fullpath'));
sourceRoots={fullfile(root,'src','orchestration'), ...
    fullfile(root,'src','simulations'),fullfile(root,'src','algorithms')};
for i=1:numel(sourceRoots)
    if ~contains([path pathsep],[sourceRoots{i} pathsep])
        addpath(sourceRoots{i});
    end
end
output=landing2d.orchestration.runLive(target,options);
if nargout==0, assignin('base','landingLive',output); end
end
