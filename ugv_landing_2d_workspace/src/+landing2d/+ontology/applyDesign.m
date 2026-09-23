function cfg = applyDesign(cfg,design)
% APPLYDESIGN  [LEGACY] 설계된 보상 가중치를 강화학습 설정에 반영.
%
% ---------------------------------------------------------------------------
% 이 경로는 옛 제안 모델입니다. 온톨로지 R-GAT의 출력을 보상 가중치로 해석해
% 보상 함수를 바꿉니다. 새 제안 모델은 이 방식을 쓰지 않습니다.
%
% 새 제안 모델은 기준 모델과 완전히 같은 보상을 쓰고, 온톨로지와 R-GAT은
% PPO에 넣을 **상태 표현**을 만드는 데만 씁니다.
%   landing2d.graphstate.applyStateRepresentation(cfg,'ontology_rgat')
%
% 이 함수는 기존 실험(reward_design*.mat, rl_policy_onto*.mat)을 다시 돌릴 수
% 있도록 남겨 둔 것이며, cfg.useLegacyOntologyReward = true일 때만 run_all이
% 호출합니다. 새 경로와 섞어 쓰지 마십시오.
% ---------------------------------------------------------------------------
%
% 온톨로지 비교군은 제안 모델이므로 기준 유도 법칙의 모방 학습으로 초기화하지 않고
% 무작위 초기 정책에서 PPO만으로 학습합니다. 그래야 결과가 유도 법칙의 사전 지식이
% 아니라 보상 설계에서 나온 것이라고 말할 수 있습니다.
% 좋은 초기 정책이 없으므로 탐색과 학습량을 키운 rl.scratch 설정을 함께 적용합니다.
%
% 정책 파일 이름도 바꿔, 손으로 정한 가중치로 학습한 정책과 섞이지 않게 합니다.
cfg.rl.captureWeight = design.captureWeight;
cfg.rl.distanceWeight = design.distanceWeight;
cfg.rl = landing2d.rl.applyScratchSettings(cfg.rl);
cfg.rl.policyFile = 'rl_policy_ontology.mat';
% 이 설정이 보상을 바꾼 경로를 지났다는 표식입니다.
% landing2d.graphstate.assertSameProblem이 이 값을 보고 새 제안 모델 경로에
% 옛 보상 설계가 섞여 들어오는 것을 막습니다.
cfg.ontologyRewardApplied = true;
end
