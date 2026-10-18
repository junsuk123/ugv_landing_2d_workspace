function [g,cache] = encoderForward(params,spec,S,head)
% ENCODERFORWARD  State representation -> Actor/Critic input.
%   S : [stateDim x B]  12-D o_t (baseline) or the flattened node features X_t
%   g : [graphDim x B]  input of the policy/value MLP
% context_rgat: H = tanh(RGAT(X) + W0 X + b0) per node, then the grouped
% factorized readout g = tanh(sum_k (Wc H_k) .* Wn(:,k) + bg). HEAD ('policy'
% or 'value') is informational: Actor and Critic have separate encoders.
if nargin < 4 || isempty(head), head = 'policy'; end %#ok<NASGU>
if strcmp(spec.mode,'baseline')
    g = S;
    cache = struct('mode',spec.mode);
    return;
end
B = size(S,2); N = spec.nNodes; dh = spec.hiddenDim;
X = reshape(S,spec.inDim,N,B);
Xf = reshape(X,spec.inDim,N*B);
[Z1,cache1] = landing2d.rgat.relationForward(X,params.W1,params.a1, ...
    params.E1,spec.T,[],spec.attentionMode);
local = reshape(params.W0*Xf+params.b0,dh,N,B);
H = tanh(reshape(Z1,dh,N,B)+local);
K = spec.groupCount;
grouped = zeros(dh,K,B);
channel = zeros(spec.graphDim,K,B);
for b = 1:B
    grouped(:,:,b) = H(:,:,b)*spec.groupMatrix';
    channel(:,:,b) = params.Wc*grouped(:,:,b);
end
g = tanh(reshape(sum(channel.*params.Wn,2),spec.graphDim,B)+params.bg);
cache = struct('mode',spec.mode,'B',B,'N',N,'dh',dh,'cache1',cache1, ...
    'Xf',Xf,'H',H,'grouped',grouped,'channel',channel,'g',g);
end
