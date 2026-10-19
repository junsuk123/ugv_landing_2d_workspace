function D = dependencyGraph(decisionTrace)
% DEPENDENCYGRAPH  Structural dependency DAG from the sources to the Actor command.
%   D = landing2d.trace.dependencyGraph(trace)
% Vertices: processors (src:*), o_t entries (ch:01..12), node features
% (x:1..7), typed R-GAT edges (e:01..20, encoderSpec.T order), node
% embeddings (h:1..7), the Actor graph embedding (readout), the Actor MLP
% (actor) and the requested acceleration (action). Arcs:
%   processor -> processor   capture dataflow (provenance.sourceEdges)
%   processor -> ch          provenance.channelSource
%   ch -> x                  provenance.channelToNode (deterministic derivation)
%   x_i -> e (src = i)       message W_r x_i of the edge
%   x_i -> h_i               local path W0 x_i + b0
%   e -> h_dst               aggregation at the destination
%   h -> readout -> actor -> action   all seven embeddings enter the readout
% Single layer: no arc leaves an embedding toward an edge, so a path never
% chains two relations (no multi-hop inference). The attention score of an
% edge also reads x_dst and its softmax the other edges of the same operator
% pool at that destination; the chain text states this, the DAG keeps the
% message lineage. Reachability here is structural, not a numeric
% contribution.
S = decisionTrace.schema; P = decisionTrace.provenance;
processors = P.processors; nP = numel(processors);
nC = numel(P.channelNames); N = S.nNodes; nE = S.nEdges;
ids = [strcat("src:",string(processors)), compose("ch:%02d",1:nC), ...
    compose("x:%d",1:N), compose("e:%02d",1:nE), compose("h:%d",1:N), ...
    "readout","actor","action"];
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
for e = 1:nE
    A(index(compose("x:%d",S.src(e))),index(compose("e:%02d",e))) = true;
    A(index(compose("e:%02d",e)),index(compose("h:%d",S.dst(e)))) = true;
end
for n = 1:N
    A(index(compose("x:%d",n)),index(compose("h:%d",n))) = true;
    A(index(compose("h:%d",n)),index("readout")) = true;
end
A(index("readout"),index("actor")) = true;
A(index("actor"),index("action")) = true;
kind = extractBefore(ids+":",":");
kind(ids=="readout") = "readout"; kind(ids=="actor") = "actor"; kind(ids=="action") = "action";
D = struct('ids',ids,'kind',kind,'A',A,'nProcessors',nP,'nChannels',nC, ...
    'nNodes',N,'nEdges',nE);
end
