function [weights,info] = alignWeights(potentials,D,onto,rl)
% ALIGNWEIGHTS  보상항 가중치를 학습된 착륙 잠재함수에 맞춰 적합.
%
% R-GAT은 "이 상태가 안전 착륙으로 이어지는가"를 지도학습으로 배웁니다(Phi).
% 그렇다면 보상 가중치도 같은 기준으로 정해야 합니다. 즉 두 항의 가중합이
% Phi를 가장 잘 따라가도록 맞춥니다.
%
%   min_w,b  sum_s ( Phi(s) - (w1*c1(s) + w2*c2(s) + b) )^2 ,   w >= 0
%
% 이렇게 하면 보상이 큰 상태가 곧 착륙으로 이어지는 상태가 되므로,
% 보상을 최대화하는 정책이 착륙을 향하게 됩니다.
% 반사실 민감도는 "무엇이 Phi를 좌우하는가"(예측 기여도)를 재는 값이라
% 가중치의 크기를 정하는 기준으로는 맞지 않습니다. 실제로 그 비율을 그대로
% 쓰면 착륙이 최적해가 아닌 보상이 만들어집니다(docs/ONTOLOGY_RGAT_KO.md).
if ~iscell(potentials)
    potentials = {potentials};
end
T = landing2d.rgat.topology(D.schema);
X = landing2d.ontology.attributionSample(D.X,onto);
features = landing2d.ontology.termFeatures( ...
    struct('X',X,'schema',D.schema),rl);
target = zeros(1,size(X,3));
for k = 1:numel(potentials)
    target = target+landing2d.rgat.predict(potentials{k},X,T)/numel(potentials);
end
design = [features;ones(1,size(features,2))]';
solution = design\target(:);
% 음수 가중치는 "그 항을 반대로 주라"는 뜻이라 보상 설계로 쓸 수 없습니다.
% 두 항뿐이므로, 음수가 나오면 그 항을 0으로 고정하고 다시 적합합니다.
for i = 1:2
    if solution(i) < 0
        keep = setdiff(1:2,i);
        reduced = [features(keep,:);ones(1,size(features,2))]';
        partial = reduced\target(:);
        solution = zeros(3,1);
        solution(keep) = max(partial(1),0);
        solution(3) = partial(2);
        break;
    end
end
weights = solution(1:2)';
residual = target(:)-design*solution;
info = struct('intercept',solution(3), ...
    'residualRms',sqrt(mean(residual.^2)), ...
    'targetStd',std(target), ...
    'explained',1-var(residual)/max(var(target),eps), ...
    'samples',size(X,3));
end
