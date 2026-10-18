function schema = observationSchema(dimension)
% OBSERVATIONSCHEMA  Single source of truth for the causal policy packet.
%   observationSchema()   2D packet, 26 = 6+8+7+5 (causal_packet_v2)
if nargin < 1 || isempty(dimension), dimension = 2; end
assert(dimension == 2,'landing2d:SpatialDimension', ...
    'Only the planar two-dimensional packet is supported.');
groups = struct();
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
