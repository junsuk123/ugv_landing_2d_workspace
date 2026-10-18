function [agent,info] = trainAgent(c,trainer)
% TRAINAGENT  Train one run with PPO from random weights (no teacher, no pretraining).
%   [agent,info] = landing2d.rl.trainAgent(c)
% Initialization, encoder and PPO use separate streams derived from rl.seed,
% so methods with the same training seed share them where their structure
% allows (the MLP initialization streams do not depend on the encoder size).
% info.history is the PPO validation history (landing2d.rl.ppoTrain).
if nargin < 2 || isempty(trainer), trainer = @landing2d.rl.ppoTrain; end
rl = landing2d.rl.ensurePool(c.rl);
c.rl = rl;
initRs = RandStream('threefry','Seed',rl.seed+101);
ppoRs = RandStream('threefry','Seed',rl.seed+404);
started = tic;
agent = landing2d.rl.agentInit(rl,initRs,c.graphState);
if rl.verbose
    fprintf('PPO (%d updates x %d episodes), random initial policy\n', ...
        rl.ppoIterations,rl.episodesPerIteration);
end
[agent,history] = trainer(agent,c,ppoRs);
info = struct('history',history,'trainingSeconds',toc(started), ...
    'trainer',func2str(trainer));
if rl.verbose
    fprintf('training time: %.1f s\n',info.trainingSeconds);
end
end
