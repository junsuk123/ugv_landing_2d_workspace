function [comparison,cfg,fig] = run_realtime_checkpoint_comparison(options)
% RUN_REALTIME_CHECKPOINT_COMPARISON  Replay PN and two saved PPO agents.
%
% All three agents are drawn together in each scenario tab.  Axes are fixed
% before playback from the complete trajectories, so the view never pans or
% rescales and the full path remains inside the configured physical bounds.
%
%   run_realtime_checkpoint_comparison
%   run_realtime_checkpoint_comparison(struct('playbackSpeed',4))
%   run_realtime_checkpoint_comparison(struct('baselinePolicyFile','x.mat', ...
%       'ontologyPolicyFile','y.mat'))
if nargin < 1, options = struct(); end
if ~(isstruct(options) && isscalar(options))
    error('landing2d:InvalidOptions','options must be a scalar struct.');
end
projectRoot = setup_project();
cfg = landing2d.config.defaultConfig(projectRoot);

baselinePolicyFile = 'rl_policy_baseline_scratch.mat';
ontologyPolicyFile = 'rl_policy_graphstate_ontology_rgat.mat';
if isfield(options,'baselinePolicyFile')
    baselinePolicyFile = char(options.baselinePolicyFile);
    options = rmfield(options,'baselinePolicyFile');
end
if isfield(options,'ontologyPolicyFile')
    ontologyPolicyFile = char(options.ontologyPolicyFile);
    options = rmfield(options,'ontologyPolicyFile');
end
if ~isfield(options,'playbackSpeed'), options.playbackSpeed = 1; end
options.animate = false;
options.makeFinalPlots = false;
options.saveResults = false;
options.showLiveDashboard = false;
if ~isfield(options,'figureVisible'), options.figureVisible = true; end
cfg = landing2d.config.applyOptions(cfg,options);
landing2d.config.validateConfig(cfg);

baselineCfg = landing2d.graphstate.applyStateRepresentation(cfg,'baseline');
if cfg.scratchBaseline
    baselineCfg.rl = landing2d.rl.applyScratchSettings(baselineCfg.rl);
end
baselineCfg.rl.policyFile = baselinePolicyFile;
proposedCfg = landing2d.graphstate.applyStateRepresentation(cfg,'ontology_rgat');
proposedCfg.rl.policyFile = ontologyPolicyFile;
differences = landing2d.graphstate.assertSameProblem(baselineCfg,proposedCfg);
if ~isempty(differences)
    error('landing2d:UncontrolledCheckpointComparison', ...
        'Checkpoint training conditions differ:\n%s',strjoin(differences,newline));
end

[baselineAgent,baselineInfo,baselineFile] = ...
    landing2d.rl.loadCheckpoint(baselineCfg);
[proposedAgent,proposedInfo,proposedFile] = ...
    landing2d.rl.loadCheckpoint(proposedCfg);
fprintf('Baseline checkpoint: %s\n',baselineFile);
fprintf('Ontology-RGAT checkpoint: %s\n',proposedFile);

guidanceResults = landing2d.simulation.run(cfg);
baselineResults = landing2d.rl.evaluate(baselineAgent,baselineCfg);
proposedResults = landing2d.rl.evaluate(proposedAgent,proposedCfg);
runs = struct('results',{guidanceResults,baselineResults,proposedResults}, ...
    'label',{'PN guidance','PPO RL','Ontology-RGAT RL'});
fig = landing2d.viz.replayAgentComparison(runs,cfg);
summaryTable = landing2d.metrics.makeComparisonSummary(runs,cfg);
disp(summaryTable);
comparison = struct('runs',runs,'summaryTable',summaryTable, ...
    'baselineAgent',baselineAgent,'baselineInfo',baselineInfo, ...
    'proposedAgent',proposedAgent,'proposedInfo',proposedInfo, ...
    'baselineCheckpoint',baselineFile,'ontologyCheckpoint',proposedFile);
end
