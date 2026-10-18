function [policyInput,detail] = environmentGraph(env,c,observation)
% ENVIRONMENTGRAPH  R-GAT policy input from the environment's 12-D common observation.
% With OBSERVATION (the vector environment.step returned) the graph is built
% from it directly; otherwise from env.commonObservation (same values).
% policyInput is the flattened TOSM node-feature matrix X_t of that o_t.
if nargin >= 3 && ~isempty(observation)
    [policyInput,detail] = landing2d.graphstate.observationVectorGraph(observation, ...
        env.observationContext,c);
else
    [policyInput,detail] = landing2d.graphstate.observationGraph(env.commonObservation, ...
        env.observationContext,c);
end
end
