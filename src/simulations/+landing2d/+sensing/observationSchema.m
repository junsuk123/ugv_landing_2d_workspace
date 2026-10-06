function schema = observationSchema()
% OBSERVATIONSCHEMA  Single source of truth for the causal policy packet.
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
schema = struct('version','causal_packet_v2','groups',groups, ...
    'groupOrder',{order},'names',{names},'groupIndex',groupIndex, ...
    'dimension',cursor);
end
