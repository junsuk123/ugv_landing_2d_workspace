function [S,detail] = observationGraph(O,G,c)
% OBSERVATIONGRAPH Typed graph built exclusively from the registered 12-D o_t.
% Static calibration G determines scaling only; no supervisor flags, reward,
% outcome, previous hidden state or simulator truth enters the ontology.
assert(isequal(fieldnames(O)',{'schemaVersion','decisionTime','ugv','drone','history'}), ...
    'landing2d:InformationLeakage', ...
    'The context graph accepts only the registered common observation fields.');
v = landing2d.observation.toVector(O,G);
[S,detail] = landing2d.graphstate.observationVectorGraph(v,G,c);
end
