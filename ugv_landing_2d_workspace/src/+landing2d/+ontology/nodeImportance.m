function importance = nodeImportance(potentials,D,onto)
% NODEIMPORTANCE  노드 하나씩 무해한 값으로 바꾸었을 때의 잠재함수 변화량.
% 보상항 묶음 단위인 termImportance와 같은 반사실 분석을 노드 단위로 수행합니다.
% 온톨로지에서 실제로 기여하는 노드를 추려낼 때 쓰는 근거입니다.
if ~iscell(potentials)
    potentials = {potentials};
end
schema = D.schema;
T = landing2d.rgat.topology(schema);
X = landing2d.ontology.attributionSample(D.X,onto);
magnitude = zeros(numel(potentials),schema.nNodes);
signed = zeros(numel(potentials),schema.nNodes);
for k = 1:numel(potentials)
    baseline = landing2d.rgat.predict(potentials{k},X,T);
    for i = 1:schema.nNodes
        if i == schema.goalNode
            continue;   % 목표 노드 값은 항상 0이므로 바꿀 것이 없습니다.
        end
        counterfactual = X;
        neutral = schema.neutralValue(i);
        counterfactual(1,i,:) = neutral;
        counterfactual(2,i,:) = 1-neutral;
        delta = landing2d.rgat.predict(potentials{k},counterfactual,T)-baseline;
        magnitude(k,i) = mean(abs(delta));
        signed(k,i) = mean(delta);
    end
end
importance = struct('nodeNames',{schema.nodeNames}, ...
    'magnitude',mean(magnitude,1),'signed',mean(signed,1), ...
    'repeats',numel(potentials));
end
