function output = run_check(mode,options)
% RUN_CHECK Current compact contracts + bounded smoke; never full training.
% run_check                  new architecture checks and one PPO update per arm
% run_check('contracts')      new architecture checks only
% run_check('legacy')         archived 14-check suite
% run_check('trace',options)  archived seven-node trace tests (not tosm4)
if nargin<1, mode = 'smoke'; end
if nargin<2, options = struct(); end
root = fileparts(mfilename('fullpath'));
for name = {'orchestration','simulations','algorithms'}
    addpath(fullfile(root,'src',name{1}));
end
switch mode
    case 'smoke'
        assert(isempty(fieldnames(options)),'landing2d:UnknownOption','Smoke takes no options.');
        tests = landing2d.minimal.selfTest();
        output = landing2d.minimal.runPipeline(struct('smoke',true,'runSelfTest',false));
        output.tests = tests;
    case 'contracts'
        output = landing2d.minimal.selfTest();
    case 'legacy'
        output = landing2d.orchestration.selfTest();
    case 'trace'
        fprintf('ARCHIVED seven-node trace acceptance tests; not the active four-node study.\n');
        output = landing2d.trace.selfTest(options);
    otherwise
        error('landing2d:CheckMode','Use smoke, contracts, legacy or trace.');
end
if nargout==0, clear output; end
end
