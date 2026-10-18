function edges=cutEdges(t,scope,target)
% CUTEDGES Resolve UI selection in checkpoint edge order (never digraph order).
scope=validatestring(scope,{'edge','outgoing','incoming','incident','relation'});
validateattributes(target,{'numeric'},{'scalar','integer','positive','finite'});
switch scope
    case 'edge'
        assert(target<=t.nEdges,'landing2d:LiveTestCutTarget','Invalid edge index.');
        edges=target;
    case 'relation'
        assert(ismember(target,t.rel),'landing2d:LiveTestCutTarget','Invalid relation index.');
        edges=find(t.rel==target);
    otherwise
        assert(target<=t.nNodes,'landing2d:LiveTestCutTarget','Invalid node index.');
        switch scope
            case 'outgoing', selected=t.src==target;
            case 'incoming', selected=t.dst==target;
            case 'incident', selected=t.src==target | t.dst==target;
        end
        % Keep self edges for node-group cuts. Individual self edges or the
        % entire self relation can still be explicitly selected.
        edges=find(selected & t.src~=t.dst);
end
edges=reshape(edges,1,[]);
assert(~isempty(edges),'landing2d:LiveTestCutTarget','No non-self edges for this selection.');
end
