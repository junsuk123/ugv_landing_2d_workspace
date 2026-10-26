function n = inputDimension(gs)
% INPUTDIMENSION Observation entries of the v5 residual actor for its registered topology.
%   tosm4_context_v1        10 (v5)
%   tosm4_context_accel_v1  11 (H3: the same ten plus the UGV acceleration estimate)
switch gs.topologyVersion
    case 'tosm4_context_v1', n = 10;
    case 'tosm4_context_accel_v1', n = 11;
    otherwise, error('landing2d:ResidualV5Topology','Unknown topology %s.',gs.topologyVersion);
end
end
