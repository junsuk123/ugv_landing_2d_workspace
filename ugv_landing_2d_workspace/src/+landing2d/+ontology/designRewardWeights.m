function [design,info] = designRewardWeights(c)
% DESIGNREWARDWEIGHTS  온톨로지 기반 R-GAT로 보상항 가중치를 설계.
%
%   1) 잡음 섞은 기준 유도 법칙 시연에서 온톨로지 그래프와 안전 착륙 결과를 모읍니다.
%   2) R-GAT이 그래프에서 안전 착륙 잠재함수 Phi(G)를 학습합니다.
%   3) 보상항에 대응하는 노드를 무해한 값으로 바꾸는 반사실 분석으로
%      각 항의 중요도를 구하고, 유계 단체에 사영해 가중치로 확정합니다.
%
% 한 번만 학습하면 초기화 난수에 따라 비율이 흔들리므로 designRepeats번 학습해
% 중요도를 평균합니다. 학습별 비율의 표준편차도 설계 결과에 함께 남깁니다.
onto = c.ontology;
landing2d.ontology.validateOntologyConfig(onto);
started = tic;
rs = RandStream('threefry','Seed',onto.seed);
if onto.verbose
    fprintf('온톨로지 데이터 수집 (%d 에피소드)...\n',onto.dataEpisodes);
end
if strcmp(onto.weightObjective,'weightGraph')
    D = landing2d.ontology.weightSweepDataset(c,rs);
else
    D = landing2d.ontology.buildDataset(c,rs);
end
if onto.verbose
    fprintf('R-GAT 학습 (%d회 x %d 에폭)...\n',onto.designRepeats,onto.epochs);
end
potentials = cell(1,onto.designRepeats);
validationLoss = zeros(1,onto.designRepeats);
for k = 1:onto.designRepeats
    [potentials{k},history] = landing2d.ontology.trainPotential(D,onto,rs);
    validationLoss(k) = history.finalValidationLoss;
end
design = landing2d.ontology.distillWeights(potentials,D,onto,c.rl);
design.datasetSamples = D.sampleCount;
design.datasetSuccessRate = D.successRate;
design.validationLoss = mean(validationLoss);
design.validationLossSpread = std(validationLoss);
design.nodeImportance = landing2d.ontology.nodeImportance(potentials,D,onto);

design.designSeconds = toc(started);
info = struct('potentials',{potentials},'validationLoss',validationLoss, ...
    'schema',D.schema);
if onto.verbose
    fprintf('\n%s\n',repmat('-',1,66));
    fprintf('온톨로지 R-GAT 보상 가중치 설계 (id %s)\n',design.designId);
    fprintf('%s\n',repmat('-',1,66));
    for i = 1:numel(design.termNames)
        fprintf('  %-10s | 중요도 %.4f | 비율 %.3f | 가중치 %.4f | %s\n', ...
            design.termNames{i},design.importance(i),design.share(i), ...
            design.weights(i),design.termLabels{i});
    end
    fprintf('  기준 항 %s = %.2f | 검증 MSE %.4f | 학습 %d회 비율 편차 %.3f | %.1f s\n', ...
        onto.anchorTerm,onto.anchorWeight,design.validationLoss,design.repeats, ...
        design.shareSpread,design.designSeconds);
    printNodeImportance(design.nodeImportance,D.schema);
    fprintf('%s\n\n',repmat('-',1,66));
end
end

function printNodeImportance(importance,schema)
% 어떤 노드가 잠재함수에 기여했는지: 온톨로지 최소화의 근거이자 설명 자료.
[~,order] = sort(importance.magnitude,'descend');
fprintf('  노드별 반사실 기여도 |dPhi|\n');
for k = order
    if k == schema.goalNode
        continue;
    end
    fprintf('    %-18s %.4f (%+.4f)\n',importance.nodeNames{k}, ...
        importance.magnitude(k),importance.signed(k));
end
end
