function W = basisWeights(V,C)
% BASISWEIGHTS  Relation weights from a shared basis: W(:,:,r) = sum_b C(r,b) V(:,:,b).
%   V : [dout x din x nBases], C : [nRelations x nBases], W : [dout x din x nRelations]
% Basis decomposition of R-GCN (Schlichtkrull et al. 2018) used by rgat_v2.
[dout,din,nBases] = size(V);
W = reshape(reshape(V,dout*din,nBases)*C',dout,din,size(C,1));
end
