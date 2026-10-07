function dimension = graphDimension(gs)
% GRAPHDIMENSION  Spatial dimension of the context-graph features (2 or 3).
% graphState.spatialDimension exists only for the 3D option, so planar
% graph-state configurations and their training signatures are unchanged.
dimension = 2;
if isstruct(gs) && isfield(gs,'spatialDimension')
    dimension = gs.spatialDimension;
end
end
