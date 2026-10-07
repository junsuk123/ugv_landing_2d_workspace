function schema = observationSchema(dimension)
% OBSERVATIONSCHEMA  Single source of truth for the causal policy packet.
%   observationSchema()   2D packet, 26 = 6+8+7+5   (causal_packet_v2)
%   observationSchema(3)  3D packet, 37 = 10+12+9+6 (causal_packet_v3_spatial)
% The 3D packet adds the lateral (y) and roll counterparts of the 2D fields.
if nargin < 1 || isempty(dimension), dimension = 2; end
groups = struct();
if dimension == 2
    groups.own_motion = {'h','vx','vz','sinTheta','cosTheta','pitchRate'};
    groups.pad_track = {'exEstimate','relativeVxEstimate','padVxEstimate', ...
        'padAxEstimate','positionStd','velocityStd','accelerationStd', ...
        'trackInitialized'};
    groups.visibility = {'detected','measuredBearing','bearingValid', ...
        'detectionConfidence','timeSinceLastDetection','predictedBearing', ...
        'predictedFovMargin'};
    groups.task_memory = {'remainingMissionTime','previousNormalizedActionX', ...
        'previousNormalizedActionZ','landingInhibited','abortRequested'};
    version = 'causal_packet_v2';
elseif dimension == 3
    groups.own_motion = {'h','vx','vy','vz','sinTheta','cosTheta','pitchRate', ...
        'sinRoll','cosRoll','rollRate'};
    groups.pad_track = {'exEstimate','eyEstimate','relativeVxEstimate', ...
        'relativeVyEstimate','padVxEstimate','padVyEstimate', ...
        'padAxEstimate','padAyEstimate','positionStd','velocityStd', ...
        'accelerationStd','trackInitialized'};
    groups.visibility = {'detected','measuredBearing','measuredBearingY', ...
        'bearingValid','detectionConfidence','timeSinceLastDetection', ...
        'predictedBearing','predictedBearingY','predictedFovMargin'};
    groups.task_memory = {'remainingMissionTime','previousNormalizedActionX', ...
        'previousNormalizedActionY','previousNormalizedActionZ', ...
        'landingInhibited','abortRequested'};
    version = 'causal_packet_v3_spatial';
else
    error('landing2d:SpatialDimension','observationSchema supports dimension 2 or 3.');
end
order = {'own_motion','pad_track','visibility','task_memory'};
names = {};
groupIndex = struct();
cursor = 0;
for i = 1:numel(order)
    key = order{i};
    n = numel(groups.(key));
    groupIndex.(key) = cursor+(1:n);
    names = [names,groups.(key)]; %#ok<AGROW>
    cursor = cursor+n;
end
schema = struct('version',version,'groups',groups, ...
    'groupOrder',{order},'names',{names},'groupIndex',groupIndex, ...
    'dimension',cursor);
end
