function rho = spearman(x,y)
% SPEARMAN Rank correlation with average ranks for ties (descriptive; no test).
ok = isfinite(x) & isfinite(y); x = x(ok); y = y(ok);
if numel(x)<3, rho = NaN; return; end
rx = ranks(x(:)); ry = ranks(y(:));
c = corrcoef(rx,ry); rho = c(1,2);
end

function r = ranks(v)
[s,order] = sort(v); r = zeros(size(v)); n = numel(v); i = 1;
while i<=n
    j = i;
    while j<n && s(j+1)==s(i), j = j+1; end
    r(order(i:j)) = (i+j)/2; i = j+1;
end
end
