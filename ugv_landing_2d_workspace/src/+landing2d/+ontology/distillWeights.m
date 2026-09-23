function design = distillWeights(potentials,D,onto,rl)
% DISTILLWEIGHTS  R-GAT 반사실 민감도를 고정 보상 가중치로 증류.
%
% 각 보상항에 대응하는 온톨로지 노드를 "무해한 값"으로 바꾸었을 때
% 잠재함수 Phi가 평균적으로 얼마나 변하는지를 그 항의 중요도로 봅니다.
% 중요도를 유계 단체(sum=1, [weightMin,weightMax])에 사영해 두 항의 비율을 얻습니다.
% 절대 크기는 기준 항(anchorTerm)의 가중치를 고정하고 나머지를 비율에 맞춰 키웁니다.
% 거리 항이 과제 자체를 정의하므로 이 항을 기준으로 삼습니다. 두 가중치의 합을
% 고정하면 비율이 포착 쪽으로 기울 때 거리 항이 함께 작아져 착륙 압력이 사라집니다.
%
% potentials가 여러 개면 중요도를 평균합니다. 한 번만 학습하면 초기화 난수에
% 따라 비율이 눈에 띄게 흔들리므로(문서의 측정 참고), 기본값은 여러 번 학습한
% 뒤 평균을 씁니다. 학습별 비율도 함께 남겨 흔들림 폭을 확인할 수 있습니다.
%
% 결과는 학습 전에 고정되며 PPO 실행 중에 변하지 않습니다.
if ~iscell(potentials)
    potentials = {potentials};
end
schema = D.schema;
nTerms = numel(schema.terms);
nRepeats = numel(potentials);
importance = zeros(nRepeats,nTerms);
signedEffect = zeros(nRepeats,nTerms);
repeatShares = zeros(nRepeats,nTerms);
for k = 1:nRepeats
    [importance(k,:),signedEffect(k,:),attributionSamples] = ...
        landing2d.ontology.termImportance(potentials{k},D,onto);
    switch onto.weightObjective
        case 'weightGraph'
            repeatShares(k,:) = landing2d.ontology.designByWeightGraph( ...
                potentials(k),D,onto);
        case 'alignment'
            repeatShares(k,:) = landing2d.ontology.projectBoundedSimplex( ...
                landing2d.ontology.alignWeights(potentials(k),D,onto,rl) ...
                +onto.importanceFloor,onto.weightMin,onto.weightMax);
        otherwise
            repeatShares(k,:) = landing2d.ontology.projectBoundedSimplex( ...
                importance(k,:)+onto.importanceFloor,onto.weightMin,onto.weightMax);
    end
end
meanImportance = mean(importance,1);
switch onto.weightObjective
    case 'weightGraph'
        % 가중치 노드를 훑어 착륙 잠재함수가 가장 큰 배분을 직접 고릅니다.
        [sweepShare,alignment] = landing2d.ontology.designByWeightGraph(potentials,D,onto);
        rawWeights = sweepShare;
    case 'alignment'
        % 보상이 착륙에 도움이 되는가를 기준으로 가중치를 적합합니다.
        [rawWeights,alignment] = landing2d.ontology.alignWeights(potentials,D,onto,rl);
    case 'counterfactual'
        % 예측 기여도를 그대로 비율로 씁니다(해석용/비교용).
        rawWeights = meanImportance;
        alignment = struct([]);
    otherwise
        error('landing2d:UnknownWeightObjective', ...
            'Unknown weightObjective: %s',onto.weightObjective);
end
if strcmp(onto.weightObjective,'weightGraph')
    share = rawWeights;   % 이미 [weightMin,weightMax] 안에서 고른 값
else
    share = landing2d.ontology.projectBoundedSimplex( ...
        rawWeights+onto.importanceFloor,onto.weightMin,onto.weightMax);
end
anchor = find(strcmp({schema.terms.name},onto.anchorTerm),1);
weights = onto.anchorWeight*share/share(anchor);
design = struct();
design.termNames = {schema.terms.name};
design.termLabels = {schema.terms.label};
design.importance = meanImportance;
design.signedEffect = mean(signedEffect,1);
design.share = share;
design.weightObjective = onto.weightObjective;
design.rawWeights = rawWeights;
design.alignment = alignment;
design.weights = weights;
design.repeatShares = repeatShares;
design.shareSpread = std(repeatShares(:,1),0,1);
design.repeats = nRepeats;
design.attributionSamples = attributionSamples;
for i = 1:nTerms
    design.(schema.terms(i).weightField) = weights(i);
end
design.anchorTerm = onto.anchorTerm;
design.anchorWeight = onto.anchorWeight;
design.designId = landing2d.util.checksum([weights,share,meanImportance, ...
    onto.anchorWeight,onto.weightMin,onto.weightMax,nRepeats]);
end
