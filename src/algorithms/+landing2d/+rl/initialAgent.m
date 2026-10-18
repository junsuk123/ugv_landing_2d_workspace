function agent = initialAgent(c)
% INITIALAGENT  The untrained agent of configuration C: the PPO starting point.
%   agent = landing2d.rl.initialAgent(c)
% landing2d.rl.trainAgent starts PPO from exactly this agent, so a trained
% checkpoint can be compared with its own initialization afterwards
% (landing2d.evaluation.trainingDiagnostics: parameter change of the encoders).
initRs = RandStream('threefry','Seed',c.rl.seed+101);
agent = landing2d.rl.agentInit(c.rl,initRs,c.graphState);
end
