function source = graphSource(gs)
% GRAPHSOURCE  Context-graph feature source: 'commonObservation' or 'packet'.
% graphState.observationSource exists only in the planar contract, so the 3D
% option and older configurations keep the packet graph and their signatures.
source = 'packet';
if isstruct(gs) && isfield(gs,'observationSource')
    source = gs.observationSource;
end
end
