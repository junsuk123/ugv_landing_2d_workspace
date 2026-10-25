function [policyInput,detail] = features(observationVector)
% FEATURES A lossless partition of o_t; no duplicated or engineered features.
v = observationVector(:);
assert(numel(v)==10 && all(isfinite(v)),'landing2d:MinimalObservation', ...
    'tosm4_v1 requires the finite 10-D common observation.');
[schema,~] = landing2d.minimal.schema();
X = zeros(10,4);
for n = 1:4
    index = schema.observationIndices{n};
    X(index,n) = v(index);
end
policyInput = X(:);
if nargout>1, detail = struct('X',X,'schema',schema); end
end
