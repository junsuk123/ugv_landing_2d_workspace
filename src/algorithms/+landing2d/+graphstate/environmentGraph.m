function [S,detail] = environmentGraph(env,c,observation)
% ENVIRONMENTGRAPH  Context-graph policy state from the environment's causal observation.
% Planar contract: the graph of the 12-D common observation (the same o_t the
% baseline reads). 3D option and old configurations: the causal-packet graph.
if strcmp(landing2d.graphstate.graphSource(c.graphState),'commonObservation')
    if nargin>=3 && ~isempty(observation)
        [S,detail] = landing2d.graphstate.observationVectorGraph(observation, ...
            env.observationContext,c);
        observationVector=observation(:);
    else
        [S,detail] = landing2d.graphstate.observationGraph(env.commonObservation, ...
            env.observationContext,c);
        observationVector=detail.observationVector(:);
    end
    if strcmp(c.graphState.readout,'observation_plus_groups')
        S=[observationVector;S];
    end
else
    [S,detail] = landing2d.graphstate.contextGraph(env.packet,c);
end
end
