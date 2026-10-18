function [S,detail] = environmentGraph(env,c,observation)
% ENVIRONMENTGRAPH  R-GAT policy state from the environment's 12-D common observation.
% With OBSERVATION (the vector environment.step returned) the graph is built
% from it directly; otherwise from env.commonObservation (same values).
if nargin >= 3 && ~isempty(observation)
    [S,detail] = landing2d.graphstate.observationVectorGraph(observation, ...
        env.observationContext,c);
else
    [S,detail] = landing2d.graphstate.observationGraph(env.commonObservation, ...
        env.observationContext,c);
end
end
