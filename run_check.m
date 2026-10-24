function output = run_check(mode,options)
% RUN_CHECK  Checks before the study.
%   run_check                  self-test + bounded smoke of every stage (minutes)
%   run_check('learnability')  also trains plain PPO (seed 1) on the easy corner
%                              (CV UGV, clean marker, matched start) and reports
%                              whether the landing task itself is learnable
%   run_check('trace')         decision-trace dashboard acceptance tests A01-A13
%                              (trained onto_rgat_ppo checkpoint, headless)
if nargin < 1, mode = 'smoke'; end
if nargin < 2, options = struct(); end
root = fileparts(mfilename('fullpath'));
for name = {'orchestration','simulations','algorithms'}
    folder = fullfile(root,'src',name{1});
    if ~contains([path pathsep],[folder pathsep]), addpath(folder); end
end
output = landing2d.orchestration.runCheck(mode,options);
if nargout == 0, clear output; end
end
