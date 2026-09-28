function [comparison,cfg,fig] = run_finalTest(options)
% RUN_FINALTEST  Replay the final PN, RL, and OntoRL agents in one GUI.
%
% The two learned agents are loaded strictly from their final checkpoints;
% this entry point never starts or resumes training.  Every scenario tab
% shows PN guidance, vector-state PPO RL, and ontology R-GAT PPO together.
% Plot limits are computed from the complete trajectories before playback
% and then kept fixed, so the GUI does not pan or rescale while it runs.
%
%   run_finalTest
%   run_finalTest(struct('playbackSpeed',4))
%   [comparison,cfg,fig] = run_finalTest(struct('playbackSpeed',Inf));
%
% Optional checkpoint overrides:
%   options.baselinePolicyFile = 'my_rl_checkpoint.mat';
%   options.ontologyPolicyFile = 'my_ontorl_checkpoint.mat';

if nargin < 1
    options = struct();
end
if ~(isstruct(options) && isscalar(options))
    error('landing2d:InvalidOptions','options must be a scalar struct.');
end

% Name the final checkpoints explicitly here so this file documents exactly
% which trained policies are used by the final comparison.
if ~isfield(options,'baselinePolicyFile')
    options.baselinePolicyFile = 'rl_policy_baseline_scratch.mat';
end
if ~isfield(options,'ontologyPolicyFile')
    options.ontologyPolicyFile = 'rl_policy_graphstate_ontology_rgat.mat';
end
if ~isfield(options,'playbackSpeed')
    options.playbackSpeed = 1;
end
if ~isfield(options,'figureVisible')
    options.figureVisible = true;
end

% Avoid stacking multiple final-test windows when the entry point is rerun.
oldFigures = findall(groot,'Type','figure','Tag','landing2dFinalTest');
if ~isempty(oldFigures)
    delete(oldFigures);
end

[comparison,cfg,fig] = run_realtime_checkpoint_comparison(options);
end
