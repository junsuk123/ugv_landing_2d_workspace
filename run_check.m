function output = run_check(mode,options)
% RUN_CHECK Current-observation semantics contracts + bounded smoke; never full training.
% run_check                  current-semantics core, one PPO update per arm, eight cells
% run_check('current-semantics') same TEST ONLY suite
% run_check('residual-v5')    archived residual checks and one PPO update per arm
% run_check('smoke')         archived minimal v3.1 smoke
% run_check('contracts')      archived minimal v3.1 contracts
% run_check('legacy')         archived 14-check suite
% run_check('trace',options)  archived seven-node trace tests (not tosm4)
if nargin<1, mode = 'current-semantics'; end
if nargin<2, options = struct(); end
root = fileparts(mfilename('fullpath'));
for name = {'orchestration','simulations','algorithms'}
    addpath(fullfile(root,'src',name{1}));
end
switch mode
    case 'current-semantics'
        assert(isempty(fieldnames(options)),'landing2d:UnknownOption','Smoke takes no options.');
        output = landing2d.current_semantics.smokeTest();
    case {'residual','residual-v5'}
        assert(isempty(fieldnames(options)),'landing2d:UnknownOption','Smoke takes no options.');
        tests = landing2d.residual_context.selfTest();
        output = landing2d.residual_context.runPipeline(struct('smoke',true,'runSelfTest',false));
        output.tests = tests;
    case 'residual-v4'
        assert(isempty(fieldnames(options)),'landing2d:UnknownOption','Smoke takes no options.');
        tests = landing2d.residual_base_init.selfTest();
        output = landing2d.residual_base_init.runPipeline(struct('smoke',true,'runSelfTest',false));
        output.tests = tests;
    case 'residual-v3'
        assert(isempty(fieldnames(options)),'landing2d:UnknownOption','Smoke takes no options.');
        tests = landing2d.residual_motion.selfTest();
        output = landing2d.residual_motion.runPipeline(struct('smoke',true,'runSelfTest',false));
        output.tests = tests;
    case 'residual-v2'
        assert(isempty(fieldnames(options)),'landing2d:UnknownOption','Smoke takes no options.');
        tests = landing2d.residual_logits.selfTest();
        output = landing2d.residual_logits.runPipeline(struct('smoke',true,'runSelfTest',false));
        output.tests = tests;
    case 'residual-v1'
        assert(isempty(fieldnames(options)),'landing2d:UnknownOption','Smoke takes no options.');
        tests = landing2d.residual.selfTest();
        output = landing2d.residual.runPipeline(struct('smoke',true,'runSelfTest',false));
        output.tests = tests;
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
        error('landing2d:CheckMode','Use current-semantics, residual, residual-v5, residual-v4, residual-v3, residual-v2, residual-v1, smoke, contracts, legacy or trace.');
end
if nargout==0, clear output; end
end
