function n = updateInputNorm(n,X)
% UPDATEINPUTNORM  MLP 입력 running 평균·분산의 병렬 Welford 갱신 (열 = 표본).
% 학습 전이에서 수집한 정책 입력만 씁니다. 보상·행동·결과·참값은 쓰지 않습니다.
m = size(X,2);
if m == 0, return; end
batchMean = mean(X,2);
batchVar = var(X,1,2);
total = n.count+m;
delta = batchMean-n.mean;
n.mean = n.mean+delta*(m/total);
n.var = (n.var*n.count+batchVar*m+delta.^2*(n.count*m/total))/total;
n.count = total;
end
