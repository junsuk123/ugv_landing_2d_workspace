function [evidence,cache] = semanticGraphForward(p,spec,u)
% SEMANTICGRAPHFORWARD Relation-typed operators of the v8 graph correction (C3).
%   H0_i = tanh(P_i u_i + bp_i)                      node evidence (as v5)
%   two hops with shared parameters; the relation of each edge fixes its operator:
%     informsMotion, self  additive messages W_r H_j, dynamic joint attention
%                          over the incoming additive edges (landing2d.minimal.dynamicForward)
%     qualifiesEstimate    modulation of the destination, G_i = prod_e (1 + tanh(W_q H_j + b_q)),
%                          G_i = 1 without such an edge
%     H_i <- G_i .* (tanh(W0 H_i + b) + Z_i)
% Messages enter the node additively without squashing; quality scales the
% destination's representation. EVIDENCE is the RelativeState goal node (d x B).
% A relation shuffle moves these operators to other edges (spec.Tadd, spec.qualifies).
d = spec.hiddenDim; N = spec.nNodes; B = size(u,2);
H0 = zeros(d,N,B);
for i = 1:N
    index = spec.schema.observationIndices{i};
    H0(:,i,:) = reshape(tanh(p.P(:,index)*u(index,:)+p.bp(:,i)),d,1,B);
end
Wq = p.W(:,:,spec.gateRelation); Wadd = p.W(:,:,spec.additiveRelations);
H = H0; layers = cell(1,spec.layers);
for l = 1:spec.layers
    [Z,relation] = landing2d.minimal.dynamicForward(H,Wadd,p.a,spec.Tadd);
    G = ones(d,N,B); gateTerms = cell(1,numel(spec.qualifies.src));
    for e = 1:numel(spec.qualifies.src)
        t = tanh(Wq*reshape(H(:,spec.qualifies.src(e),:),d,B)+p.bq);
        gateTerms{e} = t;
        i = spec.qualifies.dst(e);
        G(:,i,:) = G(:,i,:).*reshape(1+t,d,1,B);
    end
    root = reshape(tanh(p.W0*reshape(H,d,N*B)+p.b),d,N,B);
    inner = root+Z;
    previous = H;
    H = G.*inner;
    layers{l} = struct('previous',previous,'relation',relation,'G',G,'gateTerms',{gateTerms}, ...
        'root',root,'inner',inner);
end
evidence = reshape(H(:,spec.goalNode,:),d,B);
cache = struct('H0',H0,'layers',{layers},'u',u,'B',B);
end
