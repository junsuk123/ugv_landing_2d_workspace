function [schema,T,graph] = applyRelationPerturbation(schema,T,gs)
% APPLYRELATIONPERTURBATION  Fixed edge-relation shuffle for the relation-perturbed R-GAT.
% Without graphState.relationPerturbation the canonical graph passes through.
% With relationPerturbation = struct('type','edge_relation_shuffle','graphSeed',k,
% 'minChangedFraction',f) the relation type ids of the semantic edges are
% permuted once:
%   - node features, node order, src/dst, node and edge counts, per-relation
%     edge counts and the network structure are unchanged;
%   - self edges (relation 'self') are protected;
%   - an assignment equal to the canonical one up to a global renaming of
%     relation ids (in tosm7_v1 qualifiesEstimate <-> informsMotion, the two
%     relations with 3 edges each) is rejected and redrawn;
%   - an assignment changing the relation type of fewer than ceil(f * 13)
%     semantic edges is rejected and redrawn (no field: no such rule, the
%     comparison_registry_v3 graphs).
%   - when minOperatorChangedFraction is present, the same lower bound is
%     applied to the typed_v1 operator class (modulate versus propagate).
%     This prevents a shuffle from changing labels while retaining most of
%     the actual computation. Relation counts, and therefore the 8:5 split
%     between the two operator classes, remain fixed.
% The same graphSeed always gives the same assignment, so PPO, validation,
% test and inference share one typed graph. GRAPH records src/dst/rel, the
% canonical rel, and a SHA-256 hash of the typed graph.
canonicalRel = schema.rel;
perturbation = 'none';
graphSeed = NaN;
if isfield(gs,'relationPerturbation')
    p = gs.relationPerturbation;
    selfId = find(strcmp(schema.relationNames,'self'));
    movable = find(schema.rel ~= selfId);
    minChanged = 0;
    if isfield(p,'minChangedFraction'), minChanged = ceil(p.minChangedFraction*numel(movable)-1e-9); end
    minOperatorChanged = 0;
    if isfield(p,'minOperatorChangedFraction')
        minOperatorChanged = ceil(p.minOperatorChangedFraction*numel(movable)-1e-9);
    end
    canonicalOperators = schema.relationOperators(canonicalRel(movable));
    rs = RandStream('threefry','Seed',p.graphSeed);
    accepted = false;
    for attempt = 1:1000
        rel = canonicalRel;
        rel(movable) = canonicalRel(movable(randperm(rs,numel(movable))));
        runOperators = schema.relationOperators(rel(movable));
        operatorChanged = sum(~strcmp(runOperators,canonicalOperators));
        if ~sameUpToRenaming(rel(movable),canonicalRel(movable)) ...
                && sum(rel(movable)~=canonicalRel(movable))>=minChanged ...
                && operatorChanged>=minOperatorChanged
            accepted = true;
            break;
        end
    end
    assert(accepted,'landing2d:RelationShuffle', ...
        'No admissible relation shuffle was found for graph seed %d.',p.graphSeed);
    schema.rel = rel;
    semantic = size(schema.edgeTable,1);
    schema.edgeTable(:,3) = schema.relationNames(rel(1:semantic))';
    if isfield(schema,'edgePurpose')
        canonicalPurpose=schema.edgePurpose;
        for e=1:semantic
            schema.edgePurpose{e}=sprintf('SHUFFLED relation %s; canonical purpose: %s', ...
                schema.relationNames{rel(e)},canonicalPurpose{e});
        end
    end
    schema.relationPerturbation = p;
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
