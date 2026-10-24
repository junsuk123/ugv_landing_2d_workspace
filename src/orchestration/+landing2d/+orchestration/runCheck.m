function output = runCheck(mode,options)
% RUNCHECK  Checks before the main study.
%   runCheck()               self-test + bounded smoke of every stage (minutes)
%   runCheck('learnability') also train plain PPO (seed 1, full budget) on the
%                            easy corner of the family - CV UGV, clean marker,
%                            speed-matched start - and report whether the task
%                            itself is learnable (validation landing rate >=
%                            learnabilityThreshold). Run this before trusting
%                            any method comparison on a new environment.
%   runCheck('trace')        only the decision-trace acceptance tests A01-A13
%                            (landing2d.trace.selfTest; needs the trained
%                            onto_rgat_ppo seed-11 checkpoint, headless GUI)
% The learnability check is a feasibility test of the environment, not a fourth
% comparison arm; its checkpoint is saved under checkpoints/precheck_*.
if nargin < 1 || isempty(mode), mode = 'smoke'; end
if nargin < 2, options = struct(); end
mode = char(mode);
assert(ismember(mode,{'smoke','learnability','trace'}),'landing2d:CheckMode', ...
    'mode must be smoke, learnability or trace.');
if strcmp(mode,'trace')
    output = struct('trace',landing2d.trace.selfTest(options));
    return;
end
learnabilityThreshold = 0.7;
tests = landing2d.orchestration.selfTest();
smoke = landing2d.orchestration.runPipeline(struct('smoke',true,'runSelfTest',false));
output = struct('tests',tests,'smoke',smoke);
fprintf('\nSmoke pipeline passed (integration only, no performance claim).\n');
if ~strcmp(mode,'learnability'), return; end

cfg = landing2d.config.primaryConfig(landing2d.orchestration.projectRoot());
cfg.experiment.scenario.constantVelocityProbability = 1;
cfg.experiment.scenario.initialSpeedMismatchProbability = 0;
cfg.experiment.sensor.perturbation.cleanProbability = 1;
cfg.figureVisible = false;
arm = landing2d.config.applyMethod(cfg,'ppo',1);
arm.rl.policyFile = 'checkpoints/precheck_ppo_easy_s01.mat';
fprintf('\n[learnability] plain PPO, seed 1, CV + clean + matched start (%d updates)\n', ...
    arm.rl.ppoIterations);
[agent,info] = landing2d.rl.loadOrTrainAgent(arm,@landing2d.rl.ppoTrain);
[~,~,easy] = landing2d.rl.evaluateV2(agent,arm,[]);
familyConfig = landing2d.config.applyMethod(landing2d.config.primaryConfig( ...
    landing2d.orchestration.projectRoot()),'ppo',1);
[~,~,family] = landing2d.rl.evaluateV2(agent,familyConfig,[]);
passed = easy.landingRate >= learnabilityThreshold;
fprintf(['[learnability] validation landing: easy corner %.0f%% (threshold %.0f%%), ' ...
    'full family %.0f%% -> %s\n'],100*easy.landingRate,100*learnabilityThreshold, ...
    100*family.landingRate,ternary(passed,'LEARNABLE','NOT LEARNABLE - fix the task first'));
output.learnability = struct('passed',passed,'easyLandingRate',easy.landingRate, ...
    'familyLandingRate',family.landingRate,'threshold',learnabilityThreshold, ...
    'history',info.history);
end

function out = ternary(condition,a,b)
if condition, out = a; else, out = b; end
end
