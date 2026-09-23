function test_reward_design()
% TEST_REWARD_DESIGN  가중치 증류 경로: 단체 사영, 반사실 민감도, 재현성.

% 1) 유계 단체 사영: 합이 1이고 경계를 지켜야 함.
projected = landing2d.ontology.projectBoundedSimplex([0.02,0.98],0.15,0.85);
assert(abs(sum(projected)-1) < 1e-12);
assert(all(projected >= 0.15-1e-12 & projected <= 0.85+1e-12));
assert(projected(2) > projected(1),'Projection must keep the ordering.');
equal = landing2d.ontology.projectBoundedSimplex([0,0],0.15,0.85);
assert(all(abs(equal-0.5) < 1e-9),'All-zero importance must split evenly.');

% 2) 작은 설정으로 설계 전체 경로를 실행.
c = landing2d.config.defaultConfig();
c = landing2d.config.applyOptions(c,struct('tEnd',6,'segmentTimes',[2,4], ...
    'scenarioSpeeds',[1,3,1.5],'animate',false,'figureVisible',false, ...
    'saveResults',false));
c.ontology.dataEpisodes = 3;
c.ontology.epochs = 2;
c.ontology.designRepeats = 2;
c.ontology.hiddenDim = 6;
c.ontology.verbose = false;
landing2d.config.validateConfig(c);
[design,info] = landing2d.ontology.designRewardWeights(c);
terms = numel(design.termNames);
assert(terms == 2);
assert(abs(sum(design.share)-1) < 1e-9);
anchor = find(strcmp(design.termNames,c.ontology.anchorTerm),1);
assert(abs(design.weights(anchor)-c.ontology.anchorWeight) < 1e-9, ...
    'The anchor term must keep its configured weight.');
assert(abs(design.weights(1)/design.weights(2)-design.share(1)/design.share(2)) < 1e-9, ...
    'The weight ratio must equal the inferred share ratio.');
assert(all(design.weights > 0) && all(isfinite(design.weights)));
assert(all(design.importance >= 0));
assert(isfield(design,'captureWeight') && isfield(design,'distanceWeight'));
assert(design.captureWeight == design.weights(1));
assert(design.distanceWeight == design.weights(2));
assert(numel(info.potentials) == c.ontology.designRepeats);
assert(isequal(size(design.repeatShares),[c.ontology.designRepeats,terms]));
assert(all(abs(sum(design.repeatShares,2)-1) < 1e-9));
assert(design.repeats == c.ontology.designRepeats && design.shareSpread >= 0);

% 노드별 반사실 기여도: 최소 스키마의 근거이자 설명 자료.
node = design.nodeImportance;
assert(numel(node.magnitude) == numel(schemaOf().nodeNames));
assert(all(node.magnitude >= 0) && all(isfinite(node.magnitude)));
assert(node.magnitude(schemaOf().goalNode) == 0, ...
    'The goal node is always zero and cannot be neutralized.');
assert(all(node.magnitude(setdiff(1:numel(node.magnitude),schemaOf().goalNode)) > 0), ...
    'Every kept node must contribute to the potential.');

% 3) 설계한 가중치를 적용하면 강화학습 설정만 바뀌고 환경은 그대로여야 함.
applied = landing2d.ontology.applyDesign(c,design);
assert(applied.rl.captureWeight == design.captureWeight);
assert(applied.rl.distanceWeight == design.distanceWeight);
assert(~strcmp(applied.rl.policyFile,c.rl.policyFile), ...
    'The ontology policy must not overwrite the manual-weight policy.');
assert(~applied.rl.useBehaviorClone, ...
    'The ontology arm must train without behaviour cloning.');
% 이 경로는 보상을 바꾸는 옛 제안 모델이므로 표식을 남겨야 합니다.
% landing2d.graphstate.assertSameProblem이 이 표식을 보고, 새 제안 모델의
% 설정에 옛 보상 설계가 섞여 들어오는 것을 막습니다.
assert(isfield(applied,'ontologyRewardApplied') && applied.ontologyRewardApplied, ...
    'applyDesign must mark the config as having modified the reward.');
assert(~isfield(c,'ontologyRewardApplied'), ...
    'A config that never went through applyDesign must carry no marker.');
applied = rmfield(applied,'ontologyRewardApplied');
applied.rl.captureWeight = c.rl.captureWeight;
applied.rl.distanceWeight = c.rl.distanceWeight;
applied.rl.policyFile = c.rl.policyFile;
overrides = fieldnames(c.rl.scratch);
for i = 1:numel(overrides)
    applied.rl.(overrides{i}) = c.rl.(overrides{i});
end
assert(isequal(applied,c), ...
    'applyDesign must only change the reward weights and the scratch settings.');

% 4) 같은 시드면 같은 설계가 나와야 함.
repeated = landing2d.ontology.designRewardWeights(c);
assert(strcmp(repeated.designId,design.designId));
assert(norm(repeated.weights-design.weights) < 1e-12);
end

function schema = schemaOf()
schema = landing2d.ontology.nodeSchema();
end
