function [importance,signedEffect,attributionSamples] = termImportance(P,D,onto)
% TERMIMPORTANCE  보상항 묶음 단위 반사실 민감도.
% 해당 항의 온톨로지 노드를 모두 무해한 값으로 바꾸고 Phi의 변화를 측정합니다.
% 값 쌍만 바꾸고 위험 표시/편향/정체성 one-hot은 그대로 둡니다.
schema = D.schema;
T = landing2d.rgat.topology(schema);
X = landing2d.ontology.attributionSample(D.X,onto);
attributionSamples = size(X,3);
baseline = landing2d.rgat.predict(P,X,T);
nTerms = numel(schema.terms);
importance = zeros(1,nTerms);
signedEffect = zeros(1,nTerms);
for i = 1:nTerms
    counterfactual = X;
    for node = schema.terms(i).nodes
        neutral = schema.neutralValue(node);
        counterfactual(1,node,:) = neutral;
        counterfactual(2,node,:) = 1-neutral;
    end
    delta = landing2d.rgat.predict(P,counterfactual,T)-baseline;
    importance(i) = mean(abs(delta));
    signedEffect(i) = mean(delta);
end
end
