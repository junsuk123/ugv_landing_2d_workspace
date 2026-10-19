function D = dependencyGraph(decisionTrace)
% DEPENDENCYGRAPH  Structural dependency DAG from the sources to the Actor command.
%   D = landing2d.trace.dependencyGraph(trace)
% Vertices: processors (src:*), o_t entries (ch:01..12), node features
% (x:1..7), then for every R-GAT layer l = 1..L the typed edges
% (e<l>:01..20, encoderSpec.T order) and node embeddings (h<l>:1..7), the
% Actor graph embedding (readout), the Actor MLP (actor) and the requested
% acceleration (action). Arcs:
%   processor -> processor   capture dataflow (provenance.sourceEdges)
%   processor -> ch          provenance.channelSource
%   ch -> x                  provenance.channelToNode (deterministic derivation)
%   x_i -> e1 (src = i)      layer-1 message W_r x_i
%   h<l>_i -> e<l+1> (src=i) message of the next layer
%   e<l> -> h<l>_dst         aggregation at the destination
%   x_i -> h1_i              local path W0 (archived rgat_v1 only; rgat_v2 has
%                            none, its self edges carry a node's own state)
%   h<L> -> readout -> actor -> action   all seven final embeddings
% A path therefore chains at most L relations (rgat_v2: L = 2, two-hop
% compositions; rgat_v1: one hop). The attention score of an edge also reads
% the destination state and its softmax the other incoming edges of the same
% pool; the chain text states this, the DAG keeps the message lineage.
% Reachability is structural, not a numeric contribution.
S = decisionTrace.schema; P = decisionTrace.provenance;
L = 1; if isfield(S,'layers'), L = S.layers; end
legacyLocal = ~isfield(S,'encoderVersion') || ~strcmp(S.encoderVersion,'rgat_v2');
processors = P.processors; nP = numel(processors);
nC = numel(P.channelNames); N = S.nNodes; nE = S.nEdges;
ids = [strcat("src:",string(processors)), compose("ch:%02d",1:nC), compose("x:%d",1:N)];
for l = 1:L
    ids = [ids,compose("e%d:%02d",l,(1:nE)')',compose("h%d:%d",l,(1:N)')']; %#ok<AGROW>
end
ids = [ids,"readout","actor","action"];
ids = ids(:)';
V = numel(ids);
index = @(name)find(ids==name,1);
A = false(V);
for i = 1:size(P.sourceEdges,1)
    A(index("src:"+P.sourceEdges{i,1}),index("src:"+P.sourceEdges{i,2})) = true;
end
for k = 1:nC
    for p = find(P.channelSource(k,:))
        A(index("src:"+processors{p}),index(compose("ch:%02d",k))) = true;
    end
    for n = find(P.channelToNode(k,:))
        A(index(compose("ch:%02d",k)),index(compose("x:%d",n))) = true;
    end
end
for l = 1:L
    for e = 1:nE
        if l == 1
            from = compose("x:%d",S.src(e));
        else
            from = compose("h%d:%d",l-1,S.src(e));
        end
        A(index(from),index(compose("e%d:%02d",l,e))) = true;
        A(index(compose("e%d:%02d",l,e)),index(compose("h%d:%d",l,S.dst(e)))) = true;
    end
end
for n = 1:N
    if legacyLocal, A(index(compose("x:%d",n)),index(compose("h1:%d",n))) = true; end
    A(index(compose("h%d:%d",L,n)),index("readout")) = true;
end
A(index("readout"),index("actor")) = true;
A(index("actor"),index("action")) = true;
kind = extractBefore(ids+":",":");
kind(startsWith(ids,"e")) = "e"; kind(startsWith(ids,"h")) = "h";
layer = zeros(1,V);
for l = 1:L
    layer(startsWith(ids,sprintf("e%d:",l)) | startsWith(ids,sprintf("h%d:",l))) = l;
end
D = struct('ids',ids,'kind',kind,'layer',layer,'A',A,'nProcessors',nP,'nChannels',nC, ...
    'nNodes',N,'nEdges',nE,'layers',L);
end
