function s=selection(t,nodeIds,edgeIds)
% SELECTION Explicit user choices and node-induced incident edge cuts.
if ~isempty(nodeIds), validateattributes(nodeIds,{'numeric'},{'vector','integer','positive','finite','<=',t.nNodes}); end
if ~isempty(edgeIds), validateattributes(edgeIds,{'numeric'},{'vector','integer','positive','finite','<=',t.nEdges}); end
s=struct('nodeIds',unique(reshape(nodeIds,1,[])),'edgeIds',unique(reshape(edgeIds,1,[])), ...
    'nodeKeep',true(t.nNodes,1),'edgeKeep',true(t.nEdges,1));
s.nodeKeep(s.nodeIds)=false; s.edgeKeep(s.edgeIds)=false;
s.effectiveEdgeKeep=s.edgeKeep & s.nodeKeep(t.src) & s.nodeKeep(t.dst);
s.hasCuts=any(~s.nodeKeep)||any(~s.edgeKeep);
end
