function [center,lower,upper,n] = pairedInterval(delta,coverage)
% PAIREDINTERVAL Student-t interval on training-seed differences (base MATLAB).
delta = double(delta(:));
assert(all(isfinite(delta)),'landing2d:CurrentSemanticsMissing','Do not silently exclude a training seed.');
n = numel(delta); center = mean(delta); lower = NaN; upper = NaN;
if n<2, return; end
assert(coverage>0 && coverage<1);
df = n-1; q = betaincinv(1-coverage,df/2,0.5);
half = sqrt(df*(1-q)/q)*std(delta)/sqrt(n);
lower = center-half; upper = center+half;
end
