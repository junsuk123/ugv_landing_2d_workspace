function schema = vectorSchema(G)
% VECTORSCHEMA Minimal causal planar observation (12 dimensions).
% Every entry is derived from the current marker/KF estimate or navigation
% fix. Absolute horizontal position, the constant drone-x slot and the full
% previous-decision copy are deliberately excluded. The graph policy reads
% exactly these same twelve values through observationGraph.
if isfield(G,'version'), version = G.version; else, version = G.schemaVersion; end
groups = struct();
groups.relative = {'relative_x','relative_height','relative_vx'};
groups.motion = {'ugv_vx','drone_vz','drone_sinTheta', ...
    'drone_cosTheta','drone_pitchRate'};
groups.quality = {'ugv_visionUpdated','ugv_visionAge', ...
    'drone_navigationValid','drone_navigationAge'};
order = {'relative','motion','quality'};
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
