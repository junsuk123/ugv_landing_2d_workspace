function schema = vectorSchema(G)
% VECTORSCHEMA Minimal causal planar observation (10 dimensions).
% Every entry is derived from the current marker/KF estimate or navigation
% fix. Absolute horizontal position, the constant drone-x slot and the full
% previous-decision copy are deliberately excluded. The graph policy reads
% exactly these same ten values through observationGraph.
% relational-policy-v2.3 (2026-10-20): drone_navigationValid and
% drone_navigationAge were removed. The navigation estimate of this study is
% always valid and stamped at the decision time
% (landing2d.sensing.navigationEstimate), so both entries were constant (1 and
% 0) by construction and carried no information. They stay in the sensing
% record O.drone (capture); only the policy input drops them.
if isfield(G,'version'), version = G.version; else, version = G.schemaVersion; end
groups = struct();
groups.relative = {'relative_x','relative_height','relative_vx'};
groups.motion = {'ugv_vx','drone_vz','drone_sinTheta', ...
    'drone_cosTheta','drone_pitchRate'};
groups.quality = {'ugv_visionUpdated','ugv_visionAge'};
order = {'relative','motion','quality'};
% minimal_common_observation_v4_ugv_accel (hypothesis H3, 2026-10-26): the same
% ten entries plus the constant-acceleration KF UGV horizontal acceleration as
% the last entry (index 11), so every existing index is unchanged.
if strcmp(version,'minimal_common_observation_v4_ugv_accel')
    groups.acceleration = {'ugv_ax'};
    order = [order,{'acceleration'}];
end
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
