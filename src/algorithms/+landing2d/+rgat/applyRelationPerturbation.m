function [schema,T,graph] = applyRelationPerturbation(schema,T,gs)
% APPLYRELATIONPERTURBATION  Fixed edge-relation shuffle for the relation-perturbed R-GAT.
% Without graphState.relationPerturbation the canonical graph passes through.
% With relationPerturbation = struct('type','edge_relation_shuffle','graphSeed',k)
% the relation type ids of the shufflable edges are permuted once:
%   - node features, node order, src/dst, node and edge counts, per-relation
%     edge counts and the network structure are unchanged;
%   - self edges (relation 'self') are protected; the raw_plus_groups readout
%     needs no other structural edge;
%   - an assignment equal to the canonical one, or equal to it up to a global
%     renaming of relation ids (here only supports <-> inhibits, the two
%     relations with equal counts), is rejected and redrawn.
% The same graphSeed always gives the same assignment, so pretraining, PPO,
% validation, test and inference share one typed graph. GRAPH records
% src/dst/rel, the canonical rel, and a SHA-256 hash of the typed graph.
canonicalRel = schema.rel;
perturbation = 'none';
graphSeed = NaN;
if isfield(gs,'relationPerturbation')
    p = gs.relationPerturbation;
    selfId = find(strcmp(schema.relationNames,'self'));
    movable = find(schema.rel ~= selfId);
    rs = RandStream('threefry','Seed',p.graphSeed);
    accepted = false;
    for attempt = 1:1000
        rel = canonicalRel;
        rel(movable) = canonicalRel(movable(randperm(rs,numel(movable))));
        if ~sameUpToRenaming(rel(movable),canonicalRel(movable))
            accepted = true;
            break;
        end
    end
    assert(accepted,'landing2d:RelationShuffle', ...
        'No admissible relation shuffle was found for graph seed %d.',p.graphSeed);
    schema.rel = rel;
    semantic = size(schema.edgeTable,1);
    schema.edgeTable(:,3) = schema.relationNames(rel(1:semantic))';
    schema.relationPerturbation = struct('type',p.type,'graphSeed',p.graphSeed);
    schema.variant = [schema.variant,'_relation_shuffle'];
    T = landing2d.rgat.topology(schema);
    perturbation = p.type;
    graphSeed = p.graphSeed;
end
typed = struct('nodeNames',{schema.nodeNames},'relationNames',{schema.relationNames}, ...
    'src',schema.src,'dst',schema.dst,'rel',schema.rel);
graph = struct('perturbation',perturbation,'graphSeed',graphSeed, ...
    'src',schema.src,'dst',schema.dst,'rel',schema.rel,'canonicalRel',canonicalRel, ...
    'hash',landing2d.util.sha256(jsonencode(typed)));
end

function same = sameUpToRenaming(a,b)
% Equal up to a bijective renaming of relation ids <=> equal first-occurrence labels.
same = isequal(firstOccurrence(a),firstOccurrence(b));
end

function labels = firstOccurrence(x)
[~,~,labels] = unique(x,'stable');
labels = labels(:)';
end
