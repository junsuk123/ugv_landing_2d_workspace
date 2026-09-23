function w = projectBoundedSimplex(values,lower,upper)
% PROJECTBOUNDEDSIMPLEX  sum(w)=1, lower<=w<=upper 위로의 유클리드 사영.
% 원 저장소 reward_design._project_bounded_simplex와 같은 이분법입니다.
values = double(values(:))';
n = numel(values);
assert(n*lower <= 1+1e-12 && n*upper >= 1-1e-12, ...
    'landing2d:RewardWeightBounds','Weight bounds do not contain a unit simplex.');
values = max(values,0);
if sum(values) > 0
    values = values/sum(values);
else
    values = ones(1,n)/n;
end
low = min(values-upper)-1;
high = max(values-lower)+1;
for i = 1:80
    mid = 0.5*(low+high);
    projected = min(max(values-mid,lower),upper);
    if sum(projected) > 1
        low = mid;
    else
        high = mid;
    end
end
w = min(max(values-0.5*(low+high),lower),upper);
% 남은 부동소수 오차는 여유가 가장 큰 항에 흡수시켜 경계를 지킵니다.
residual = 1-sum(w);
if residual > 0
    room = upper-w;
else
    room = w-lower;
end
[~,index] = max(room);
w(index) = w(index)+residual;
end
